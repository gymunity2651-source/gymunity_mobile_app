import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { createContextToken } from "../_shared/taiyo_action_auth.ts";
import { handleTaiyoMemberContextRequest } from "./index.ts";

Deno.test("taiyo-member-context rejects missing auth with 401", async () => {
  const response = await handleTaiyoMemberContextRequest(
    new Request("https://example.com/taiyo-member-context", {
      method: "POST",
      body: "{}",
    }),
  );

  assertEquals(response.status, 401);
  const body = await response.json();
  assertEquals(body.status, "error");
});

Deno.test("taiyo-member-context rejects non-member roles", async () => {
  const response = await handleTaiyoMemberContextRequest(
    new Request("https://example.com/taiyo-member-context", {
      method: "POST",
      headers: { Authorization: "Bearer token" },
      body: "{}",
    }),
    {
      authenticate: async () => ({ id: "coach-1" }),
      getProfileRole: async () => "coach",
    },
  );

  assertEquals(response.status, 403);
  const body = await response.json();
  assertMatch(String(body.error), /member accounts only/i);
});

Deno.test("taiyo-member-context accepts scoped action token", async () => {
  const getEnv = (name: string) => {
    const values: Record<string, string> = {
      TAIYO_ACTION_SECRET: "action-secret",
      TAIYO_CONTEXT_TOKEN_SECRET: "context-secret-with-enough-length",
    };
    const value = values[name];
    if (!value) throw new Error(`Missing ${name}`);
    return value;
  };
  const contextToken = await createContextToken({
    sub: "member-1",
    role: "member",
    scope: "member_context",
  }, getEnv);
  const response = await handleTaiyoMemberContextRequest(
    new Request("https://example.com/taiyo-member-context", {
      method: "POST",
      headers: {
        "x-taiyo-action-secret": "action-secret",
        "x-taiyo-context-token": contextToken,
      },
      body: "{}",
    }),
    {
      getEnv,
      loadContext: async () => ({
        member_profile: { goal: "fat_loss", experience_level: "beginner" },
        recent_sessions: [],
        recent_task_logs: [],
        today_tasks: [],
        nutrition: {},
      }),
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.result.member_id, "member-1");
});

Deno.test("taiyo-member-context rejects bad context token", async () => {
  const response = await handleTaiyoMemberContextRequest(
    new Request("https://example.com/taiyo-member-context", {
      method: "POST",
      headers: {
        "x-taiyo-action-secret": "action-secret",
        "x-taiyo-context-token": "bad-token",
      },
      body: "{}",
    }),
    {
      getEnv: (name: string) => {
        const values: Record<string, string> = {
          TAIYO_ACTION_SECRET: "action-secret",
          TAIYO_CONTEXT_TOKEN_SECRET: "context-secret-with-enough-length",
        };
        const value = values[name];
        if (!value) throw new Error(`Missing ${name}`);
        return value;
      },
    },
  );

  assertEquals(response.status, 401);
  const body = await response.json();
  assertEquals(body.status, "error");
});

Deno.test("taiyo-member-context rejects expired action token", async () => {
  const getEnv = (name: string) => {
    const values: Record<string, string> = {
      TAIYO_ACTION_SECRET: "action-secret",
      TAIYO_CONTEXT_TOKEN_SECRET: "context-secret-with-enough-length",
    };
    const value = values[name];
    if (!value) throw new Error(`Missing ${name}`);
    return value;
  };
  const contextToken = await createContextToken({
    sub: "member-1",
    role: "member",
    scope: "member_context",
    ttlSeconds: -1,
  }, getEnv);
  const response = await handleTaiyoMemberContextRequest(
    new Request("https://example.com/taiyo-member-context", {
      method: "POST",
      headers: {
        "x-taiyo-action-secret": "action-secret",
        "x-taiyo-context-token": contextToken,
      },
      body: "{}",
    }),
    { getEnv },
  );

  assertEquals(response.status, 401);
  const body = await response.json();
  assertEquals(body.status, "error");
});
