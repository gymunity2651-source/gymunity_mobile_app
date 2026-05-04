import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { callFoundryOrchestrator } from "../_shared/foundry.ts";
import {
  authenticateTaiyoRequest,
  createSupabaseClients,
  type SupabasePair,
} from "../_shared/taiyo_action_auth.ts";
import { dateOnly, obj, str } from "../taiyo-daily-brief/engine.ts";

type HandlerDeps = {
  getEnv?: (name: string) => string;
  authenticate?: (token: string) => Promise<{ id: string }>;
  getProfileRole?: (userId: string) => Promise<string | null>;
  loadContext?: (
    input: { memberId: string; targetDate: string; limit: number },
  ) => Promise<Record<string, unknown>>;
  callOrchestrator?: (input: Record<string, unknown>) => Promise<unknown>;
  saveRecommendations?: (
    memberId: string,
    normalized: NormalizedStoreRecommendations,
  ) => Promise<number>;
};

type NormalizedStoreRecommendations = {
  request_type: "store_recommendations";
  status: "success" | "needs_more_context" | "error";
  result: {
    recommendation_type: string;
    reason: string;
    products: Array<Record<string, unknown>>;
    disclaimer: string;
  };
  data_quality: {
    missing_fields: string[];
    confidence: "low" | "medium" | "high";
  };
  metadata: {
    source: "supabase_edge_function";
    generated_at: string;
    persisted_count?: number;
  };
};

if (import.meta.main) {
  Deno.serve((req) => handleTaiyoStoreRecommendationsRequest(req));
}

