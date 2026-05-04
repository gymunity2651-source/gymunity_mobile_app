import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { callFoundryOrchestrator } from "../_shared/foundry.ts";
import {
  authenticateTaiyoRequest,
  createSupabaseClients,
  type SupabasePair,
} from "../_shared/taiyo_action_auth.ts";
import { dateOnly, obj, str } from "../taiyo-daily-brief/engine.ts";

type NutritionRequestType = "nutrition_context" | "nutrition_guidance";
type Confidence = "low" | "medium" | "high";

type HandlerDeps = {
  getEnv?: (name: string) => string;
  authenticate?: (token: string) => Promise<{ id: string }>;
  getProfileRole?: (userId: string) => Promise<string | null>;
  loadContext?: (
    input: { memberId: string; targetDate: string },
  ) => Promise<Record<string, unknown>>;
  callOrchestrator?: (input: Record<string, unknown>) => Promise<unknown>;
};

if (import.meta.main) {
  Deno.serve((req) => handleTaiyoNutritionContextRequest(req));
}

export async function handleTaiyoNutritionContextRequest(
  req: Request,
  deps: HandlerDeps = {},
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const getEnv = deps.getEnv || env;
  let clients: SupabasePair | null = null;
  try {
    const body = obj(await req.json().catch(() => ({})));
    const requestType = supportedRequestType(body.request_type);
    const targetDate = dateOnly(str(body.date) || str(body.target_date));
    const authResult = await authenticateTaiyoRequest(
      req,
      "nutrition_context",
      {
        getEnv,
        createClients: (token) => {
          clients ??= createSupabaseClients(token, getEnv);
          return clients;
        },
        authenticate: deps.authenticate,
        getProfileRole: deps.getProfileRole,
      },
    );
    if (authResult.auth.role !== "member") {
      return jsonResponse({
        error: "TAIYO nutrition context is available for member accounts only.",
      }, 403);
    }

    const loadContext = deps.loadContext ||
      ((input) =>
        loadNutritionContext(defaultSupabase(authResult, getEnv), input));
    const context = await loadContext({
      memberId: authResult.auth.userId,
      targetDate,
    });

    if (requestType === "nutrition_context") {
      return jsonResponse({
        request_type: requestType,
        status: "success",
        result: context,
        metadata: metadata(authResult.auth.authMode),
      });
    }

    const callOrchestrator = deps.callOrchestrator || callTaiyoOrchestrator;
    const aiOutput = await callOrchestrator({
      request_type: "nutrition_guidance",
      user_role: "member",
      nutrition_context: context,
      response_format: "json",
      instruction:
        "Return only valid JSON with nutrition_status, calorie_guidance, protein_focus, hydration_focus, meal_suggestion, warning, and confidence.",
    });
    const normalized = normalizeNutritionGuidance(aiOutput, context);
    return jsonResponse({
      request_type: requestType,
      status: "success",
      result: normalized,
      data_quality: dataQuality(context),
      metadata: metadata(authResult.auth.authMode),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = errorStatus(message);
    return jsonResponse({
      request_type: "nutrition_guidance",
      status: "error",
      error: publicError(message, status),
      result: fallbackGuidance({}),
      metadata: metadata("unknown"),
    }, status);
  }
}

export async function loadNutritionContext(
  supabase: SupabaseClient,
  input: { memberId: string; targetDate: string },
) {
  const [
    profile,
    target,
    mealPlan,
    day,
    plannedMeals,
    mealLogs,
    hydrationLogs,
    checkins,
  ] = await Promise.all([
    maybeSingle(
      supabase.from("nutrition_profiles").select("*").eq(
        "member_id",
        input.memberId,
      ).maybeSingle(),
    ),
    maybeSingle(
      supabase.from("nutrition_targets").select("*")
        .eq("member_id", input.memberId)
        .eq("status", "active")
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle(),
    ),
    maybeSingle(
      supabase.from("member_meal_plans").select("*")
        .eq("member_id", input.memberId)
        .eq("status", "active")
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle(),
    ),
    maybeSingle(
      supabase.from("member_meal_plan_days").select("*")
        .eq("member_id", input.memberId)
        .eq("plan_date", input.targetDate)
        .limit(1)
        .maybeSingle(),
    ),
    listRows(
      supabase.from("member_planned_meals")
        .select(
          "id,meal_type,title,calories,protein_g,carbs_g,fats_g,completed_at",
        )
        .eq("member_id", input.memberId)
        .eq("plan_date", input.targetDate)
        .order("sort_order", { ascending: true }),
    ),
    listRows(
      supabase.from("meal_logs")
        .select(
          "id,title,calories,protein_g,carbs_g,fats_g,log_date,completed_at",
        )
        .eq("member_id", input.memberId)
        .eq("log_date", input.targetDate),
    ),
    listRows(
      supabase.from("hydration_logs")
        .select("amount_ml,logged_at")
        .eq("member_id", input.memberId)
        .eq("log_date", input.targetDate),
    ),
    listRows(
      supabase.from("nutrition_checkins")
        .select(
          "week_start,adherence_score,hunger_score,energy_score,notes,suggested_adjustment_json",
        )
        .eq("member_id", input.memberId)
        .order("week_start", { ascending: false })
        .limit(4),
    ),
  ]);

  const hydrationMl = hydrationLogs.reduce(
    (sum, row) => sum + (Number(row.amount_ml) || 0),
    0,
  );
  const caloriesLogged = mealLogs.reduce(
    (sum, row) => sum + (Number(row.calories) || 0),
    0,
  );
  const proteinLogged = mealLogs.reduce(
    (sum, row) => sum + (Number(row.protein_g) || 0),
    0,
  );

  return {
    member_id: input.memberId,
    target_date: input.targetDate,
    profile,
    target,
    active_meal_plan: mealPlan,
    day,
    planned_meals: plannedMeals,
    meal_logs: mealLogs,
    hydration_logs: hydrationLogs,
    recent_checkins: checkins,
    summary: {
      planned_meals: plannedMeals.length,
      logged_meals: mealLogs.length,
      calories_logged: caloriesLogged,
      protein_logged_g: proteinLogged,
      hydration_logged_ml: hydrationMl,
      calorie_target: Number(day.target_calories) ||
        Number(target.target_calories) || null,
      protein_target_g: Number(day.protein_g) || Number(target.protein_g) ||
        null,
      hydration_target_ml: Number(day.hydration_ml) ||
        Number(target.hydration_ml) || null,
    },
  };
}

export async function callTaiyoOrchestrator(input: Record<string, unknown>) {
  return await callFoundryOrchestrator(input, {
    additionalInstructions:
      "You are the TAIYO Orchestrator. Return only one valid JSON object for nutrition_guidance. Keep advice practical, non-medical, and avoid extreme dieting.",
  });
}

export function normalizeNutritionGuidance(
  aiOutput: unknown,
  context: Record<string, unknown>,
) {
  const raw = typeof aiOutput === "string"
    ? parseJsonFromText(aiOutput)
    : aiOutput;
  const map = obj(raw);
  const result = obj(map.result).length ? obj(map.result) : map;
  return {
    nutrition_status: nonEmpty(result.nutrition_status) ||
      statusFromContext(context),
    calorie_guidance: nonEmpty(result.calorie_guidance) ||
      "Keep today's intake close to your active target without aggressive restriction.",
    protein_focus: nonEmpty(result.protein_focus) ||
      "Prioritize a protein-forward meal in your next eating window.",
    hydration_focus: nonEmpty(result.hydration_focus) ||
      "Keep water intake steady through the rest of the day.",
    meal_suggestion: nonEmpty(result.meal_suggestion) ||
      "Use a simple balanced meal built around protein, carbs, vegetables, and fluids.",
    warning: nonEmpty(result.warning) ||
      "General fitness nutrition guidance only, not medical nutrition advice.",
    confidence: confidence(result.confidence),
  };
}

function fallbackGuidance(context: Record<string, unknown>) {
  return normalizeNutritionGuidance({}, context);
}

function statusFromContext(context: Record<string, unknown>) {
  const summary = obj(context.summary);
  const calorieTarget = Number(summary.calorie_target) || 0;
  const calories = Number(summary.calories_logged) || 0;
  const hydrationTarget = Number(summary.hydration_target_ml) || 0;
  const hydration = Number(summary.hydration_logged_ml) || 0;
  if (!calorieTarget && !hydrationTarget) return "needs_setup";
  if (hydrationTarget && hydration < hydrationTarget * 0.5) {
    return "hydration_gap";
  }
  if (calorieTarget && calories < calorieTarget * 0.45) return "under_logged";
  return "on_track";
}

function dataQuality(context: Record<string, unknown>) {
  const missing = [
    Object.keys(obj(context.profile)).length ? null : "nutrition_profile",
    Object.keys(obj(context.target)).length ? null : "nutrition_target",
    Object.keys(obj(context.day)).length ? null : "meal_plan_day",
  ].filter(Boolean) as string[];
  return {
    missing_fields: missing,
    confidence: missing.length >= 2
      ? "low"
      : missing.length
      ? "medium"
      : "high",
  };
}

function supportedRequestType(value: unknown): NutritionRequestType {
  const text = str(value) || "nutrition_guidance";
  if (text === "nutrition_context" || text === "nutrition_guidance") {
    return text;
  }
  throw new Error("Unsupported request_type.");
}

async function maybeSingle(
  query: PromiseLike<{ data: unknown; error: unknown }>,
) {
  const { data, error } = await query;
  if (error) throw new Error(errorMessage(error));
  return obj(data);
}

async function listRows(query: PromiseLike<{ data: unknown; error: unknown }>) {
  const { data, error } = await query;
  if (error) throw new Error(errorMessage(error));
  return Array.isArray(data) ? data.map(obj) : [];
}

function metadata(authMode: string) {
  return {
    source: "supabase_edge_function",
    auth_mode: authMode,
    generated_at: new Date().toISOString(),
  };
}

function confidence(value: unknown): Confidence {
  return value === "high" || value === "medium" || value === "low"
    ? value
    : "medium";
}

function nonEmpty(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function parseJsonFromText(text: string) {
  const trimmed = text.trim();
  try {
    return JSON.parse(trimmed);
  } catch {
    const match = trimmed.match(/\{[\s\S]*\}/);
    if (!match) return {};
    try {
      return JSON.parse(match[0]);
    } catch {
      return {};
    }
  }
}

function env(name: string) {
  const value = Deno.env.get(name)?.trim() || "";
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
}

function defaultSupabase(
  authResult: Awaited<ReturnType<typeof authenticateTaiyoRequest>>,
  getEnv: (name: string) => string,
) {
  if (authResult.clients) return authResult.clients.userSupabase;
  return createClient(
    getEnv("SUPABASE_URL"),
    getEnv("SUPABASE_SERVICE_ROLE_KEY"),
    {
      auth: { persistSession: false },
    },
  );
}

function errorStatus(message: string) {
  const lower = message.toLowerCase();
  if (message === "Missing auth token" || message === "Unauthorized") {
    return 401;
  }
  if (lower.includes("context token")) return 401;
  if (lower.includes("member accounts only")) return 403;
  return 500;
}

function publicError(message: string, status: number) {
  return status === 401 || status === 403
    ? message
    : "TAIYO nutrition context failed.";
}

function errorMessage(error: unknown) {
  return error instanceof Error
    ? error.message
    : obj(error).message?.toString() || String(error);
}
