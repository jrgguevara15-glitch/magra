// MAGRA · M11 — Edge Function "ai-menu".
//
// Arma el menú de la semana (o reemplaza una comida) dentro de los números
// que fija el motor de la app: cuántas comidas, a qué hora y cuántas
// calorías y macros lleva cada una. Claude solo elige los platos y las
// cantidades; no cambia las metas. Respeta dieta, alergias, alimentos que
// no le gustan, presupuesto y si cocina. La clave de la API vive solo aquí,
// como secreto ANTHROPIC_API_KEY.
//
// Despliegue: Supabase → Edge Functions → Deploy a new function → Via
// Editor → nombre "ai-menu" → pegar este archivo → Deploy.

import Anthropic from "npm:@anthropic-ai/sdk@0.132.1";
import { createClient } from "npm:@supabase/supabase-js@2.117.3";

/** Menús semanales por usuario al día. */
export const WEEK_DAILY_LIMIT = 3;

/** Cambios de una comida por usuario al día. */
export const SWAP_DAILY_LIMIT = 20;

const MODEL = "claude-opus-5-5";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export const DAY_NAMES = [
  "lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo",
];

export const CATEGORIES = [
  "Verduras y frutas",
  "Carnes, pollo y pescados",
  "Lácteos y huevos",
  "Panadería y cereales",
  "Abarrotes",
  "Congelados",
  "Otros",
] as const;

export interface Slot {
  time: string;
  role: "regular" | "pre" | "post";
  kcal: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
}

export interface Prefs {
  diet: string;
  allergies: string[];
  dislikes: string;
  budget: string;
  cooking: string;
}

export interface MenuRequest {
  mode: "week" | "meal";
  slots: Slot[];
  prefs: Prefs;
  /** Modo "meal": qué día (0 = lunes) y qué comida reemplazar. */
  day?: number;
  meal?: number;
  /** Platos que ya están en la semana (para no repetir). */
  avoid?: string[];
}

export interface MenuItem {
  food: string;
  quantity: number;
  unit: "g" | "ml" | "unidad";
  kcal: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  category: (typeof CATEGORIES)[number];
  brand: string;
}

export interface MenuMeal {
  name: string;
  prep: string;
  items: MenuItem[];
}

const ITEM_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["food", "quantity", "unit", "kcal", "protein_g", "carbs_g", "fat_g", "category", "brand"],
  properties: {
    food: { type: "string" },
    quantity: { type: "number" },
    unit: { type: "string", enum: ["g", "ml", "unidad"] },
    kcal: { type: "number" },
    protein_g: { type: "number" },
    carbs_g: { type: "number" },
    fat_g: { type: "number" },
    category: { type: "string", enum: [...CATEGORIES] },
    brand: { type: "string" },
  },
} as const;

const MEAL_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["name", "prep", "items"],
  properties: {
    name: { type: "string" },
    prep: { type: "string" },
    items: { type: "array", items: ITEM_SCHEMA },
  },
} as const;

export const DAY_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["meals"],
  properties: { meals: { type: "array", items: MEAL_SCHEMA } },
} as const;

export class HttpError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}

const num = (v: unknown, min: number, max: number): number | null =>
  typeof v === "number" && Number.isFinite(v) && v >= min && v <= max ? v : null;

const str = (v: unknown, max: number) =>
  typeof v === "string" ? v.trim().slice(0, max) : "";

