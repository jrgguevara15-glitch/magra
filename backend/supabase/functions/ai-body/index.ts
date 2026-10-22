// MAGRA · U15 — Edge Function "ai-body".
//
// Evaluación corporal con foto: recibe 1 a 3 fotos del cuerpo (frente,
// perfil, espalda) y los datos de la persona (sexo, edad, estatura, peso,
// perímetros y el % de grasa de sus medidas) y devuelve el % de grasa
// estimado con su rango, la distribución de la grasa, el tono muscular, la
// postura y recomendaciones. Solo responde si la persona aceptó enviar sus
// fotos a la IA (ai_consents, 'body'). Las fotos no se guardan en ninguna
// parte; la clave de la API vive solo aquí (secreto ANTHROPIC_API_KEY) y
// nunca se registran en logs las fotos ni los datos.
//
// Despliegue: Supabase → Edge Functions → Deploy a new function → Via
// Editor → nombre "ai-body" → pegar este archivo → Deploy (con "Verify
// JWT" activado).

import Anthropic from "npm:@anthropic-ai/sdk@0.132.1";
import { createClient } from "npm:@supabase/supabase-js@2.117.3";

/** Evaluaciones por usuario al día. */
export const DAILY_LIMIT = 3;

/** Tamaño máximo de cada imagen en base64 (~5 MB de imagen). */
export const MAX_BASE64_LENGTH = 7_000_000;

const MODEL = "claude-opus-5-5";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MEDIA_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;
type MediaType = (typeof MEDIA_TYPES)[number];
const VIEWS = ["front", "side", "back"] as const;
type View = (typeof VIEWS)[number];
const VIEW_LABEL: Record<View, string> = { front: "de frente", side: "de perfil", back: "de espalda" };

export interface BodyImage {
  data: string;
  media_type: MediaType;
  view: View;
}

export interface BodyContext {
  sex: "male" | "female";
  age: number;
  height_cm: number;
  weight_kg: number;
  neck_cm?: number;
  waist_cm?: number;
  hip_cm?: number;
  tape_fat_pct?: number;
  goal_fat_pct?: number;
}

export interface BodyRequest {
  images: BodyImage[];
  context: BodyContext;
}

export interface BodyResult {
  valid: boolean;
  invalid_reason: string;
  fat_pct: number;
  fat_low: number;
  fat_high: number;
  confidence: "alta" | "media" | "baja";
  fat_distribution: string;
  muscle_tone: string;
  posture: string;
  strengths: string[];
  priorities: string[];
  nutrition: string[];
  training: string[];
  photo_tips: string;
}

const list = { type: "array", items: { type: "string" } } as const;

/** Esquema de la respuesta que se le exige a Claude. */
export const RESULT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "valid", "invalid_reason", "fat_pct", "fat_low", "fat_high", "confidence",
    "fat_distribution", "muscle_tone", "posture", "strengths", "priorities",
    "nutrition", "training", "photo_tips",
  ],
  properties: {
    valid: { type: "boolean" },
    invalid_reason: { type: "string" },
    fat_pct: { type: "number" },
    fat_low: { type: "number" },
    fat_high: { type: "number" },
    confidence: { type: "string", enum: ["alta", "media", "baja"] },
    fat_distribution: { type: "string" },
    muscle_tone: { type: "string" },
    posture: { type: "string" },
    strengths: list,
    priorities: list,
    nutrition: list,
    training: list,
    photo_tips: { type: "string" },
  },
} as const;

export class HttpError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}

const num = (v: unknown, min: number, max: number): number | undefined =>
  typeof v === "number" && Number.isFinite(v) && v >= min && v <= max ? v : undefined;

/** Valida el cuerpo que manda la app. */
export function parseRequest(body: unknown): BodyRequest {
  const b = body as Partial<BodyRequest> | null;
  const images = Array.isArray(b?.images) ? b!.images : [];
  if (images.length < 1) throw new HttpError(400, "Falta la foto de frente.");
  if (images.length > 3) throw new HttpError(400, "Máximo 3 fotos.");
  const seen = new Set<string>();
  for (const i of images) {
    if (!i || typeof i.data !== "string" || i.data.length < 100) {
      throw new HttpError(400, "Una de las fotos llegó vacía.");
    }
    if (i.data.length > MAX_BASE64_LENGTH) throw new HttpError(413, "Una de las fotos es demasiado grande.");
    if (!MEDIA_TYPES.includes(i.media_type)) throw new HttpError(400, "Formato de imagen no soportado.");
    if (!VIEWS.includes(i.view) || seen.has(i.view)) throw new HttpError(400, "Vista de foto inválida.");
    seen.add(i.view);
  }
  const c = (b?.context ?? {}) as Partial<BodyContext>;
  const sex = c.sex === "male" || c.sex === "female" ? c.sex : undefined;
  const age = num(c.age, 18, 100);
  const height = num(c.height_cm, 120, 230);
  const weight = num(c.weight_kg, 25, 400);
  if (!sex || age === undefined || height === undefined || weight === undefined) {
    throw new HttpError(400, "Faltan tus datos (sexo, edad, estatura y peso).");
  }
  return {
    images: images.map((i) => ({ data: i.data, media_type: i.media_type, view: i.view })),
    context: {
      sex,
      age: Math.round(age),
      height_cm: height,
      weight_kg: weight,
      neck_cm: num(c.neck_cm, 20, 80),
      waist_cm: num(c.waist_cm, 40, 250),
      hip_cm: num(c.hip_cm, 50, 250),
      tape_fat_pct: num(c.tape_fat_pct, 3, 70),
      goal_fat_pct: num(c.goal_fat_pct, 5, 50),
    },
  };
}

