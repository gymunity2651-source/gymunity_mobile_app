import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  buildPlannerContext,
  normalizeWorkoutPlannerResponse,
} from "./engine.ts";
import { handleTaiyoWorkoutPlannerRequest } from "./index.ts";

const validAnswers = {
  goal: "strength",
  experience_level: "beginner",
  days_per_week: 3,
  session_minutes: 45,
  equipment: ["dumbbells"],
  limitations: [],
};

Deno.test("taiyo-workout-planner rejects missing auth with 401", async () => {
  const response = await handleTaiyoWorkoutPlannerRequest(
    new Request("https://example.com/taiyo-workout-planner", {
      method: "POST",
      body: "{}",
    }),
  );

  assertEquals(response.status, 401);
  const body = await response.json();
  assertEquals(body.status, "error");
  assertEquals(body.error, "Missing auth token");
});

Deno.test("taiyo-workout-planner rejects non-member profiles with 403", async () => {
  const response = await handleTaiyoWorkoutPlannerRequest(
    request({ planner_answers: validAnswers }),
    {
      authenticate: async () => ({ id: "user-1" }),
      getProfileRole: async () => "coach",
    },
  );

  assertEquals(response.status, 403);
  const body = await response.json();
  assertMatch(String(body.error), /member accounts only/i);
});

Deno.test("taiyo-workout-planner returns needs_more_context for missing critical answers", async () => {
  const response = await handleTaiyoWorkoutPlannerRequest(
    request({
      planner_answers: { goal: "strength" },
    }),
    {
      authenticate: async () => ({ id: "user-1" }),
      getProfileRole: async () => "member",
      loadContext: async () => baseRawContext(),
      callOrchestrator: async () => {
        throw new Error("orchestrator should not be called");
      },
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.status, "needs_more_context");
  assertEquals(body.result.activation_allowed, false);
  assertEquals(body.metadata.persisted, false);
  assertEquals(body.data_quality.missing_fields.includes("equipment"), true);
});

Deno.test("taiyo-workout-planner blocks high-risk safety responses", async () => {
  const response = await handleTaiyoWorkoutPlannerRequest(
    request({
      planner_answers: {
        ...validAnswers,
        limitations: ["severe pain and dizziness"],
      },
    }),
    {
      authenticate: async () => ({ id: "user-1" }),
      getProfileRole: async () => "member",
      loadContext: async () => baseRawContext(),
      callOrchestrator: async () => {
        throw new Error("orchestrator should not be called for safety block");
      },
      saveDraft: async (_memberId, sessionId, normalized) => {
        assertEquals(normalized.status, "blocked_for_safety");
        assertEquals(normalized.result.activation_allowed, false);
        assertEquals(Object.keys(normalized.plan_json).length, 0);
        return {
          persisted: true,
          draft_id: "draft-safe",
          session_id: sessionId || "session-1",
        };
      },
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.status, "blocked_for_safety");
  assertEquals(body.result.activation_allowed, false);
  assertEquals(body.metadata.persisted, true);
});

Deno.test("taiyo-workout-planner normalizes fenced JSON and persists a safe plan", async () => {
  const response = await handleTaiyoWorkoutPlannerRequest(
    request({ planner_answers: validAnswers, session_id: "session-1" }),
    {
      authenticate: async () => ({ id: "user-1" }),
      getProfileRole: async () => "member",
      loadContext: async () => baseRawContext(),
      callOrchestrator: async () =>
        '```json\n{"status":"success","result":{"plan_goal":"strength","summary":"Three steady strength days.","weekly_structure":[{"day":"Monday","focus":"Full body strength","tasks":["Goblet squat","Dumbbell row"]}],"safety_notes":[],"progression_rule":"Add reps first.","deload_rule":"Reduce volume if readiness drops.","activation_allowed":true}}\n```',
      saveDraft: async (_memberId, sessionId, normalized) => {
        assertEquals(normalized.status, "success");
        assertEquals(normalized.result.activation_allowed, true);
        assertEquals(Object.keys(normalized.plan_json).length > 0, true);
        return {
          persisted: true,
          draft_id: "draft-1",
          session_id: sessionId || "session-1",
        };
      },
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.status, "success");
  assertEquals(body.metadata.persisted, true);
  assertEquals(body.metadata.draft_id, "draft-1");
  assertEquals(body.result.weekly_structure.length, 1);
});

Deno.test("taiyo-workout-planner handles malformed Azure output safely", async () => {
  const response = await handleTaiyoWorkoutPlannerRequest(
    request({ planner_answers: validAnswers }),
    {
      authenticate: async () => ({ id: "user-1" }),
      getProfileRole: async () => "member",
      loadContext: async () => baseRawContext(),
      callOrchestrator: async () => "```json\nnot-json\n```",
      saveDraft: async () => {
        throw new Error("save should not be called for malformed output");
      },
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.status, "error");
  assertEquals(body.result.activation_allowed, false);
  assertEquals(body.metadata.persisted, false);
});

Deno.test("normalizeWorkoutPlannerResponse maps a valid plan to activation-ready JSON", () => {
  const context = buildPlannerContext("user-1", baseRawContext(), validAnswers);
  const normalized = normalizeWorkoutPlannerResponse(
    {
      status: "success",
      result: {
        summary: "A simple strength plan.",
        weekly_structure: [
          {
            day: "Day 1",
            focus: "Strength",
            tasks: [{ title: "Squat", instructions: "Controlled reps" }],
          },
        ],
        activation_allowed: true,
      },
    },
    context,
    "workout_plan_draft",
    { generatedAt: "2026-04-29T00:00:00.000Z" },
  );

  assertEquals(normalized.status, "success");
  assertEquals(normalized.result.activation_allowed, true);
  assertEquals(normalized.metadata.generated_at, "2026-04-29T00:00:00.000Z");
  assertEquals(normalized.plan_json.weekly_structure instanceof Array, true);
});

function request(body: Record<string, unknown>) {
  return new Request("https://example.com/taiyo-workout-planner", {
    method: "POST",
    headers: {
      "Authorization": "Bearer test-token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      request_type: "workout_plan_draft",
      ...body,
    }),
  });
}

function baseRawContext() {
  return {
    coach_context: {
      member_profile: {
        goal: "strength",
        experience_level: "beginner",
        injuries: [],
      },
      preferences: { language: "en", measurement_unit: "metric" },
      readiness: {
        readiness_score: 72,
        sleep_hours: 7,
        energy_level: 4,
        soreness_level: 2,
        stress_level: 2,
      },
      active_plan: {},
      recent_sessions: [],
      recent_task_logs: [],
      today_tasks: [],
      nutrition: { target: { hydration_ml: 2500 } },
    },
    memories: [],
    current_draft: {},
    recent_readiness: [],
  };
}
