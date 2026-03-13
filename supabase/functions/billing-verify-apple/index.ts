import {
  authenticateUser,
  createServiceClient,
  type LifecycleState,
  type PurchasePayload,
  upsertBillingState,
} from "../_shared/billing.ts";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const productionUrl = "https://buy.itunes.apple.com/verifyReceipt";
const sandboxUrl = "https://sandbox.itunes.apple.com/verifyReceipt";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createServiceClient();
    const { user } = await authenticateUser(supabase, req);
    const payload = (await req.json()) as PurchasePayload;

    const receiptData =
      payload.verification_data?.server_verification_data?.trim() ?? "";
    if (!receiptData) {
      return jsonResponse(
        { error: "Apple receipt data is required for verification." },
        400,
      );
    }

    const sharedSecret = (Deno.env.get("APPLE_SHARED_SECRET") ?? "").trim();
    if (!sharedSecret) {
      return jsonResponse(
        { error: "Missing required env var: APPLE_SHARED_SECRET" },
        500,
      );
    }

    const response = await verifyReceipt(receiptData, sharedSecret);
    if (response.status !== 0) {
      return jsonResponse(
        {
          error: "Apple receipt validation failed.",
          status: response.status,
        },
        400,
      );
    }

    const productId = payload.product_id?.trim() ?? "";
    const transaction = selectLatestTransaction(response, productId);
    if (!transaction) {
      return jsonResponse(
        { error: "Apple receipt does not contain the requested product." },
        400,
      );
    }

    const pendingRenewal = selectPendingRenewal(
      response,
      transaction.original_transaction_id,
    );
    const planCode = resolveApplePlanCode(transaction.product_id);
    const lifecycleState = resolveLifecycleState(transaction, pendingRenewal);

    const summary = await upsertBillingState({
      supabase,
      userId: user.id,
      offeringCode: payload.offering_code ?? "ai_premium",
      planCode,
      platform: "ios",
      productId: transaction.product_id,
      purchaseState: payload.purchase_status ?? "purchased",
      lifecycleState,
      transactionId:
        transaction.transaction_id ??
        transaction.original_transaction_id ??
        productId,
      originalTransactionId: transaction.original_transaction_id ?? null,
      purchaseToken: "",
      transactionDate: transaction.purchase_date_ms
        ? new Date(Number(transaction.purchase_date_ms)).toISOString()
        : payload.transaction_date ?? null,
      accessExpiresAt: transaction.expires_date_ms
        ? new Date(Number(transaction.expires_date_ms)).toISOString()
        : null,
      renewsAt: transaction.expires_date_ms
        ? new Date(Number(transaction.expires_date_ms)).toISOString()
        : null,
      cancellationRequestedAt:
        pendingRenewal?.auto_renew_status === "0"
          ? new Date().toISOString()
          : null,
      gracePeriodUntil: pendingRenewal?.grace_period_expires_date_ms
        ? new Date(
            Number(pendingRenewal.grace_period_expires_date_ms),
          ).toISOString()
        : null,
      environment: response.environment ?? null,
      verificationSource: "apple_verify_receipt",
      rawPayload: {
        request: payload,
        apple_response: response,
      },
    });

    return jsonResponse({ success: true, summary });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unknown error" },
      500,
    );
  }
});

async function verifyReceipt(receiptData: string, sharedSecret: string) {
  const body = JSON.stringify({
    "receipt-data": receiptData,
    password: sharedSecret,
    "exclude-old-transactions": false,
  });

  const productionResponse = await fetch(productionUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body,
  });
  const productionJson = await productionResponse.json();
  if (productionJson.status === 21007) {
    const sandboxResponse = await fetch(sandboxUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
    });
    return await sandboxResponse.json();
  }
  return productionJson;
}

function selectLatestTransaction(
  response: Record<string, unknown>,
  productId: string,
) {
  const rows = Array.isArray(response.latest_receipt_info)
    ? response.latest_receipt_info
    : Array.isArray(response.receipt?.in_app)
    ? response.receipt.in_app
    : [];

  const filtered = rows
    .filter((row) => typeof row === "object" && row !== null)
    .map((row) => row as Record<string, string>)
    .filter((row) => !productId || row.product_id === productId)
    .sort((left, right) => {
      const leftMs = Number(left.expires_date_ms ?? left.purchase_date_ms ?? 0);
      const rightMs = Number(
        right.expires_date_ms ?? right.purchase_date_ms ?? 0,
      );
      return rightMs - leftMs;
    });

  return filtered[0] ?? null;
}

function selectPendingRenewal(
  response: Record<string, unknown>,
  originalTransactionId: string | undefined,
) {
  const rows = Array.isArray(response.pending_renewal_info)
    ? response.pending_renewal_info
    : [];

  const matching = rows
    .filter((row) => typeof row === "object" && row !== null)
    .map((row) => row as Record<string, string>)
    .find(
      (row) =>
        !originalTransactionId ||
        row.original_transaction_id === originalTransactionId,
    );

  return matching ?? null;
}

function resolveApplePlanCode(productId: string | undefined) {
  const monthlyId =
    (Deno.env.get("APPLE_AI_PREMIUM_MONTHLY_PRODUCT_ID") ?? "").trim();
  const annualId =
    (Deno.env.get("APPLE_AI_PREMIUM_ANNUAL_PRODUCT_ID") ?? "").trim();

  if (productId && productId === annualId) {
    return "annual";
  }
  if (productId && productId === monthlyId) {
    return "monthly";
  }
  return null;
}

function resolveLifecycleState(
  transaction: Record<string, string>,
  pendingRenewal: Record<string, string> | null,
): LifecycleState {
  const now = Date.now();
  const expiresAt = Number(transaction.expires_date_ms ?? 0);
  const graceAt = Number(pendingRenewal?.grace_period_expires_date_ms ?? 0);

  if (transaction.cancellation_date_ms || transaction.cancellation_date) {
    return "revoked_or_refunded";
  }

  if (graceAt > now) {
    return "grace_period";
  }

  if (expiresAt > 0 && expiresAt <= now) {
    return "expired";
  }

  if (pendingRenewal?.auto_renew_status === "0") {
    return "cancellation_requested_active_until_expiry";
  }

  if (pendingRenewal?.auto_renew_status === "1") {
    return "renewing";
  }

  return "active";
}
