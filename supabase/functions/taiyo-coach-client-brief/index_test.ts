import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  buildCoachClientContext,
  normalizeCoachCopilotResponse,
} from "./engine.ts";
import { handleTaiyoCoachClientBriefRequest } from "./index.ts";

Deno.test("taiyo-coach-client-brief rejects missing auth with 401", async () => {
  const response = await handleTaiyoCoachClientBriefRequest(
    new Request("https://example.com/taiyo-coach-client-brief", {
      method: "POST",
      body: "{}",
    }),
  );

  assertEquals(response.status, 401);
  const body = await response.json();
  assertEquals(body.status, "error");
  assertEquals(body.error, "Missing auth token");
});

Deno.test("taiyo-coach-client-brief rejects non-coach profiles with 403", async () => {
  const response = await handleTaiyoCoachClientBriefRequest(
    request({ request_type: "coach_client_brief" }),
    {
      authenticate: async () => ({ id: "user-1" }),
      getProfileRole: async () => "seller",
    },
  );

  assertEquals(response.status, 403);
  const body = await response.json();
  assertMatch(String(body.error), /coach accounts only/i);
});

Deno.test("taiyo-coach-client-brief rejects coach without ownership with 403", async () => {
  const response = await handleTaiyoCoachClientBriefRequest(
    request({ request_type: "coach_client_brief" }),
    {
      authenticate: async () => ({ id: "coach-1" }),
      getProfileRole: async () => "coach",
      loadContext: async () => {
        throw new Error("Coach client subscription not found.");
      },
    },
  );

  assertEquals(response.status, 403);
  const body = await response.json();
  assertMatch(String(body.error), /subscription not found/i);
});

Deno.test("taiyo-coach-client-brief returns needs_visibility_permission", async () => {
  const response = await handleTaiyoCoachClientBriefRequest(
    request({ request_type: "coach_client_brief" }),
    {
      authenticate: async () => ({ id: "coach-1" }),
      getProfileRole: async () => "coach",
      loadContext: async () => baseRawContext({ visibility: {} }),
      callOrchestrator: async () => {
        throw new Error("orchestrator should not be called");
      },
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.status, "needs_visibility_permission");
  assertMatch(String(body.result.summary), /visibility permission/i);
});

Deno.test("taiyo-coach-client-brief normalizes successful client brief", async () => {
  const response = await handleTaiyoCoachClientBriefRequest(
    request({ request_type: "coach_client_brief" }),
    {
      authenticate: async () => ({ id: "coach-1" }),
      getProfileRole: async () => "coach",
      loadContext: async () => baseRawContext(),
      callOrchestrator: async () =>
        '```json\n{"status":"success","result":{"client_status":"watch","summary":"Client needs adherence support.","red_flags":["low_adherence"],"suggested_action":"Send a check-in prompt.","suggested_message":"How did this week feel?","privacy_notes":["Draft only"],"risk_level":"medium"},"data_quality":{"confidence":"high"}}\n```',
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.request_type, "coach_client_brief");
  assertEquals(body.status, "success");
  assertEquals(body.result.client_status, "watch");
  assertEquals(body.result.suggested_message, "How did this week feel?");
  assertEquals(
    body.result.privacy_notes.includes("Suggested message is a draft only."),
    true,
  );
});

Deno.test("taiyo-coach-client-brief checkin_reply_draft returns draft only", async () => {
  const response = await handleTaiyoCoachClientBriefRequest(
    request({ request_type: "checkin_reply_draft" }),
    {
      authenticate: async () => ({ id: "coach-1" }),
      getProfileRole: async () => "coach",
      loadContext: async () => baseRawContext(),
      callOrchestrator: async () => ({
        status: "success",
        result: {
          client_status: "on_track",
          summary: "Check-in reviewed.",
          suggested_action: "Review and edit the draft.",
          suggested_message: "Nice work this week. What felt easiest?",
          privacy_notes: [],
          risk_level: "low",
        },
      }),
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.request_type, "checkin_reply_draft");
  assertEquals(body.status, "success");
  assertEquals(body.result.suggested_message.includes("Nice work"), true);
  assertEquals(
    body.result.privacy_notes.includes("Suggested message is a draft only."),
    true,
  );
});

Deno.test("taiyo-coach-client-brief handles malformed Azure output safely", async () => {
  const response = await handleTaiyoCoachClientBriefRequest(
    request({ request_type: "client_risk_summary" }),
    {
      authenticate: async () => ({ id: "coach-1" }),
      getProfileRole: async () => "coach",
      loadContext: async () => baseRawContext(),
      callOrchestrator: async () => "```json\nnot-json\n```",
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.status, "error");
  assertMatch(String(body.result.summary), /could not return/i);
});

Deno.test("normalizeCoachCopilotResponse strips fenced JSON", () => {
  const context = buildCoachClientContext("coach-1", baseRawContext(), {
    clientId: "member-1",
    subscriptionId: "sub-1",
    requestType: "coach_client_brief",
  });
  const normalized = normalizeCoachCopilotResponse(
    '```json\n{"status":"success","result":{"summary":"Client is stable.","client_status":"on_track","risk_level":"low"}}\n```',
    context,
    "coach_client_brief",
    { generatedAt: "2026-05-02T00:00:00.000Z" },
  );

  assertEquals(normalized.status, "success");
  assertEquals(normalized.result.summary, "Client is stable.");
  assertEquals(normalized.metadata.generated_at, "2026-05-02T00:00:00.000Z");
});

function request(body: Record<string, unknown>) {
  return new Request("https://example.com/taiyo-coach-client-brief", {
    method: "POST",
    headers: {
      "Authorization": "Bearer test-token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      client_id: "member-1",
      subscription_id: "sub-1",
      ...body,
    }),
  });
}

function baseRawContext(
  overrides: { visibility?: Record<string, unknown> } = {},
) {
  const visibility = overrides.visibility ?? {
    share_ai_plan_summary: true,
    share_workout_adherence: true,
    share_progress_metrics: false,
    share_nutrition_summary: false,
  };
  return {
    subscription: {
      id: "sub-1",
      member_id: "member-1",
      coach_id: "coach-1",
      status: "active",
    },
    workspace: {
      client: {
        subscription_id: "sub-1",
        member_id: "member-1",
        member_name: "Member One",
        status: "active",
        risk_status: "none",
        risk_flags: [],
        last_checkin_at: "2026-05-01T00:00:00Z",
      },
      visibility,
      checkins: [
        {
          id: "checkin-1",
          week_start: "2026-04-27",
          adherence_score: 55,
          workouts_completed: 2,
          missed_workouts: 1,
          pain_warning: "",
          support_needed: "Need motivation",
        },
      ],
      notes: [{ id: "note-1", note: "Prefers short replies." }],
      threads: [{ id: "thread-1" }],
    },
    visibility,
    member_insight: {
      member_id: "member-1",
      member_name: "Member One",
      current_goal: "strength",
      subscription_status: "active",
      adherence_insight: { completion_rate: 55, missed_tasks: 1 },
      risk_flags: [],
    },
    messages: [
      {
        id: "message-1",
        sender_role: "member",
        message_type: "text",
        content: "I missed one session.",
        created_at: "2026-05-01T00:00:00Z",
      },
    ],
  };
}