/** Valida el cuerpo que manda la app. Las metas vienen del motor de reglas. */
export function parseRequest(body: unknown): MenuRequest {
  const b = body as Partial<MenuRequest> | null;
  if (b?.mode !== "week" && b?.mode !== "meal") throw new HttpError(400, "Modo inválido.");
  if (!Array.isArray(b.slots) || b.slots.length < 2 || b.slots.length > 6) {
    throw new HttpError(400, "El plan debe tener entre 2 y 6 comidas.");
  }
  const slots: Slot[] = b.slots.map((s) => {
    const kcal = num(s?.kcal, 50, 2500);
    const p = num(s?.protein_g, 0, 250);
    const c = num(s?.carbs_g, 0, 400);
    const f = num(s?.fat_g, 0, 150);
    const time = typeof s?.time === "string" && /^\d{2}:\d{2}$/.test(s.time) ? s.time : null;
    if (kcal === null || p === null || c === null || f === null || time === null) {
      throw new HttpError(400, "Metas de comida inválidas.");
    }
    const role = s.role === "pre" || s.role === "post" ? s.role : "regular";
    return { time, role, kcal: Math.round(kcal), protein_g: Math.round(p), carbs_g: Math.round(c), fat_g: Math.round(f) };
  });
  const total = slots.reduce((a, s) => a + s.kcal, 0);
  if (total < 800 || total > 6000) throw new HttpError(400, "Calorías del día fuera de rango.");
  const p = b.prefs as Partial<Prefs> | undefined;
  const prefs: Prefs = {
    diet: str(p?.diet, 60) || "Como de todo",
    allergies: Array.isArray(p?.allergies) ? p!.allergies.slice(0, 10).map((a) => str(a, 40)).filter(Boolean) : [],
    dislikes: str(p?.dislikes, 200),
    budget: str(p?.budget, 30) || "Medio",
    cooking: str(p?.cooking, 60) || "Cocino todos los días",
  };
  const avoid = Array.isArray(b.avoid) ? b.avoid.slice(0, 50).map((a) => str(a, 80)).filter(Boolean) : [];
  if (b.mode === "meal") {
    const day = num(b.day, 0, 6);
    const meal = num(b.meal, 0, slots.length - 1);
    if (day === null || meal === null || !Number.isInteger(day) || !Number.isInteger(meal)) {
      throw new HttpError(400, "Comida a cambiar inválida.");
    }
    return { mode: "meal", slots, prefs, day, meal, avoid };
  }
  return { mode: "week", slots, prefs, avoid };
}

/** Base del plato principal de cada día, para que la semana sea variada. */
export function dayThemes(diet: string): string[] {
  const d = diet.toLowerCase();
  if (d.includes("vegano")) {
    return ["legumbres", "tofu", "quinoa y garbanzos", "lentejas", "soya texturizada", "porotos", "seitán o tempeh"];
  }
  if (d.includes("vegetariano")) {
    return ["legumbres", "huevo", "quesillo y yogur", "tofu", "lentejas", "huevo", "garbanzos"];
  }
  if (d.includes("pescetariano")) {
    return ["pescado blanco", "huevo", "salmón", "legumbres", "atún", "mariscos o pescado", "huevo"];
  }
  return ["pollo", "vacuno magro", "pescado", "legumbres", "cerdo magro", "pavo", "huevo y vacuno"];
}

const roleText = (r: Slot["role"]) =>
  r === "pre" ? " (antes de entrenar)" : r === "post" ? " (después de entrenar)" : "";

/** Instrucciones para un día (o para reemplazar una comida). */
export function buildPrompt(req: MenuRequest, day: number, only?: number): string {
  const slots = only === undefined ? req.slots : [req.slots[only]];
  const meals = slots
    .map((s, i) =>
      `${i + 1}. ${s.time}${roleText(s.role)}: ${s.kcal} kcal, ${s.protein_g} g proteína, ` +
      `${s.carbs_g} g carbohidratos, ${s.fat_g} g grasa.`
    )
    .join("\n");
  const p = req.prefs;
  return [
    "Eres el nutricionista deportivo de MAGRA, una app para bajar grasa conservando músculo, en Chile.",
    only === undefined
      ? `Arma las comidas del ${DAY_NAMES[day]} (día ${day + 1} de 7). Devuelve exactamente ${slots.length} comidas, en este orden:`
      : `Propón UNA comida distinta para reemplazar la del ${DAY_NAMES[day]}. Devuelve exactamente 1 comida con esta meta:`,
    meals,
    "Cada comida debe sumar sus calorías y macros con un margen de ±10 %. No cambies las metas.",
    only === undefined
      ? `Para variar la semana, la proteína principal del almuerzo de hoy es: ${dayThemes(p.diet)[day]}.`
      : "",
    `Dieta: ${p.diet}.`,
    p.allergies.length ? `Alergias o intolerancias (PROHIBIDO incluirlas): ${p.allergies.join(", ")}.` : "",
    p.dislikes ? `No le gusta (no lo uses): ${p.dislikes}.` : "",
    `Presupuesto: ${p.budget}. Cocina: ${p.cooking}.`,
    req.avoid?.length ? `No repitas estos platos: ${req.avoid.join("; ")}.` : "",
    "Usa comida casera chilena y alimentos de supermercados chilenos (Lider, Jumbo, Unimarc, Tottus).",
    "name: nombre corto del plato. prep: preparación en una frase (máx. 140 caracteres).",
    "items: cada ingrediente con su nombre genérico de compra (ej. \"Pechuga de pollo\", \"Arroz\"), " +
    "cantidad en crudo en g, ml o unidad, sus nutrientes y la categoría del supermercado. " +
    "brand: una marca chilena común solo si es un producto envasado y estás seguro; si no, \"\".",
    "Proteína repartida, verduras en almuerzo y cena, y más carbohidratos cerca del entrenamiento.",
  ].filter(Boolean).join("\n");
}

