import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  handleTaiyoNutritionContextRequest,
  normalizeNutritionGuidance,
} from "./index.ts";

Deno.test("taiyo-nutrition-context rejects missing auth", async () => {
  const response = await handleTaiyoNutritionContextRequest(
    new Request("https://example.com/taiyo-nutrition-context", {
      method: "POST",
      body: "{}",
    }),
  );

  assertEquals(response.status, 401);
});

Deno.test("taiyo-nutrition-context rejects wrong role", async () => {
  const response = await handleTaiyoNutritionContextRequest(
    new Request("https://example.com/taiyo-nutrition-context", {
      method: "POST",
      headers: { Authorization: "Bearer token" },
      body: "{}",
    }),
    {
      authenticate: async () => ({ id: "seller-1" }),
      getProfileRole: async () => "seller",
    },
  );

  assertEquals(response.status, 403);
  const body = await response.json();
  assertMatch(String(body.error), /member accounts only/i);
});

Deno.test("taiyo-nutrition-context handles malformed Azure output safely", async () => {
  const response = await handleTaiyoNutritionContextRequest(
    new Request("https://example.com/taiyo-nutrition-context", {
      method: "POST",
      headers: { Authorization: "Bearer token" },
      body: JSON.stringify({ request_type: "nutrition_guidance" }),
    }),
    {
      authenticate: async () => ({ id: "member-1" }),
      getProfileRole: async () => "member",
      loadContext: async () => ({ summary: { hydration_target_ml: 2500 } }),
      callOrchestrator: async () => "not-json",
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.result.confidence, "medium");
  assertMatch(String(body.result.warning), /General fitness/i);
});

Deno.test("normalizeNutritionGuidance strips fenced JSON", () => {
  const guidance = normalizeNutritionGuidance(
    '```json\n{"nutrition_status":"on_track","hydration_focus":"Keep sipping.","confidence":"high"}\n```',
    {},
  );

  assertEquals(guidance.nutrition_status, "on_track");
  assertEquals(guidance.hydration_focus, "Keep sipping.");
  assertEquals(guidance.confidence, "high");
});