/** Instrucciones para Claude. */
export function buildPrompt(req: BodyRequest): string {
  const c = req.context;
  const f = (v: number | undefined, unit: string) => (v === undefined ? "sin dato" : `${v} ${unit}`);
  return [
    "Eres el evaluador de composición corporal de MAGRA, una app de nutrición y entrenamiento para bajar grasa.",
    `Recibes ${req.images.length} foto(s) de la persona: ${req.images.map((i) => VIEW_LABEL[i.view]).join(", ")}.`,
    "Datos de la persona:",
    `- Sexo: ${c.sex === "male" ? "hombre" : "mujer"}; edad: ${c.age} años; estatura: ${c.height_cm} cm; peso: ${c.weight_kg} kg.`,
    `- Cuello: ${f(c.neck_cm, "cm")}; cintura: ${f(c.waist_cm, "cm")}; cadera: ${f(c.hip_cm, "cm")}.`,
    `- % de grasa según sus medidas (fórmula de la Marina de EE.UU.): ${f(c.tape_fat_pct, "%")}.`,
    c.goal_fat_pct !== undefined ? `- Su meta: ${c.goal_fat_pct} % de grasa.` : "",
    "",
    "Tarea: estima el % de grasa corporal a partir de lo que ves (definición muscular, pliegues,",
    "acumulación en abdomen, cintura, caderas, espalda baja, brazos y muslos, vascularidad, forma de",
    "la cintura) combinado con los datos. Usa como referencia las guías visuales de % de grasa por sexo",
    "y el IMC. Da un valor central y un rango realista (normalmente ±3 puntos; más amplio si la foto",
    "es mala o la ropa es holgada). Si tu estimación difiere mucho de la de sus medidas, explica por qué.",
    "Describe la distribución de la grasa, el tono muscular y la postura que se observa, sin diagnósticos médicos.",
    "Luego da recomendaciones concretas y priorizadas para bajar grasa conservando músculo:",
    "priorities (2–4), nutrition (2–4) y training (2–4), cada una en una frase corta y accionable.",
    "strengths: 1–3 aspectos positivos reales que veas.",
    "photo_tips: cómo mejorar las fotos para la próxima evaluación (luz, distancia, ropa, pose), o vacío.",
    "",
    "Reglas: tono respetuoso, motivador y sin juicios sobre el cuerpo; español de Chile; nada de",
    "comentarios sobre el rostro ni rasgos personales. Si las fotos no muestran el cuerpo de UNA",
    "persona adulta (otra cosa, varias personas, solo la cara, o alguien que parece menor de edad),",
    "devuelve valid=false con el motivo en invalid_reason, fat_pct=0 y listas vacías.",
  ].filter((l) => l !== "").join("\n");
}

const clean = (v: unknown, max: number) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const cleanList = (v: unknown) =>
  Array.isArray(v) ? v.filter((s) => typeof s === "string" && s.trim()).slice(0, 5).map((s) => s.trim().slice(0, 240)) : [];
const pct = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? Math.round(Math.min(Math.max(v, 3), 70) * 10) / 10 : 0);

/** Valida y acota lo que devolvió el modelo. */
export function sanitizeResult(raw: unknown): BodyResult {
  const r = (raw ?? {}) as Partial<BodyResult>;
  const valid = r.valid === true && typeof r.fat_pct === "number" && r.fat_pct > 0;
  const fat = valid ? pct(r.fat_pct) : 0;
  let low = valid ? pct(r.fat_low) : 0;
  let high = valid ? pct(r.fat_high) : 0;
  if (valid) {
    // El rango debe contener el valor central y no ser absurdo.
    if (!(low > 0 && low <= fat)) low = Math.max(3, fat - 3);
    if (!(high >= fat)) high = Math.min(70, fat + 3);
    if (high - low > 16) {
      low = Math.max(3, fat - 8);
      high = Math.min(70, fat + 8);
    }
  }
  return {
    valid,
    invalid_reason: valid ? "" : clean(r.invalid_reason, 300) || "No se pudo evaluar con estas fotos.",
    fat_pct: fat,
    fat_low: low,
    fat_high: high,
    confidence: r.confidence === "alta" || r.confidence === "baja" ? r.confidence : "media",
    fat_distribution: valid ? clean(r.fat_distribution, 400) : "",
    muscle_tone: valid ? clean(r.muscle_tone, 400) : "",
    posture: valid ? clean(r.posture, 400) : "",
    strengths: valid ? cleanList(r.strengths) : [],
    priorities: valid ? cleanList(r.priorities) : [],
    nutrition: valid ? cleanList(r.nutrition) : [],
    training: valid ? cleanList(r.training) : [],
    photo_tips: clean(r.photo_tips, 400),
  };
}