export async function handleTaiyoStoreRecommendationsRequest(
  req: Request,
  deps: HandlerDeps = {},
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const getEnv = deps.getEnv || env;
  let clients: SupabasePair | null = null;
  try {
    const body = obj(await req.json().catch(() => ({})));
    const requestType = str(body.request_type) || "store_recommendations";
    if (requestType !== "store_recommendations") {
      return jsonResponse({ error: "Unsupported request_type." }, 400);
    }
    const limit = boundedLimit(body.limit);
    const targetDate = dateOnly(str(body.date) || str(body.target_date));
    const authResult = await authenticateTaiyoRequest(
      req,
      "store_recommendations",
      {
        getEnv,
        createClients: (token) => {
          clients ??= createSupabaseClients(token, getEnv);
          return clients;
        },
        authenticate: deps.authenticate,
        getProfileRole: deps.getProfileRole,
      },
    );
    if (authResult.auth.role !== "member") {
      return jsonResponse({
        error:
          "TAIYO store recommendations are available for member accounts only.",
      }, 403);
    }

    const loadContext = deps.loadContext ||
      ((input) => loadStoreContext(defaultSupabase(authResult, getEnv), input));
    const context = await loadContext({
      memberId: authResult.auth.userId,
      targetDate,
      limit,
    });
    const availableProducts = productRows(context).filter(isAvailableProduct);
    if (!availableProducts.length) {
      return jsonResponse(noProductsResponse(context));
    }

    const callOrchestrator = deps.callOrchestrator || callTaiyoOrchestrator;
    const aiOutput = await callOrchestrator({
      request_type: "store_recommendations",
      user_role: "member",
      store_context: {
        ...context,
        products: availableProducts.slice(0, 30),
      },
      response_format: "json",
      instruction:
        "Return only valid JSON with recommendation_type, reason, products[], and disclaimer. Recommend products only as fitness support, never medical treatment.",
    });
    const normalized = normalizeStoreRecommendations(aiOutput, context, limit);
    const saveRecommendations = deps.saveRecommendations ||
      ((memberId, recommendation) =>
        saveMemberProductRecommendations(
          defaultSupabase(authResult, getEnv),
          memberId,
          recommendation,
        ));
    const persistedCount = normalized.status === "success"
      ? await saveRecommendations(authResult.auth.userId, normalized)
      : 0;

    return jsonResponse({
      ...normalized,
      metadata: {
        ...normalized.metadata,
        persisted_count: persistedCount,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = errorStatus(message);
    return jsonResponse({
      request_type: "store_recommendations",
      status: "error",
      error: publicError(message, status),
      metadata: {
        source: "supabase_edge_function",
        generated_at: new Date().toISOString(),
      },
    }, status);
  }
}

export async function loadStoreContext(
  supabase: SupabaseClient,
  input: { memberId: string; targetDate: string; limit: number },
) {
  const [
    memberProfile,
    nutritionTarget,
    products,
    favorites,
    cart,
    orders,
    history,
  ] = await Promise.all([
    maybeSingle(
      supabase.from("member_profiles").select("*").eq("user_id", input.memberId)
        .maybeSingle(),
    ),
    maybeSingle(
      supabase.from("nutrition_targets").select("*")
        .eq("member_id", input.memberId)
        .eq("status", "active")
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle(),
    ),
    listRows(
      supabase.from("products")
        .select(
          "id,seller_id,title,description,category,price,currency,stock_qty,image_paths,low_stock_threshold,is_active,deleted_at,updated_at",
        )
        .eq("is_active", true)
        .is("deleted_at", null)
        .order("updated_at", { ascending: false })
        .limit(60),
    ),
    listRows(
      supabase.from("product_favorites").select("product_id")
        .eq("member_id", input.memberId)
        .limit(60),
    ),
    loadCartContext(supabase, input.memberId),
    listRows(
      supabase.from("orders")
        .select("id,status,total_amount,currency,created_at")
        .eq("member_id", input.memberId)
        .order("created_at", { ascending: false })
        .limit(10),
    ),
    listRows(
      supabase.from("member_product_recommendations")
        .select("product_id,recommendation_context,status,created_at")
        .eq("member_id", input.memberId)
        .order("created_at", { ascending: false })
        .limit(20),
    ),
  ]);

  return {
    member_id: input.memberId,
    target_date: input.targetDate,
    limit: input.limit,
    member_profile: memberProfile,
    nutrition_target: nutritionTarget,
    products,
    favorites,
    cart,
    orders,
    recommendation_history: history,
  };
}

export async function callTaiyoOrchestrator(input: Record<string, unknown>) {
  return await callFoundryOrchestrator(input, {
    additionalInstructions:
      "You are the TAIYO Orchestrator. Return only one valid JSON object for store_recommendations. Recommend available products only as fitness support, not medical treatment.",
  });
}

export function normalizeStoreRecommendations(
  aiOutput: unknown,
  context: Record<string, unknown>,
  limit: number,
): NormalizedStoreRecommendations {
  const parsed = typeof aiOutput === "string"
    ? parseJsonFromText(aiOutput)
    : aiOutput;
  const raw = obj(parsed);
  const result = obj(raw.result).length ? obj(raw.result) : raw;
  const available = productRows(context).filter(isAvailableProduct);
  const byId = new Map(available.map((product) => [str(product.id), product]));
  const requested = Array.isArray(result.products)
    ? result.products.map(obj)
    : [];
  const selected: Record<string, unknown>[] = [];
  for (const item of requested) {
    const productId = str(item.product_id) || str(item.id);
    const product = productId ? byId.get(productId) : null;
    if (!product || selected.some((row) => row.product_id === productId)) {
      continue;
    }
    selected.push(productRecommendation(product, item));
    if (selected.length >= limit) break;
  }
  if (!selected.length) {
    for (const product of available.slice(0, limit)) {
      selected.push(productRecommendation(product, {}));
    }
  }

  return {
    request_type: "store_recommendations",
    status: selected.length ? "success" : "needs_more_context",
    result: {
      recommendation_type: nonEmpty(result.recommendation_type) ||
        "fitness_support",
      reason: nonEmpty(result.reason) ||
        "TAIYO matched available store products to your current training and nutrition context.",
      products: selected,
      disclaimer:
        "Recommendations are based on fitness context, not medical advice.",
    },
    data_quality: dataQuality(context),
    metadata: {
      source: "supabase_edge_function",
      generated_at: new Date().toISOString(),
    },
  };
}

async function saveMemberProductRecommendations(
  supabase: SupabaseClient,
  memberId: string,
  normalized: NormalizedStoreRecommendations,
) {
  const products = normalized.result.products;
  if (!products.length) return 0;
  const rows = products.map((product) => ({
    member_id: memberId,
    product_id: str(product.product_id),
    recommendation_context: recommendationContext(
      normalized.result.recommendation_type,
    ),
    why_recommended: str(product.why_recommended),
    priority: priority(str(product.priority)),
    recommendation_payload_json: {
      reason: normalized.result.reason,
      product,
      disclaimer: normalized.result.disclaimer,
    },
    status: "suggested",
  })).filter((row) => row.product_id);
  if (!rows.length) return 0;
  const { error } = await supabase.from("member_product_recommendations")
    .insert(rows);
  if (error) throw new Error(error.message);
  return rows.length;
}

async function loadCartContext(supabase: SupabaseClient, memberId: string) {
  const cart = await maybeSingle(
    supabase.from("store_carts").select("id,status,updated_at")
      .eq("member_id", memberId)
      .eq("status", "active")
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle(),
  );
  const cartId = str(cart.id);
  const items = cartId
    ? await listRows(
      supabase.from("store_cart_items").select("product_id,quantity")
        .eq("cart_id", cartId),
    )
    : [];
  return { ...cart, items };
}

function noProductsResponse(
  context: Record<string, unknown>,
): NormalizedStoreRecommendations {
  return {
    request_type: "store_recommendations",
    status: "needs_more_context",
    result: {
      recommendation_type: "store_unavailable",
      reason: "No available products are ready for recommendation right now.",
      products: [],
      disclaimer:
        "Recommendations are based on fitness context, not medical advice.",
    },
    data_quality: dataQuality(context),
    metadata: {
      source: "supabase_edge_function",
      generated_at: new Date().toISOString(),
    },
  };
}

function productRecommendation(
  product: Record<string, unknown>,
  aiItem: Record<string, unknown>,
) {
  return {
    product_id: str(product.id) || "",
    name: str(product.title) || "Product",
    category: str(product.category) || "",
    price: Number(product.price) || 0,
    currency: str(product.currency) || "USD",
    why_recommended: nonEmpty(aiItem.why_recommended) ||
      "Useful support for the current training or nutrition focus.",
    priority: priority(str(aiItem.priority)),
  };
}

function productRows(context: Record<string, unknown>) {
  return Array.isArray(context.products) ? context.products.map(obj) : [];
}

function isAvailableProduct(product: Record<string, unknown>) {
  return product.is_active !== false &&
    !product.deleted_at &&
    (Number(product.stock_qty) || 0) > 0;
}

function dataQuality(context: Record<string, unknown>) {
  const missing = [
    Object.keys(obj(context.member_profile)).length ? null : "member_profile",
    Object.keys(obj(context.nutrition_target)).length
      ? null
      : "nutrition_target",
    productRows(context).length ? null : "products",
  ].filter(Boolean) as string[];
  return {
    missing_fields: missing,
    confidence: missing.length >= 2
      ? "low"
      : missing.length
      ? "medium"
      : "high",
  } as const;
}

function recommendationContext(value: string) {
  const normalized = value.toLowerCase();
  if (normalized.includes("nutrition")) return "nutrition_goal";
  if (normalized.includes("equipment")) return "equipment_gap";
  if (normalized.includes("coach")) return "coach_suggestion";
  return "ai_plan_accessory";
}

function priority(value: string | null) {
  return value === "high" || value === "medium" || value === "low"
    ? value
    : "medium";
}

function boundedLimit(value: unknown) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return 3;
  return Math.max(1, Math.min(8, Math.round(parsed)));
}

async function maybeSingle(
  query: PromiseLike<{ data: unknown; error: unknown }>,
) {
  const { data, error } = await query;
  if (error) throw new Error(errorMessage(error));
  return obj(data);
}

async function listRows(query: PromiseLike<{ data: unknown; error: unknown }>) {
  const { data, error } = await query;
  if (error) throw new Error(errorMessage(error));
  return Array.isArray(data) ? data.map(obj) : [];
}

function parseJsonFromText(text: string) {
  const trimmed = text.trim();
  try {
    return JSON.parse(trimmed);
  } catch {
    const match = trimmed.match(/\{[\s\S]*\}/);
    if (!match) return {};
    try {
      return JSON.parse(match[0]);
    } catch {
      return {};
    }
  }
}

function nonEmpty(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function env(name: string) {
  const value = Deno.env.get(name)?.trim() || "";
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
}

function defaultSupabase(
  authResult: Awaited<ReturnType<typeof authenticateTaiyoRequest>>,
  getEnv: (name: string) => string,
) {
  if (authResult.clients) return authResult.clients.userSupabase;
  return createClient(
    getEnv("SUPABASE_URL"),
    getEnv("SUPABASE_SERVICE_ROLE_KEY"),
    {
      auth: { persistSession: false },
    },
  );
}

function errorStatus(message: string) {
  const lower = message.toLowerCase();
  if (message === "Missing auth token" || message === "Unauthorized") {
    return 401;
  }
  if (lower.includes("context token")) return 401;
  if (lower.includes("member accounts only")) return 403;
  return 500;
}

function publicError(message: string, status: number) {
  return status === 401 || status === 403
    ? message
    : "TAIYO store recommendations failed.";
}

function errorMessage(error: unknown) {
  return error instanceof Error
    ? error.message
    : obj(error).message?.toString() || String(error);
}
