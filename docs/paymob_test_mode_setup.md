# Paymob Test Mode Setup

This setup is for GymUnity coach subscriptions in Paymob test mode only.
Do not use live credentials, real money, Paymob split payments, or automatic coach payouts.

## Required Paymob Values

- Mode: `test`
- Merchant ID: `1155713`
- Test integration ID: `5629685`
- Integration type: Online Card
- Integration status: Test
- Currency: `EGP`
- Public key: set as `PAYMOB_PUBLIC_KEY_TEST`
- Secret key: set as `PAYMOB_SECRET_KEY_TEST`
- HMAC secret: set as `PAYMOB_HMAC_SECRET_TEST`
- Platform fee: `GYMUNITY_PLATFORM_FEE_BPS=1500`
- Payout hold days: `GYMUNITY_PAYOUT_HOLD_DAYS=0`

Never commit Paymob secret keys, HMAC secrets, Supabase service role keys, or Supabase access tokens.
Rotate any credential that was pasted into chat or stored outside the secret store before production use.

## Supabase Secrets

Run this from a linked Supabase project. Replace placeholders with values from the Paymob Dashboard or secure secret store.

```bash
supabase secrets set \
  PAYMOB_MODE="test" \
  PAYMOB_API_BASE_URL="https://accept.paymob.com" \
  PAYMOB_MERCHANT_ID="1155713" \
  PAYMOB_TEST_INTEGRATION_IDS="5629685" \
  PAYMOB_CURRENCY="EGP" \
  PAYMOB_PUBLIC_KEY_TEST="<PAYMOB_PUBLIC_KEY_TEST>" \
  PAYMOB_SECRET_KEY_TEST="<PAYMOB_SECRET_KEY_TEST>" \
  PAYMOB_HMAC_SECRET_TEST="<PAYMOB_HMAC_SECRET_TEST>" \
  PAYMOB_NOTIFICATION_URL="https://pooelnnveljiikpdrvqw.functions.supabase.co/paymob-transaction-callback" \
  APP_PUBLIC_PAYMENT_REDIRECT_URL="https://pooelnnveljiikpdrvqw.functions.supabase.co/paymob-payment-response" \
  GYMUNITY_PLATFORM_FEE_BPS="1500" \
  GYMUNITY_PAYOUT_HOLD_DAYS="0"
```

If they are not already configured for Edge Functions, also set:

```bash
supabase secrets set \
  SUPABASE_URL="https://pooelnnveljiikpdrvqw.supabase.co" \
  SUPABASE_SERVICE_ROLE_KEY="<SUPABASE_SERVICE_ROLE_KEY>"
```

## Deploy Order

Deploy functions before changing Paymob Dashboard callbacks.

```bash
supabase db push
supabase functions deploy create-coach-paymob-checkout
supabase functions deploy paymob-transaction-callback
supabase functions deploy paymob-payment-response
supabase functions deploy sync-paymob-payment-status
supabase functions deploy admin-payment-settings
```

## Paymob Dashboard Callbacks

After deployment, configure the Paymob test Dashboard:

- Transaction processed callback: `https://pooelnnveljiikpdrvqw.functions.supabase.co/paymob-transaction-callback`
- Transaction response callback: `https://pooelnnveljiikpdrvqw.functions.supabase.co/paymob-payment-response`

Confirm:

- Mode is Test.
- Merchant ID is `1155713`.
- Integration ID is `5629685`.
- Integration type is Online Card.
- Currency is EGP.
- Status is Test.

## Flutter Test Run

Use Paymob as the active coach checkout path and disable legacy manual proofs:

```bash
flutter run \
  --dart-define=ENABLE_COACH_SUBSCRIPTIONS=true \
  --dart-define=ENABLE_COACH_PAYMOB_PAYMENTS=true \
  --dart-define=ENABLE_COACH_MANUAL_PAYMENT_PROOFS=false
```

The dev and staging dart-define examples are configured the same way. Do not put Paymob secrets in Dart defines or `assets/config/local_env.json`.

## End-to-End Test Checklist

1. Rotate/revoke the pasted Supabase access token before deployment.
2. Deploy DB migrations and Edge Functions.
3. Set Supabase Edge Function secrets.
4. Confirm function URLs are reachable.
5. Configure Paymob Dashboard callback URLs.
6. Run Flutter with Paymob enabled and manual proofs disabled.
7. Create or use a published active coach package.
8. Log in as a member and tap `Start secure payment` / `Pay with Paymob`.
9. Complete Paymob hosted test checkout.
10. Confirm Paymob Dashboard shows a test transaction.
11. Confirm `coach_payment_orders.status = paid`.
12. Confirm `subscriptions.status = active` and `subscriptions.checkout_status = paid`.
13. Confirm one `coach_member_threads` row exists for the subscription.
14. Confirm one `coach_payout_items` row exists for the payment order.
15. Confirm client and coach can message.
16. Confirm coach sees payout status and client does not.
17. Confirm no Paymob order shows `Submit payment proof`, `Approve payment`, or `Needs follow-up`.

## Common Errors

- Missing `PAYMOB_SECRET_KEY_TEST`: set Supabase Edge Function secrets again and redeploy.
- Missing `PAYMOB_HMAC_SECRET_TEST`: callback will reject HMAC verification and will not activate subscriptions.
- Invalid integration ID: `PAYMOB_TEST_INTEGRATION_IDS` must be comma-separated numeric test integration IDs.
- Invalid HMAC: confirm Dashboard callback payload is from the same Paymob test account and HMAC secret.
- Amount mismatch: confirm Flutter does not send price and backend uses the coach package amount.
- Callback URL not reachable: deploy functions first, then update Paymob Dashboard URLs.
- User closed checkout: app should refresh and remain payment pending until Paymob callback arrives.
- Webhook delayed: subscription must remain pending until verified callback processes.
- Dashboard still has old callback URL: update both processed and response callback URLs.
- Feature flag disabled: run Flutter with Paymob enabled and manual proofs disabled.
- Manual payment proof still showing: check `ENABLE_COACH_MANUAL_PAYMENT_PROOFS=false` and confirm the subscription/payment order is Paymob-backed.

## Limitations

- Test mode only.
- Online Card only for MVP.
- GymUnity receives funds first.
- No automatic coach payout.
- No Paymob split payments.
- No live payments.
- Manual admin settlement only.
- Refund and dispute automation are not implemented.
