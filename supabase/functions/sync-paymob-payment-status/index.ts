import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  authenticateUser,
  checkoutCorsHeaders,
  createServiceClient,
  getPaymobConfig,
  HttpError,
  jsonResponse,
  stringOrNull,
  type JsonMap,
  type PaymobConfig,
} from "../_shared/paymob.ts";

type SyncDeps = {
  supabase?: SupabaseClient;
  paymobConfig?: PaymobConfig;
};

export async function handleSyncPaymobPaymentStatus(
  req: Request,
  deps: SyncDeps = {},
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: checkoutCorsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const supabase = deps.supabase ?? createServiceClient();
    const config = deps.paymobConfig ?? getPaymobConfig();
    const { user } = await authenticateUser(supabase, req);
    await assertAdmin(supabase, user.id);

    const body = (await req.json().catch(() => ({}))) as JsonMap;
    const paymentOrderId = stringOrNull(body["payment_order_id"]);
    if (!paymentOrderId) {
      throw new HttpError("payment_order_id is required.", 400);
    }

    await supabase.from("admin_audit_events").insert({
      actor_user_id: user.id,
      action: "sync_paymob_payment_status_requested",
      target_type: "coach_payment_order",
      target_id: paymentOrderId,
      metadata: {
        mode: config.mode,
        status: "stubbed",
      },
    });

    return jsonResponse({
      ok: true,
      mode: config.mode,
      payment_order_id: paymentOrderId,
      status: "not_implemented",
      message:
        "Paymob transaction inquiry is intentionally stubbed for MVP test mode. Use verified callbacks as source of truth.",
    });
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    return jsonResponse({
      error: error instanceof Error ? error.message : "Unknown sync error",
    }, status);
  }
}

async function assertAdmin(supabase: SupabaseClient, userId: string) {
  const { data, error } = await supabase
    .from("app_admins")
    .select("user_id")
    .eq("user_id", userId)
    .eq("is_active", true)
    .maybeSingle();
  if (error) {
    throw new Error(error.message);
  }
  if (!data) {
    throw new HttpError("Admin access is required.", 403);
  }
}

if (import.meta.main) {
  Deno.serve((req) => handleSyncPaymobPaymentStatus(req));
}
