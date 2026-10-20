// MAGRA · M6 — Edge Function "ai-photo".
//
// Recibe la foto de un plato o de una etiqueta nutricional y devuelve los
// alimentos con gramos y nutrientes estimados por Claude. La clave de la API
// vive solo aquí, como secreto ANTHROPIC_API_KEY (nunca en la app). La foto
// no se guarda.
//
// Despliegue: Supabase → Edge Functions → Deploy a new function → Via
// Editor → nombre "ai-photo" → pegar este archivo → Deploy (con "Verify
// JWT" activado). Secreto: Edge Functions → Secrets → ANTHROPIC_API_KEY.

import Anthropic from "npm:@anthropic-ai/sdk@0.132.1";
import { createClient } from "npm:@supabase/supabase-js@2.117.3";

/** Fotos por usuario al día. */
export const DAILY_LIMIT = 25;

/** Tamaño máximo de la imagen en base64 (~5 MB de imagen). */
export const MAX_BASE64_LENGTH = 7_000_000;

const MODEL = "claude-opus-5-5";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MEDIA_TYPES = ["image/jpeg", "image/png", "image/webp", "image/gif"] as const;
type MediaType = (typeof MEDIA_TYPES)[number];

export interface PhotoRequest {
  image: string;
  media_type: MediaType;
  mode: "plate" | "label";
  note?: string;
  remaining_kcal?: number;
}

export interface PhotoItem {
  name: string;
  quantity: number;
  unit: string;
  kcal: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
}

export interface PhotoResult {
  items: PhotoItem[];
  confidence: "alta" | "media" | "baja";
  notes: string;
}

/** Esquema de la respuesta que se le exige a Claude. */
export const RESULT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["items", "confidence", "notes"],
  properties: {
    items: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["name", "quantity", "unit", "kcal", "protein_g", "carbs_g", "fat_g"],
        properties: {
          name: { type: "string" },
          quantity: { type: "number" },
          unit: { type: "string", enum: ["g", "ml", "unidad"] },
          kcal: { type: "number" },
          protein_g: { type: "number" },
          carbs_g: { type: "number" },
          fat_g: { type: "number" },
        },
      },
    },
    confidence: { type: "string", enum: ["alta", "media", "baja"] },
    notes: { type: "string" },
  },
} as const;

export class HttpError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}

/** Valida el cuerpo que manda la app. */
export function parseRequest(body: unknown): PhotoRequest {
  const b = body as Partial<PhotoRequest> | null;
  if (!b || typeof b.image !== "string" || b.image.length < 100) {
    throw new HttpError(400, "Falta la imagen.");
  }
  if (b.image.length > MAX_BASE64_LENGTH) {
    throw new HttpError(413, "La imagen es demasiado grande.");
  }
  if (!MEDIA_TYPES.includes(b.media_type as MediaType)) {
    throw new HttpError(400, "Formato de imagen no soportado.");
  }
  if (b.mode !== "plate" && b.mode !== "label") {
    throw new HttpError(400, "Modo inválido.");
  }
  const note = typeof b.note === "string" ? b.note.slice(0, 300) : undefined;
  const remaining =
    typeof b.remaining_kcal === "number" && Number.isFinite(b.remaining_kcal)
      ? Math.round(b.remaining_kcal)
      : undefined;
  return { image: b.image, media_type: b.media_type as MediaType, mode: b.mode, note, remaining_kcal: remaining };
}

/** Instrucciones para Claude según el modo. */
export function buildPrompt(req: PhotoRequest): string {
  const what =
    req.mode === "label"
      ? "La imagen es la etiqueta nutricional de un producto. Lee los valores " +
        "de UNA porción declarada y devuelve un solo item con esa porción."
      : "La imagen es un plato de comida. Identifica cada alimento visible y " +
        "estima sus gramos usando referencias de tamaño (plato, cubiertos, " +
        "manos). Cuenta el aceite de cocción si se ve frito o salteado.";
  return [
    "Eres el nutricionista de MAGRA, una app para bajar grasa en Chile y Latinoamérica.",
    what,
    "Usa nombres cortos en español de Chile. Cantidades en g, ml o unidad.",
    "Si la imagen no muestra comida, devuelve items vacío y explícalo en notes.",
    "En notes escribe una frase útil para la persona (máximo 160 caracteres).",
    req.remaining_kcal !== undefined
      ? `A la persona le quedan ${req.remaining_kcal} kcal hoy.`
      : "",
    req.note ? `Aclaración de la persona: ${req.note}` : "",
  ].filter(Boolean).join("\n");
}

