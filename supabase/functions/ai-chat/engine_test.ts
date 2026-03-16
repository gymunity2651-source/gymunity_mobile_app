import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  buildMemoryPayload,
  buildPersonalizationUsed,
  buildSuggestedReplies,
  classifyConversationMode,
  criticalMissing,
  deriveSignals,
  emptyMemory,
  emptyProfile,
  mergeProfileSources,
  summarizeSessionState,
  type PlannerContextLike,
} from "./engine.ts";

function baseContext(): PlannerContextLike {
  return {
    profile_basics: { full_name: "Mona" },
    member_profile: { goal: "fat_loss", experience_level: "beginner" },
    preferences: { language: "english", measurement_unit: "metric" },
    latest_weight: { weight_kg: 72 },
    latest_measurement: { recorded_at: "2026-03-14T09:00:00Z" },
    recent_sessions: [
      { title: "Upper", performed_at: "2026-03-14T10:00:00Z", duration_minutes: 55 },
      { title: "Lower", performed_at: "2026-03-11T10:00:00Z", duration_minutes: 45 },
    ],
    active_ai_plan: { id: "plan-1", title: "Cut Plan" },
    prior_profile: {
      ...emptyProfile(),
      goal: "fat_loss",
      experience_level: "beginner",
      days_per_week: 4,
      session_minutes: 45,
      equipment: ["dumbbells"],
    },
    current_draft: {},
    memory: {
      ...emptyMemory(),
      preferred_days: ["tuesday", "thursday"],
      exercise_dislikes: ["burpees"],
    },
    session_state: { summary: "Using saved schedule preferences." },
    signals: {
      sessions_last_7d: 2,
      sessions_last_30d: 6,
      average_session_minutes: 50,
      days_since_last_workout: 1,
      active_plan_task_count: 12,
      adherence_scheduled_count: 8,
      adherence_completed_count: 6,
      adherence_partial_count: 1,
      adherence_completion_ratio: 0.81,
    },
  };
}

Deno.test("deriveSignals computes activity and adherence summaries", () => {
  const signals = deriveSignals({
    recentSessions: [
      { performed_at: "2026-03-14T10:00:00Z", duration_minutes: 60 },
      { performed_at: "2026-03-10T10:00:00Z", duration_minutes: 40 },
      { performed_at: "2026-02-20T10:00:00Z", duration_minutes: 50 },
    ],
    activePlanTasks: [
      { id: "1", scheduled_date: "2026-03-14" },
      { id: "2", scheduled_date: "2026-03-13" },
      { id: "3", scheduled_date: "2026-03-12" },
    ],
    taskLogs: [
      { task_id: "1", completion_status: "completed" },
      { task_id: "2", completion_status: "partial" },
    ],
    now: new Date("2026-03-15T12:00:00Z"),
  });

  assertEquals(signals.sessions_last_7d, 2);
  assertEquals(signals.sessions_last_30d, 3);
  assertEquals(signals.average_session_minutes, 50);
  assertEquals(signals.days_since_last_workout, 1);
  assertEquals(signals.adherence_scheduled_count, 3);
  assertEquals(signals.adherence_completed_count, 1);
  assertEquals(signals.adherence_partial_count, 1);
  assertEquals(signals.adherence_completion_ratio, 0.5);
});

Deno.test("mergeProfileSources reuses memory before asking for missing fields", () => {
  const profile = mergeProfileSources(
    {},
    { goal: "muscle_gain", experience_level: "intermediate" },
    { language: "english", measurement_unit: "metric" },
    {
      ...emptyMemory(),
      days_per_week: 4,
      session_minutes: 50,
      equipment: ["barbell", "bench"],
    },
  );

  assertEquals(criticalMissing(profile), []);
});

Deno.test("classifyConversationMode separates planner collect/generate/refine and progress checkins", () => {
  const ctx = baseContext();

  assertEquals(
    classifyConversationMode({
      sessionType: "planner",
      action: "reply",
      latestUserMessage: "Build my plan",
      ctx,
      draftRef: null,
    }),
    "planner_generate",
  );

  assertEquals(
    classifyConversationMode({
      sessionType: "planner",
      action: "regenerate_plan",
      latestUserMessage: "Make it easier",
      ctx,
      draftRef: { id: "draft-1" },
    }),
    "planner_refine",
  );

  assertEquals(
    classifyConversationMode({
      sessionType: "general",
      action: "reply",
      latestUserMessage: "Compare this week to last week and adjust my plan",
      ctx,
      draftRef: null,
    }),
    "progress_checkin",
  );
});

Deno.test("personalization and suggested replies reflect real user context", () => {
  const ctx = baseContext();
  const used = buildPersonalizationUsed(ctx, "progress_checkin");
  const replies = buildSuggestedReplies({
    conversationMode: "progress_checkin",
    missingFields: [],
    ctx,
  });

  assertEquals(used, [
    "profile basics",
    "goal",
    "saved schedule preferences",
    "exercise dislikes",
  ]);
  assertEquals(replies[0], "Compare this week to last week.");
});

Deno.test("buildMemoryPayload keeps stable profile facts and explicit long-term preferences", () => {
  const payload = buildMemoryPayload(
    {
      ...emptyProfile(),
      goal: "fat_loss",
      experience_level: "beginner",
      days_per_week: 4,
      session_minutes: 45,
      equipment: ["dumbbells"],
      limitations: ["knee pain"],
      preferred_language: "en",
      measurement_unit: "metric",
    },
    {
      preferred_days: ["tuesday", "thursday"],
      exercise_dislikes: ["burpees"],
      response_style: "concise",
    },
  );

  assertEquals(payload.preferred_days, ["tuesday", "thursday"]);
  assertEquals(payload.exercise_dislikes, ["burpees"]);
  assertEquals(payload.response_style, "concise");
  assertEquals(payload.goal, "fat_loss");
});

Deno.test("summarizeSessionState captures the latest intent and open loops", () => {
  const summary = summarizeSessionState({
    latestUserMessage: "I can only train three days this week because of work.",
    turnStatus: "needs_more_info",
    conversationMode: "planner_collect",
    ctx: baseContext(),
    missingFields: ["equipment", "session_minutes"],
  });

  assertEquals(summary.openLoops, ["equipment", "session_minutes"]);
  assertMatch(summary.summary, /waiting for equipment, session_minutes/i);
});
