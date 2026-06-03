import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  briefPersistencePayload,
  buildMemberContext,
  normalizeAiDailyBrief,
} from "./engine.ts";
import { handleTaiyoDailyBriefRequest } from "./index.ts";

Deno.test("taiyo-daily-brief rejects missing auth with 401", async () => {
  const response = await handleTaiyoDailyBriefRequest(
    new Request("https://example.com/taiyo-daily-brief", {
      method: "POST",
      body: "{}",
    }),
  );

  assertEquals(response.status, 401);
  const body = await response.json();
  assertEquals(body.status, "error");
  assertEquals(body.error, "Missing auth token");
});

Deno.test("taiyo-daily-brief rejects non-member profiles with 403", async () => {
  const response = await handleTaiyoDailyBriefRequest(
    new Request("https://example.com/taiyo-daily-brief", {
      method: "POST",
      headers: {
        "Authorization": "Bearer test-token",
        "Content-Type": "application/json",
      },
      body: "{}",
    }),
    {
      authenticate: async () => ({ id: "user-1" }),
      getProfileRole: async () => "coach",
    },
  );

  assertEquals(response.status, 403);
  const body = await response.json();
  assertMatch(String(body.error), /member accounts only/i);
});

Deno.test("buildMemberContext handles missing member data without crashing", () => {
  const context = buildMemberContext("user-1", {
    member_profile: {},
    recent_sessions: [],
    recent_task_logs: [],
    today_tasks: [],
    nutrition: {},
    memories: {},
  });

  assertEquals(context.member_id, "user-1");
  assertEquals(context.role, "member");
  assertEquals(context.profile.goal, "unknown");
  assertEquals(context.readiness.score, null);
  assertEquals(context.safety_flags.includes("missing_readiness_data"), true);
  assertEquals(
    context.data_quality.critical_missing_fields.includes("readiness"),
    true,
  );
  assertEquals(
    context.data_quality.optional_missing_fields.includes("latest_weight"),
    true,
  );
  assertEquals(context.data_quality.confidence, "low");
});