const clamp = (v: unknown, max: number) => {
  const n = typeof v === "number" && Number.isFinite(v) ? v : 0;
  return Math.round(Math.min(Math.max(n, 0), max) * 10) / 10;
};

export function sanitizeMeal(raw: unknown): MenuMeal {
  const m = raw as Partial<MenuMeal> | null;
  const items = Array.isArray(m?.items) ? m!.items.slice(0, 12) : [];
  return {
    name: str(m?.name, 80) || "Comida",
    prep: str(m?.prep, 200),
    items: items
      .filter((i) => i && typeof i.food === "string" && i.food.trim().length > 0)
      .map((i) => ({
        food: i.food.trim().slice(0, 80),
        quantity: clamp(i.quantity, 3000),
        unit: ["g", "ml", "unidad"].includes(i.unit) ? i.unit : "g",
        kcal: clamp(i.kcal, 3000),
        protein_g: clamp(i.protein_g, 300),
        carbs_g: clamp(i.carbs_g, 500),
        fat_g: clamp(i.fat_g, 200),
        category: (CATEGORIES as readonly string[]).includes(i.category) ? i.category : "Otros",
        brand: str(i.brand, 40),
      })),
  };
}

/** Pide a Claude las comidas de un día y valida que vengan todas. */
export async function generateDay(
  client: Anthropic,
  req: MenuRequest,
  day: number,
  only?: number,
): Promise<MenuMeal[]> {
  const expected = only === undefined ? req.slots.length : 1;
  const response = await client.beta.messages.create({
    model: MODEL,
    max_tokens: 6000,
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    output_config: { format: { type: "json_schema", schema: DAY_SCHEMA } },
    messages: [{ role: "user", content: [{ type: "text", text: buildPrompt(req, day, only) }] }],
  });
  if (response.stop_reason === "refusal") {
    throw new HttpError(422, "La IA no pudo armar este menú.");
  }
  const text = response.content.find((b) => b.type === "text");
  if (!text || text.type !== "text") throw new HttpError(502, "La IA no devolvió un menú.");
  let parsed: { meals?: unknown[] };
  try {
    parsed = JSON.parse(text.text);
  } catch {
    throw new HttpError(502, "La IA devolvió un menú ilegible. Intenta de nuevo.");
  }
  const meals = Array.isArray(parsed.meals) ? parsed.meals.map(sanitizeMeal) : [];
  if (meals.length !== expected || meals.some((m) => m.items.length === 0)) {
    throw new HttpError(502, "La IA devolvió un menú incompleto. Intenta de nuevo.");
  }
  return meals;
}

/** Los 7 días en paralelo (cada uno tarda lo que tarda un día). */
export async function generateWeek(client: Anthropic, req: MenuRequest): Promise<MenuMeal[][]> {
  return await Promise.all(DAY_NAMES.map((_, d) => generateDay(client, req, d)));
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
    console.error("ai-menu", "ANTHROPIC_API_KEY mal configurada: debe ser solo la clave sk-ant-…");
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
    if (!authorization) throw new HttpError(401, "Inicia sesión para usar la IA.");
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      publicKey((n) => Deno.env.get(n)),
      { global: { headers: { Authorization: authorization } } },
    );
    const menu = parseRequest(await req.json());
    const apiKey = anthropicKey(Deno.env.get("ANTHROPIC_API_KEY"));

    const week = menu.mode === "week";
    const limit = week ? WEEK_DAILY_LIMIT : SWAP_DAILY_LIMIT;
    const { error: limitError } = await supabase.rpc("ai_consume", {
      p_feature: week ? "menu_week" : "menu_meal",
      p_limit: limit,
    });
    if (limitError) {
      if (limitError.message.includes("limit_reached")) {
        throw new HttpError(
          429,
          week
            ? `Llegaste al límite de ${limit} menús por hoy.`
            : `Llegaste al límite de ${limit} cambios de comida por hoy.`,
        );
      }
      throw new HttpError(401, "Tu sesión no es válida. Vuelve a entrar.");
    }

    const client = new Anthropic({ apiKey });
    if (week) return json(200, { days: await generateWeek(client, menu) });
    const [meal] = await generateDay(client, menu, menu.day!, menu.meal!);
    return json(200, { meal });
  } catch (e) {
    if (e instanceof HttpError) return json(e.status, { error: e.message });
    console.error("ai-menu", redact(e instanceof Error ? e.message : "error"));
    return json(500, { error: "No se pudo armar el menú. Intenta de nuevo." });
  }
}

Deno.serve(handle);
