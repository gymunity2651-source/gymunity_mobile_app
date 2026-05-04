import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  authenticateTaiyoRequest,
  createContextToken,
  createSupabaseClients,
  type SupabasePair,
} from "../_shared/taiyo_action_auth.ts";
import {
  buildMemberContext,
  dateOnly,
  obj,
  str,
} from "../taiyo-daily-brief/engine.ts";

type HandlerDeps = {
  getEnv?: (name: string) => string;
  authenticate?: (token: string) => Promise<{ id: string }>;
  getProfileRole?: (userId: string) => Promise<string | null>;
  loadContext?: (
    input: { memberId: string; targetDate: string; authMode: string },
  ) => Promise<Record<string, unknown>>;
};

if (import.meta.main) {
  Deno.serve((req) => handleTaiyoMemberContextRequest(req));
}

export async function handleTaiyoMemberContextRequest(
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
    const authResult = await authenticateTaiyoRequest(req, "member_context", {
      getEnv,
      createClients: (token) => {
        clients ??= createSupabaseClients(token, getEnv);
        return clients;
      },
      authenticate: deps.authenticate,
      getProfileRole: deps.getProfileRole,
    });
    if (authResult.auth.role !== "member") {
      return jsonResponse({
        error: "TAIYO member context is available for member accounts only.",
      }, 403);
    }

    const body = obj(await req.json().catch(() => ({})));
    const targetDate = dateOnly(str(body.date) || str(body.target_date));
    const loadContext = deps.loadContext ||
      ((input) =>
        loadMemberContext(defaultSupabase(authResult, getEnv), input));
    const rawContext = await loadContext({
      memberId: authResult.auth.userId,
      targetDate,
      authMode: authResult.auth.authMode,
    });
    const context = buildMemberContext(authResult.auth.userId, rawContext);
    const contextToken = authResult.auth.authMode === "user_jwt"
      ? await createContextToken({
        sub: authResult.auth.userId,
        role: "member",
        scope: "taiyo:any",
      }, getEnv).catch(() => null)
      : null;

    return jsonResponse({
      request_type: "member_context",
      status: "success",
      result: context,
      metadata: {
        source: "supabase_edge_function",
        auth_mode: authResult.auth.authMode,
        generated_at: new Date().toISOString(),
        ...(contextToken ? { context_token: contextToken } : {}),
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = errorStatus(message);
    return jsonResponse({
      request_type: "member_context",
      status: "error",
      error: publicError(message, status),
      metadata: {
        source: "supabase_edge_function",
        generated_at: new Date().toISOString(),
      },
    }, status);
  }
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

export async function loadMemberContext(
  supabase: SupabaseClient,
  input: { memberId: string; targetDate: string; authMode: string },
) {
  if (input.authMode === "user_jwt") {
    const { data, error } = await supabase.rpc("get_member_ai_coach_context", {
      input_target_date: input.targetDate,
    });
    if (!error) return obj(data);
  }

  const [
    memberProfile,
    readiness,
    sessions,
    taskLogs,
    todayTasks,
    nutrition,
    latestWeight,
    memories,
  ] = await Promise.all([
    maybeSingle(
      supabase.from("member_profiles").select("*").eq("user_id", input.memberId)
        .maybeSingle(),
    ),
    maybeSingle(
      supabase.from("member_daily_readiness_logs").select("*")
        .eq("member_id", input.memberId)
        .eq("log_date", input.targetDate)
        .maybeSingle(),
    ),
    listRows(
      supabase.from("workout_sessions")
        .select(
          "id,title,performed_at,duration_minutes,readiness_score,difficulty_score,completion_rate,summary_json",
        )
        .eq("member_id", input.memberId)
        .order("performed_at", { ascending: false })
        .limit(20),
    ),
    listRows(
      supabase.from("workout_task_logs")
        .select(
          "task_id,completion_status,completion_percent,duration_minutes,difficulty_score,pain_score,logged_at",
        )
        .eq("member_id", input.memberId)
        .order("logged_at", { ascending: false })
        .limit(40),
    ),
    listRows(
      supabase.from("workout_plan_tasks")
        .select("id,task_type,title,duration_minutes,scheduled_date,sort_order")
        .eq("member_id", input.memberId)
        .eq("scheduled_date", input.targetDate)
        .order("sort_order", { ascending: true }),
    ),
    loadNutritionContext(supabase, input.memberId, input.targetDate),
    maybeSingle(
      supabase.from("member_weight_entries")
        .select("weight_kg,recorded_at")
        .eq("member_id", input.memberId)
        .order("recorded_at", { ascending: false })
        .limit(1)
        .maybeSingle(),
    ),
    listRows(
      supabase.from("ai_user_memories")
        .select("memory_key,memory_value_json")
        .eq("user_id", input.memberId)
        .limit(24),
    ),
  ]);

  return {
    member_profile: memberProfile,
    readiness,
    recent_sessions: sessions,
    recent_task_logs: taskLogs,
    today_tasks: todayTasks,
    nutrition,
    latest_weight: latestWeight,
    memories: memoryRowsToMap(memories),
  };
}

async function loadNutritionContext(
  supabase: SupabaseClient,
  memberId: string,
  targetDate: string,
) {
  const [target, mealLogs, plannedMeals, hydration, checkin] = await Promise
    .all([
      maybeSingle(
        supabase.from("nutrition_targets").select("*")
          .eq("member_id", memberId)
          .eq("status", "active")
          .order("created_at", { ascending: false })
          .limit(1)
          .maybeSingle(),
      ),
      listRows(
        supabase.from("meal_logs").select("id").eq("member_id", memberId)
          .eq("log_date", targetDate),
      ),
      listRows(
        supabase.from("member_planned_meals").select("id")
          .eq("member_id", memberId)
          .eq("plan_date", targetDate),
      ),
      listRows(
        supabase.from("hydration_logs").select("amount_ml")
          .eq("member_id", memberId)
          .eq("log_date", targetDate),
      ),
      maybeSingle(
        supabase.from("nutrition_checkins")
          .select(
            "week_start,adherence_score,hunger_score,energy_score,notes,suggested_adjustment_json",
          )
          .eq("member_id", memberId)
          .order("week_start", { ascending: false })
          .limit(1)
          .maybeSingle(),
      ),
    ]);
  return {
    target,
    meal_logs_today: mealLogs.length,
    planned_meals_today: plannedMeals.length,
    hydration_ml_today: hydration.reduce(
      (sum, row) => sum + (Number(obj(row).amount_ml) || 0),
      0,
    ),
    last_nutrition_checkin: checkin,
  };
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

function memoryRowsToMap(rows: Record<string, unknown>[]) {
  const result: Record<string, unknown> = {};
  for (const row of rows) {
    const key = str(row.memory_key);
    if (key) result[key] = row.memory_value_json;
  }
  return result;
}

function env(name: string) {
  const value = Deno.env.get(name)?.trim() || "";
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
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
    : "TAIYO member context failed.";
}

function errorMessage(error: unknown) {
  return error instanceof Error
    ? error.message
    : obj(error).message?.toString() || String(error);
}