Deno.test("taiyo-daily-brief handles malformed Azure output safely", async () => {
  const response = await handleTaiyoDailyBriefRequest(
    new Request("https://example.com/taiyo-daily-brief", {
      method: "POST",
      headers: {
        "Authorization": "Bearer test-token",
        "Content-Type": "application/json",
      },
      body: "{}",
    }),
    {
      authenticate: async () => ({ id: "user-1" }),
      getProfileRole: async () => "member",
      loadContext: async () => ({
        member_profile: { goal: "strength", experience_level: "intermediate" },
        readiness: {
          readiness_score: 72,
          energy_level: 4,
          soreness_level: 2,
          stress_level: 2,
        },
        recent_sessions: [],
        recent_task_logs: [],
        today_tasks: [{
          id: "task-1",
          title: "Upper strength",
          is_required: true,
        }],
        nutrition: { target: { hydration_ml: 2500 }, hydration_ml_today: 1800 },
      }),
      callOrchestrator: async () => "```json\nnot-json\n```",
      saveDailyBrief: async () => {
        throw new Error("save should not be called for malformed output");
      },
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.status, "error");
  assertMatch(String(body.result.motivation_message), /could not return/i);
  assertEquals(body.metadata.persisted, false);
});

Deno.test("normalizeAiDailyBrief strips fenced JSON and returns app-ready shape", () => {
  const context = buildMemberContext("user-1", {
    member_profile: { goal: "fat_loss", experience_level: "beginner" },
    readiness: {
      readiness_score: 61,
      energy_level: 3,
      soreness_level: 2,
      stress_level: 2,
    },
    today_tasks: [{ title: "Mobility", is_required: true }],
    recent_task_logs: [],
    nutrition: { target: { hydration_ml: 2400 }, hydration_ml_today: 1600 },
  });

  const brief = normalizeAiDailyBrief(
    '```json\n{"status":"success","result":{"training_decision":"train","workout_focus":"strength","nutrition_focus":"protein","risk_level":"low","motivation_message":"Keep it steady.","safety_notes":[]}}\n```',
    context,
    { generatedAt: "2026-04-29T00:00:00.000Z" },
  );

  assertEquals(brief.status, "success");
  assertEquals(brief.result.workout_focus, "strength");
  assertEquals(brief.metadata.generated_at, "2026-04-29T00:00:00.000Z");
});

Deno.test("normalizeAiDailyBrief returns needs_more_context for critical gaps", () => {
  const context = buildMemberContext("user-1", {
    member_profile: { goal: "fat_loss", experience_level: "beginner" },
    recent_sessions: [],
    recent_task_logs: [],
    today_tasks: [],
    nutrition: {},
  });

  const brief = normalizeAiDailyBrief(
    '{"status":"success","result":{"training_decision":"setup","workout_focus":"builder","nutrition_focus":"target","risk_level":"low","motivation_message":"Add context.","safety_notes":[]}}',
    context,
  );

  assertEquals(brief.status, "needs_more_context");
});

Deno.test("briefPersistencePayload writes UI-compatible fields and actions", () => {
  const context = {
    active_plan: {
      id: "plan-1",
      adaptation_mode: "semi_auto",
      coach_id: null,
    },
    today_day: { id: "day-1" },
    today_tasks: [{
      id: "task-1",
      is_required: true,
      duration_minutes: 42,
      substitution_options_json: [{ title: "DB row" }],
    }],
    readiness: { readiness_score: 81 },
    nutrition: { target: { hydration_ml: 2400 } },
    active_subscription: null,
  };
  const memberContext = buildMemberContext("user-1", context);
  const brief = normalizeAiDailyBrief(
    '{"status":"success","result":{"training_decision":"Train normally","workout_focus":"Upper strength","nutrition_focus":"Protein with lunch","risk_level":"low","motivation_message":"Start strong.","safety_notes":[]}}',
    memberContext,
    { generatedAt: "2026-04-29T00:00:00.000Z" },
  );

  const payload = briefPersistencePayload(
    "user-1",
    "2026-04-29",
    context,
    brief,
  );

  assertEquals(payload.readiness_score, 81);
  assertEquals(payload.plan_id, "plan-1");
  assertEquals(payload.day_id, "day-1");
  assertEquals(payload.primary_task_id, "task-1");
  assertEquals(payload.recommended_workout_json.title, "Train normally");
  assertEquals(payload.recommended_workout_json.focus, "Upper strength");
  assertEquals(payload.recommended_workout_json.duration_minutes, 42);
  assertEquals(payload.habit_focus_json.body, "Start strong.");
  assertEquals(payload.nutrition_priority_json.body, "Protein with lunch");
  assertEquals(
    payload.recommended_actions_json.includes("start_workout"),
    true,
  );
  assertEquals(
    payload.recommended_actions_json.includes("swap_exercise"),
    true,
  );
});

Deno.test("briefPersistencePayload blocks unsafe workout actions for coach locked plans", () => {
  const context = {
    active_plan: {
      id: "plan-1",
      adaptation_mode: "coach_locked",
      coach_id: "coach-1",
    },
    today_day: { id: "day-1" },
    today_tasks: [{ id: "task-1", is_required: true }],
    readiness: { readiness_score: 72 },
    nutrition: { target: { hydration_ml: 2400 } },
  };
  const memberContext = buildMemberContext("user-1", context);
  const brief = normalizeAiDailyBrief(
    '{"status":"success","result":{"training_decision":"Train normally","workout_focus":"Upper strength","nutrition_focus":"Protein","risk_level":"low","motivation_message":"Start.","safety_notes":[]}}',
    memberContext,
  );

  const payload = briefPersistencePayload(
    "user-1",
    "2026-04-29",
    context,
    brief,
  );

  assertEquals(
    payload.recommended_actions_json.includes("move_to_tomorrow"),
    false,
  );
});

Deno.test("taiyo-daily-brief persists needs_more_context briefs", async () => {
  let saved = false;
  const response = await handleTaiyoDailyBriefRequest(
    new Request("https://example.com/taiyo-daily-brief", {
      method: "POST",
      headers: {
        "Authorization": "Bearer test-token",
        "Content-Type": "application/json",
      },
      body: "{}",
    }),
    {
      authenticate: async () => ({ id: "user-1" }),
      getProfileRole: async () => "member",
      loadContext: async () => ({
        member_profile: { goal: "strength", experience_level: "intermediate" },
        recent_sessions: [],
        recent_task_logs: [],
        today_tasks: [],
        nutrition: {},
      }),
      callOrchestrator: async () =>
        '{"status":"success","result":{"training_decision":"setup","workout_focus":"builder","nutrition_focus":"target","risk_level":"low","motivation_message":"Add context.","safety_notes":[]}}',
      saveDailyBrief: async () => {
        saved = true;
        return true;
      },
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.status, "needs_more_context");
  assertEquals(body.metadata.persisted, true);
  assertEquals(saved, true);
});
