import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  handleTaiyoStoreRecommendationsRequest,
  normalizeStoreRecommendations,
} from "./index.ts";

Deno.test("taiyo-store-recommendations rejects missing auth", async () => {
  const response = await handleTaiyoStoreRecommendationsRequest(
    new Request("https://example.com/taiyo-store-recommendations", {
      method: "POST",
      body: "{}",
    }),
  );

  assertEquals(response.status, 401);
});

Deno.test("taiyo-store-recommendations rejects wrong role", async () => {
  const response = await handleTaiyoStoreRecommendationsRequest(
    new Request("https://example.com/taiyo-store-recommendations", {
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

Deno.test("taiyo-store-recommendations filters unavailable products", () => {
  const normalized = normalizeStoreRecommendations(
    {
      result: {
        recommendation_type: "equipment_gap",
        products: [
          { product_id: "out", why_recommended: "No stock", priority: "high" },
          { product_id: "in", why_recommended: "Useful", priority: "high" },
        ],
      },
    },
    {
      products: [
        { id: "out", title: "Out", stock_qty: 0, is_active: true },
        {
          id: "in",
          title: "Band",
          stock_qty: 4,
          is_active: true,
          price: 25,
          currency: "EGP",
        },
      ],
    },
    3,
  );

  assertEquals(normalized.result.products.length, 1);
  assertEquals(normalized.result.products[0].product_id, "in");
});

Deno.test("taiyo-store-recommendations handles malformed Azure output safely", async () => {
  const response = await handleTaiyoStoreRecommendationsRequest(
    new Request("https://example.com/taiyo-store-recommendations", {
      method: "POST",
      headers: { Authorization: "Bearer token" },
      body: JSON.stringify({ limit: 2 }),
    }),
    {
      authenticate: async () => ({ id: "member-1" }),
      getProfileRole: async () => "member",
      loadContext: async () => ({
        products: [{
          id: "product-1",
          title: "Band",
          stock_qty: 3,
          is_active: true,
        }],
      }),
      callOrchestrator: async () => "not-json",
      saveRecommendations: async () => 1,
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.status, "success");
  assertEquals(body.result.products[0].product_id, "product-1");
});
