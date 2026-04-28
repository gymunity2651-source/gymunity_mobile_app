import {
  checkoutCorsHeaders,
  getEnv,
  htmlResponse,
  jsonResponse,
} from "../_shared/paymob.ts";

export function handlePaymobPaymentResponse(req: Request): Response {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: checkoutCorsHeaders });
  }

  const url = new URL(req.url);
  const appRedirect = getEnv("APP_PUBLIC_PAYMENT_REDIRECT_URL");
  const status =
    url.searchParams.get("success") === "true" ||
      url.searchParams.get("success") === "1"
      ? "success"
      : (url.searchParams.get("pending") === "true" ||
          url.searchParams.get("pending") === "1")
      ? "pending"
      : "refresh";
  const paymentOrderId = url.searchParams.get("payment_order_id") ??
    url.searchParams.get("merchant_order_id") ??
    url.searchParams.get("order");

  if (appRedirect) {
    const redirectUrl = new URL(appRedirect);
    if (!isPaymentResponseEndpoint(redirectUrl)) {
      redirectUrl.searchParams.set("payment_status", status);
      if (paymentOrderId) {
        redirectUrl.searchParams.set("payment_order_id", paymentOrderId);
      }
      return new Response(null, {
        status: 302,
        headers: {
          ...checkoutCorsHeaders,
          "Location": redirectUrl.toString(),
        },
      });
    }
  }

  if (req.headers.get("accept")?.includes("application/json")) {
    return jsonResponse({
      ok: true,
      message: "Payment response received. Refresh payment status in the app.",
      payment_status: status,
    });
  }

  return htmlResponse(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>GymUnity Payment</title>
    <style>
      body {
        margin: 0;
        font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        background: #fffaf7;
        color: #241b18;
      }
      main {
        min-height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 24px;
      }
      section {
        max-width: 420px;
        width: 100%;
        text-align: center;
      }
      .badge {
        display: inline-flex;
        border: 1px solid #f2b25c;
        color: #af3e12;
        background: #fff2df;
        border-radius: 999px;
        padding: 8px 12px;
        font-weight: 800;
        font-size: 13px;
        margin-bottom: 18px;
      }
      h1 {
        font-size: 26px;
        margin: 0 0 10px;
      }
      p {
        color: #6d5f58;
        line-height: 1.5;
        margin: 0 0 22px;
      }
      a.button {
        display: block;
        width: 100%;
        box-sizing: border-box;
        border-radius: 14px;
        background: #af3e12;
        color: #fff;
        padding: 15px 18px;
        font-weight: 800;
        text-decoration: none;
      }
      .hint {
        display: block;
        margin-top: 14px;
        font-size: 13px;
        color: #87766f;
      }
    </style>
  </head>
  <body>
    <main>
      <section>
        <div class="badge">PAYMOB TEST MODE</div>
        <h1>Return to GymUnity</h1>
        <p>Your payment page is done. Open GymUnity and refresh My Coaching. The subscription activates only after the verified Paymob webhook reaches GymUnity.</p>
        <a class="button" id="open-app" href="${escapeHtml(deepLinkUrl(status, paymentOrderId))}">Open GymUnity</a>
        <span class="hint">If the app does not open automatically, tap the button above.</span>
      </section>
    </main>
    <script>
      window.setTimeout(function () {
        window.location.href = document.getElementById("open-app").href;
      }, 600);
    </script>
  </body>
</html>`);
}

function isPaymentResponseEndpoint(url: URL): boolean {
  return url.pathname.replace(/\/+$/, "").endsWith("/paymob-payment-response");
}

function deepLinkUrl(status: string, paymentOrderId: string | null): string {
  const url = new URL("gymunity://payment-callback");
  url.searchParams.set("payment_status", status);
  if (paymentOrderId) {
    url.searchParams.set("payment_order_id", paymentOrderId);
  }
  return url.toString();
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll('"', "&quot;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

if (import.meta.main) {
  Deno.serve((req) => handlePaymobPaymentResponse(req));
}