/** Pide la evaluación a Claude y devuelve el resultado validado. */
export async function assess(client: Anthropic, req: BodyRequest): Promise<BodyResult> {
  const response = await client.beta.messages.create({
    model: MODEL,
    max_tokens: 4000,
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    output_config: { format: { type: "json_schema", schema: RESULT_SCHEMA } },
    messages: [
      {
        role: "user",
        content: [
          ...req.images.flatMap((i) => [
            { type: "text" as const, text: `Foto ${VIEW_LABEL[i.view]}:` },
            { type: "image" as const, source: { type: "base64" as const, media_type: i.media_type, data: i.data } },
          ]),
          { type: "text", text: buildPrompt(req) },
        ],
      },
    ],
  });
  if (response.stop_reason === "refusal") {
    throw new HttpError(422, "La IA no pudo evaluar estas fotos.");
  }
  const text = response.content.find((b) => b.type === "text");
  if (!text || text.type !== "text") throw new HttpError(502, "La IA no devolvió un resultado.");
  try {
    return sanitizeResult(JSON.parse(text.text));
  } catch {
    throw new HttpError(502, "La IA devolvió un resultado ilegible.");
  }
}

/** Clave pública del proyecto: la antigua (anon) o la nueva (publishable). */
export function publicKey(env: (name: string) => string | undefined): string {
  const anon = env("SUPABASE_ANON_KEY");
  if (anon) return anon;
  const publishable = env("SUPABASE_PUBLISHABLE_KEYS");
  if (publishable) {
    try {
      const keys = JSON.parse(publishable) as Record<string, string>;
      const first = Object.values(keys)[0];
      if (first) return first;
    } catch {
      return publishable;
    }
  }
  throw new HttpError(500, "Falta configurar Supabase en el servidor.");
}

/** El secreto debe ser solo la clave (sk-ant-…). */
export function anthropicKey(raw: string | undefined): string {
  const key = (raw ?? "").trim();
  if (!key) throw new HttpError(500, "Falta configurar la IA en el servidor.");
  if (!/^sk-ant-[A-Za-z0-9_-]+$/.test(key)) {
    console.error("ai-body", "ANTHROPIC_API_KEY mal configurada: debe ser solo la clave sk-ant-…");
    throw new HttpError(500, "La clave de la IA está mal configurada en el servidor.");
  }
  return key;
}

/** Nunca dejar una clave en los logs, aunque venga dentro de un error. */
export function redact(text: string): string {
  return text.replace(/sk-ant-[A-Za-z0-9_-]+/g, "sk-ant-***");
}

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

export async function handle(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json(405, { error: "Método no permitido." });
  try {
    const authorization = req.headers.get("Authorization");
    if (!authorization) throw new HttpError(401, "Inicia sesión para usar la evaluación.");
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      publicKey((n) => Deno.env.get(n)),
      { global: { headers: { Authorization: authorization } } },
    );
    const body = parseRequest(await req.json());
    const apiKey = anthropicKey(Deno.env.get("ANTHROPIC_API_KEY"));

    // Sin permiso explícito, las fotos del cuerpo no salen hacia la IA.
    const { data: consent, error: consentError } = await supabase
      .from("ai_consents")
      .select("feature")
      .eq("feature", "body")
      .maybeSingle();
    if (consentError) throw new HttpError(401, "Tu sesión no es válida. Vuelve a entrar.");
    if (!consent) throw new HttpError(403, "Primero acepta enviar tus fotos a la IA.");

    const { error: limitError } = await supabase.rpc("ai_consume", {
      p_feature: "body",
      p_limit: DAILY_LIMIT,
    });
    if (limitError) {
      if (limitError.message.includes("limit_reached")) {
        throw new HttpError(429, `Llegaste al límite de ${DAILY_LIMIT} evaluaciones por hoy.`);
      }
      throw new HttpError(401, "Tu sesión no es válida. Vuelve a entrar.");
    }

    const result = await assess(new Anthropic({ apiKey }), body);
    return json(200, result);
  } catch (e) {
    if (e instanceof HttpError) return json(e.status, { error: e.message });
    console.error("ai-body", redact(e instanceof Error ? e.message : "error"));
    return json(500, { error: "No se pudo evaluar. Intenta de nuevo." });
  }
}

Deno.serve(handle);
