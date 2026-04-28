import { assertEquals, assertMatch } from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  buildAccountabilityNudges,
  buildDailyBrief,
  buildMemoryUpserts,
  buildWorkoutPrompt,
  signalsForBrief,
} from "./engine.ts";

function baseContext() {
  return {
    readiness: {
      readiness_score: 62,
      available_minutes: 30,
    },
    active_plan: {
      id: "plan-1",
      source: "ai",
      adaptation_mode: "semi_auto",
    },
    active_subscription: {},
    today_day: {
      id: "day-1",
      label: "Upper Strength",
      focus: "Upper-body strength",
    },
    today_tasks: [
      {
        id: "task-1",
        title: "Bench Press",
        task_type: "workout",
        duration_minutes: 30,
        is_required: true,
      },
    ],
    recent_sessions: [
      { title: "Upper Strength", duration_minutes: 46, performed_at: "2026-04-20T08:00:00Z" },
      { title: "Lower Strength", duration_minutes: 42, performed_at: "2026-04-17T08:00:00Z" },
    ],
    recent_task_logs: [
      { completion_status: "completed", logged_at: "2026-04-20T08:00:00Z" },
      { completion_status: "partial", logged_at: "2026-04-18T08:00:00Z" },
      { completion_status: "skipped", logged_at: "2026-04-16T08:00:00Z" },
    ],
    nutrition: {
      meal_logs_today: 1,
      planned_meals_today: 3,
      hydration_ml_today: 500,
      target: { hydration_ml: 2500 },
      last_nutrition_checkin: { adherence_score: 55 },
    },
  };
}

Deno.test("buildDailyBrief produces a finishable workout recommendation with explanation", () => {
  const brief = buildDailyBrief(baseContext(), "2026-04-21");
  assertEquals(brief.recommended_workout_json.title, "Bench Press");
  assertEquals(brief.intensity_band, "yellow");
  assertEquals(brief.recommended_actions_json.length, 7);
  assertMatch(String(brief.why_short), /taiyo|today|training/i);
});

Deno.test("buildAccountabilityNudges generates nutrition and recovery interventions", () => {
  const nudges = buildAccountabilityNudges(
    {
      ...baseContext(),
      readiness: { readiness_score: 30, available_minutes: 20 },
      recent_task_logs: [
        { completion_status: "skipped", logged_at: "2026-04-20T08:00:00Z" },
        { completion_status: "missed", logged_at: "2026-04-19T08:00:00Z" },
        { completion_status: "missed", logged_at: "2026-04-18T08:00:00Z" },
        { completion_status: "skipped", logged_at: "2026-04-17T08:00:00Z" },
      ],
    },
    "2026-04-21",
  );

  assertEquals(nudges[0].nudge_type, "restart_week");
  assertEquals(nudges[1].nudge_type, "nutrition_inconsistency");
  assertEquals(nudges[2].nudge_type, "recovery_recommendation");
});

Deno.test("buildWorkoutPrompt uses readiness and pace context", () => {
  const prompt = buildWorkoutPrompt({
    context: baseContext(),
    session: {
      summary_json: { day_label: "Upper Strength", day_focus: "Upper-body strength" },
      pace_delta_percent: -8,
    },
    promptKind: "mid_session",
  });

  assertMatch(String(prompt.message), /behind your usual pace|pace/i);
});

Deno.test("buildMemoryUpserts only produces allowlisted memories", () => {
  const rows = buildMemoryUpserts({
    ...baseContext(),
    recent_task_logs: [
      { completion_status: "missed", logged_at: "2026-04-20T08:00:00Z" },
      { completion_status: "skipped", logged_at: "2026-04-18T08:00:00Z" },
      { completion_status: "missed", logged_at: "2026-04-16T08:00:00Z" },
    ],
  });

  assertEquals(rows.every((row) => typeof row.memory_key === "string"), true);
  assertEquals(rows.some((row) => row.memory_key === "best_duration_minutes"), true);
  assertEquals(rows.some((row) => row.memory_key === "schedule_constraints"), true);
});

Deno.test("signalsForBrief detects coach mode safely", () => {
  const signals = signalsForBrief({
    ...baseContext(),
    active_plan: {
      id: "plan-1",
      source: "coach",
      adaptation_mode: "coach_locked",
      coach_id: "coach-1",
    },
  });

  assertEquals(signals.coachMode, true);
});
