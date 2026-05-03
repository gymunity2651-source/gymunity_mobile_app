import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  buildSellerContext,
  normalizeSellerCopilotResponse,
} from "./engine.ts";
import { handleTaiyoSellerCopilotRequest } from "./index.ts";

Deno.test("taiyo-seller-copilot rejects missing auth with 401", async () => {
  const response = await handleTaiyoSellerCopilotRequest(
    new Request("https://example.com/taiyo-seller-copilot", {
      method: "POST",
      body: "{}",
    }),
  );

  assertEquals(response.status, 401);
  const body = await response.json();
  assertEquals(body.status, "error");
  assertEquals(body.error, "Missing auth token");
});

Deno.test("taiyo-seller-copilot rejects non-seller profiles with 403", async () => {
  const response = await handleTaiyoSellerCopilotRequest(
    request({ request_type: "seller_dashboard_brief" }),
    {
      authenticate: async () => ({ id: "user-1" }),
      getProfileRole: async () => "coach",
    },
  );

  assertEquals(response.status, 403);
  const body = await response.json();
  assertMatch(String(body.error), /seller accounts only/i);
});

Deno.test("buildSellerContext handles sparse seller data safely", () => {
  const context = buildSellerContext("seller-1", {
    profile: {},
    dashboard_summary: {},
    products: [],
    orders: [],
  });

  assertEquals(context.seller_id, "seller-1");
  assertEquals(context.role, "seller");
  assertEquals(context.active_products.length, 0);
  assertEquals(context.data_quality.confidence, "low");
  assertEquals(context.data_quality.missing_fields.includes("products"), true);
});

Deno.test("taiyo-seller-copilot handles malformed Azure output safely", async () => {
  const response = await handleTaiyoSellerCopilotRequest(
    request({ request_type: "seller_dashboard_brief" }),
    {
      authenticate: async () => ({ id: "seller-1" }),
      getProfileRole: async () => "seller",
      loadContext: async () => baseRawContext(),
      callOrchestrator: async () => "```json\nnot-json\n```",
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.status, "error");
  assertMatch(String(body.result.summary), /could not return/i);
});

Deno.test("taiyo-seller-copilot normalizes seller dashboard brief", async () => {
  const response = await handleTaiyoSellerCopilotRequest(
    request({ request_type: "seller_dashboard_brief" }),
    {
      authenticate: async () => ({ id: "seller-1" }),
      getProfileRole: async () => "seller",
      loadContext: async () => baseRawContext(),
      callOrchestrator: async () =>
        '```json\n{"status":"success","result":{"summary":"Orders are steady.","priority_actions":["Restock bands"],"product_opportunities":["Bundle accessories"],"order_notes":["Two orders pending"],"risk_level":"medium","recommended_next_step":"Review low stock products."},"data_quality":{"confidence":"high"}}\n```',
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.request_type, "seller_dashboard_brief");
  assertEquals(body.status, "success");
  assertEquals(body.result.risk_level, "medium");
  assertEquals(body.result.priority_actions[0], "Restock bands");
  assertEquals(body.metadata.source, "supabase_edge_function");
});

Deno.test("normalizeSellerCopilotResponse strips fenced JSON", () => {
  const context = buildSellerContext("seller-1", baseRawContext());
  const normalized = normalizeSellerCopilotResponse(
    '```json\n{"status":"success","result":{"summary":"Inventory looks healthy.","risk_level":"low"}}\n```',
    context,
    "seller_dashboard_brief",
    { generatedAt: "2026-05-02T00:00:00.000Z" },
  );

  assertEquals(normalized.status, "success");
  assertEquals(normalized.result.summary, "Inventory looks healthy.");
  assertEquals(normalized.metadata.generated_at, "2026-05-02T00:00:00.000Z");
});

function request(body: Record<string, unknown>) {
  return new Request("https://example.com/taiyo-seller-copilot", {
    method: "POST",
    headers: {
      "Authorization": "Bearer test-token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

function baseRawContext() {
  return {
    profile: {
      store_name: "Seller Studio",
      primary_category: "equipment",
      shipping_scope: "domestic",
    },
    dashboard_summary: {
      total_products: 4,
      active_products: 3,
      low_stock_products: 1,
      pending_orders: 2,
      in_progress_orders: 1,
      delivered_orders: 5,
      gross_revenue: 2400,
    },
    products: [
      {
        id: "product-1",
        title: "Resistance Band",
        category: "equipment",
        price: 20,
        stock_qty: 2,
        low_stock_threshold: 5,
        is_active: true,
      },
    ],
    orders: [
      {
        id: "order-1",
        status: "pending",
        total_amount: 40,
        item_count: 2,
      },
    ],
    order_items: [
      {
        order_id: "order-1",
        product_id: "product-1",
        product_title_snapshot: "Resistance Band",
        quantity: 2,
        line_total: 40,
      },
    ],
    order_status_history: [],
  };
}
