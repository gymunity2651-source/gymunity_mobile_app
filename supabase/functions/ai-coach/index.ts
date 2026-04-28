import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  buildAccountabilityNudges,
  buildDailyBrief,
  buildMemoryUpserts,
  buildWorkoutPrompt,
  compactStrings,
  dateOnly,
  memoryAllowlist,
  obj,
  startOfWeek,
  str,
} from "./engine.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const token = bearer(req);
    const serviceSupabase = createClient(
      env("SUPABASE_URL"),
      env("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false } },
    );
    const user = await authUser(serviceSupabase, token);
    const supabase = createClient(
      env("SUPABASE_URL"),
      env("SUPABASE_SERVICE_ROLE_KEY"),
      {
        auth: { persistSession: false },
        global: {
          headers: { Authorization: `Bearer ${token}` },
        },
      },
    );
    const body = obj(await req.json().catch(() => ({})));
    const mode = str(body.mode) || "refresh_daily_brief";

    switch (mode) {
      case "refresh_daily_brief":
        return await refreshDailyBrief(supabase, user.id, body);
      case "run_accountability_scan":
        return await runAccountabilityScan(supabase, user.id, body);
      case "workout_prompt":
        return await workoutPrompt(supabase, user.id, body);
      case "refresh_weekly_summary":
        return await refreshWeeklySummary(supabase, user.id, body);
      case "maintain_memory":
        return await maintainMemory(supabase, user.id, body);
      default:
        return jsonResponse({ error: "Unsupported ai-coach mode." }, 400);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = message === "Unauthorized" || message === "Missing auth token"
      ? 401
      : 400;
    return jsonResponse({ error: message }, status);
  }
});

async function refreshDailyBrief(
  supabase: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
) {
  const targetDate = dateOnly(str(body.target_date));
  const context = await loadContext(supabase, targetDate);
  const briefPayload = buildDailyBrief(context, targetDate);
  const { data: brief, error } = await supabase
    .from("member_ai_daily_briefs")
    .upsert(
      {
        member_id: userId,
        ...briefPayload,
      },
      { onConflict: "member_id,brief_date" },
    )
    .select()
    .single();
  if (error) throw new Error(error.message);

  const planId = str(obj(context.active_plan).id);
  if (planId) {
    await supabase
      .from("workout_plans")
      .update({
        last_ai_brief_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("id", planId)
      .eq("member_id", userId);
  }

  await maintainMemory(supabase, userId, {});
  return jsonResponse({ brief });
}

async function runAccountabilityScan(
  supabase: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
) {
  const targetDate = dateOnly(str(body.target_date));
  const context = await loadContext(supabase, targetDate);
  const nudges = buildAccountabilityNudges(context, targetDate);
  if (!nudges.length) {
    return jsonResponse({ nudges: [], count: 0 });
  }

  const nudgeRows = nudges.map((nudge) => ({
    member_id: userId,
    ...nudge,
    status: "pending",
    available_at: new Date(`${targetDate}T07:00:00.000Z`).toISOString(),
  }));
  const { data, error } = await supabase
    .from("member_ai_nudges")
    .upsert(nudgeRows, { onConflict: "member_id,external_key" })
    .select();
  if (error) throw new Error(error.message);

  const notificationRows = nudgeRows.map((nudge) => ({
    user_id: userId,
    type: "ai",
    title: nudge.title,
    body: nudge.body,
    external_key: nudge.external_key,
    available_at: nudge.available_at,
    data: {
      kind: "coach_nudge",
      action_type: nudge.action_type,
      action_payload: nudge.action_payload_json,
      why_short: nudge.why_short,
      signals_used: nudge.signals_used,
    },
  }));
  const notificationResult = await supabase
    .from("notifications")
    .upsert(notificationRows, { onConflict: "user_id,external_key" });
  if (notificationResult.error) {
    throw new Error(notificationResult.error.message);
  }

  return jsonResponse({ nudges: data || [], count: (data || []).length });
}

async function workoutPrompt(
  supabase: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
) {
  const sessionId = str(body.session_id);
  if (!sessionId) {
    return jsonResponse({ error: "session_id is required." }, 400);
  }
  const promptKind = str(body.prompt_kind) || "mid_session";
  const { data: session, error } = await supabase
    .from("member_active_workout_sessions")
    .select()
    .eq("id", sessionId)
    .eq("member_id", userId)
    .single();
  if (error || !session) {
    return jsonResponse({ error: "Active workout session not found." }, 404);
  }
  const context = await loadContext(
    supabase,
    dateOnly(str(obj(session).started_at)),
  );
  const prompt = buildWorkoutPrompt({
    context,
    session,
    promptKind,
  });

  const eventResult = await supabase.from("member_active_workout_events").insert({
    session_id: sessionId,
    member_id: userId,
    event_type: "prompt",
    event_payload_json: prompt,
  });
  if (eventResult.error) {
    throw new Error(eventResult.error.message);
  }

  return jsonResponse({ prompt });
}

async function refreshWeeklySummary(
  supabase: SupabaseClient,
  _userId: string,
  body: Record<string, unknown>,
) {
  const weekStart = startOfWeek(str(body.week_start));
  const { data, error } = await supabase.rpc("build_member_ai_weekly_summary", {
    input_week_start: weekStart,
  });
  if (error) throw new Error(error.message);
  return jsonResponse({ weekly_summary: data });
}

async function maintainMemory(
  supabase: SupabaseClient,
  userId: string,
  _body: Record<string, unknown>,
) {
  const targetDate = dateOnly(new Date());
  const context = await loadContext(supabase, targetDate);
  const keepRows = buildMemoryUpserts(context);
  const { data: existingRows, error: existingError } = await supabase
    .from("ai_user_memories")
    .select("id,memory_key")
    .eq("user_id", userId);
  if (existingError) {
    throw new Error(existingError.message);
  }
  const staleIds = (existingRows || [])
    .filter((row) => !memoryAllowlist.includes(String(row.memory_key)))
    .map((row) => String(row.id));
  if (staleIds.length) {
    const deleteResult = await supabase
      .from("ai_user_memories")
      .delete()
      .eq("user_id", userId)
      .in("id", staleIds);
    if (deleteResult.error) {
      throw new Error(deleteResult.error.message);
    }
  }

  if (!keepRows.length) {
    return jsonResponse({ kept_keys: [] });
  }

  const upsertRows = keepRows.map((row) => ({
    user_id: userId,
    memory_key: row.memory_key,
    memory_value_json: row.memory_value_json,
    confidence: row.confidence,
  }));
  const { error } = await supabase.from("ai_user_memories").upsert(upsertRows, {
    onConflict: "user_id,memory_key",
  });
  if (error) {
    throw new Error(error.message);
  }
  return jsonResponse({
    kept_keys: compactStrings(keepRows.map((row) => String(row.memory_key))),
  });
}

async function loadContext(supabase: SupabaseClient, targetDate: string) {
  const { data, error } = await supabase.rpc("get_member_ai_coach_context", {
    input_target_date: targetDate,
  });
  if (error) {
    throw new Error(error.message);
  }
  return obj(data);
}

function env(name: string) {
  const value = Deno.env.get(name)?.trim() || "";
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
}

function bearer(req: Request) {
  const header = req.headers.get("Authorization") || "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) throw new Error("Missing auth token");
  return match[1];
}

async function authUser(supabase: SupabaseClient, token: string) {
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) throw new Error("Unauthorized");
  return data.user;
}
