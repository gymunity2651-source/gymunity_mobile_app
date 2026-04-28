import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  authenticateUser,
  checkoutCorsHeaders,
  createServiceClient,
  getEnv,
  getPaymobConfig,
  HttpError,
  jsonResponse,
} from "../_shared/paymob.ts";

type SettingsDeps = {
  supabase?: SupabaseClient;
};

export async function handleAdminPaymentSettings(
  req: Request,
  deps: SettingsDeps = {},
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: checkoutCorsHeaders });
  }
  if (req.method !== "GET" && req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const supabase = deps.supabase ?? createServiceClient();
    const { user } = await authenticateUser(supabase, req);
    await assertAdminCanReadSettings(supabase, user.id);

    const config = getPaymobConfig();
    return jsonResponse({
      mode: config.mode,
      currency: config.currency,
      platform_fee_bps: config.platformFeeBps,
      payout_hold_days: config.payoutHoldDays,
      api_base_url: config.apiBaseUrl,
      merchant_id_configured: config.merchantId.trim().length > 0,
      notification_url_configured: config.notificationUrl.trim().length > 0,
      redirection_url_configured: config.redirectUrl.trim().length > 0,
      test_integration_ids_configured: config.integrationIds.length > 0,
      secret_key_configured: getEnv("PAYMOB_SECRET_KEY_TEST").length > 0,
      hmac_key_configured: getEnv("PAYMOB_HMAC_SECRET_TEST").length > 0,
    });
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    return jsonResponse({
      error: error instanceof Error ? error.message : "Unknown settings error",
    }, status);
  }
}

async function assertAdminCanReadSettings(
  supabase: SupabaseClient,
  userId: string,
) {
  const { data, error } = await supabase
    .from("app_admins")
    .select("user_id,role,permissions")
    .eq("user_id", userId)
    .eq("is_active", true)
    .maybeSingle();
  if (error) {
    throw new Error(error.message);
  }
  if (!data) {
    throw new HttpError("Admin access is required.", 403);
  }

  const row = data as { role?: string; permissions?: Record<string, unknown> };
  if (!hasPermission(row.role ?? "", row.permissions ?? {}, "settings.read")) {
    throw new HttpError("settings.read permission is required.", 403);
  }
}

function hasPermission(
  role: string,
  permissions: Record<string, unknown>,
  permission: string,
): boolean {
  if (role === "super_admin") {
    return true;
  }
  if (permissions[permission] === true) {
    return true;
  }
  return role === "finance_admin" || role === "support_admin" || role === "admin";
}

if (import.meta.main) {
  Deno.serve((req) => handleAdminPaymentSettings(req));
}