const clamp = (v: unknown, max: number) => {
  const n = typeof v === "number" && Number.isFinite(v) ? v : 0;
  return Math.round(Math.min(Math.max(n, 0), max) * 10) / 10;
};

/** Valida y acota lo que devolvió el modelo. */
export function sanitizeResult(raw: unknown): PhotoResult {
  const r = raw as Partial<PhotoResult> | null;
  const items = Array.isArray(r?.items) ? r!.items.slice(0, 15) : [];
  return {
    items: items
      .filter((i) => i && typeof i.name === "string" && i.name.trim().length > 0)
      .map((i) => ({
        name: i.name.trim().slice(0, 120),
        quantity: clamp(i.quantity, 3000),
        unit: ["g", "ml", "unidad"].includes(i.unit) ? i.unit : "g",
        kcal: clamp(i.kcal, 5000),
        protein_g: clamp(i.protein_g, 500),
        carbs_g: clamp(i.carbs_g, 1000),
        fat_g: clamp(i.fat_g, 500),
      })),
    confidence: r?.confidence === "alta" || r?.confidence === "baja" ? r.confidence : "media",
    notes: typeof r?.notes === "string" ? r.notes.slice(0, 300) : "",
  };
}

/** Pide el análisis a Claude y devuelve el resultado validado. */
export async function analyzePhoto(client: Anthropic, req: PhotoRequest): Promise<PhotoResult> {
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
          { type: "image", source: { type: "base64", media_type: req.media_type, data: req.image } },
          { type: "text", text: buildPrompt(req) },
        ],
      },
    ],
  });
  if (response.stop_reason === "refusal") {
    throw new HttpError(422, "La IA no pudo analizar esta imagen.");
  }
  const text = response.content.find((b) => b.type === "text");
  if (!text || text.type !== "text") {
    throw new HttpError(502, "La IA no devolvió un resultado.");
  }
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
    if (!authorization) throw new HttpError(401, "Inicia sesión para usar la IA.");

    // Cliente con la sesión del usuario: ai_consume() usa su auth.uid().
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      publicKey((n) => Deno.env.get(n)),
      { global: { headers: { Authorization: authorization } } },
    );
    const photo = parseRequest(await req.json());
    // Antes de descontar una foto del límite diario.
    const apiKey = anthropicKey(Deno.env.get("ANTHROPIC_API_KEY"));

    const { error: limitError } = await supabase.rpc("ai_consume", {
      p_feature: "photo",
      p_limit: DAILY_LIMIT,
    });
    if (limitError) {
      if (limitError.message.includes("limit_reached")) {
        throw new HttpError(429, `Llegaste al límite de ${DAILY_LIMIT} fotos por hoy.`);
      }
      throw new HttpError(401, "Tu sesión no es válida. Vuelve a entrar.");
    }

    const result = await analyzePhoto(new Anthropic({ apiKey }), photo);
    return json(200, result);
  } catch (e) {
    if (e instanceof HttpError) return json(e.status, { error: e.message });
    console.error("ai-photo", redact(e instanceof Error ? e.message : "error"));
    return json(500, { error: "No se pudo analizar la foto. Intenta de nuevo." });
  }
}

/// El secreto debe ser solo la clave (sk-ant-…), sin comillas, espacios ni
/// el comando curl de ejemplo de la consola.
export function anthropicKey(raw: string | undefined): string {
  const key = (raw ?? "").trim();
  if (!key) throw new HttpError(500, "Falta configurar la IA en el servidor.");
  if (!/^sk-ant-[A-Za-z0-9_-]+$/.test(key)) {
    console.error("ai-photo", "ANTHROPIC_API_KEY mal configurada: debe ser solo la clave sk-ant-…");
    throw new HttpError(500, "La clave de la IA está mal configurada en el servidor.");
  }
  return key;
}

/// Nunca dejar una clave en los logs, aunque venga dentro de un error.
export function redact(text: string): string {
  return text.replace(/sk-ant-[A-Za-z0-9_-]+/g, "sk-ant-***");
}

Deno.serve(handle);
