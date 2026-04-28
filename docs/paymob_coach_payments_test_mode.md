# Paymob Coach Payments Test Mode

This flow is test mode only. Do not use live Paymob credentials or real money until live-mode payout, refund, dispute, and finance approval controls are implemented.

## Supabase Edge Function Secrets

Set these secrets in Supabase for the target test project:

```bash
supabase secrets set PAYMOB_MODE=test
supabase secrets set PAYMOB_API_BASE_URL=https://accept.paymob.com
supabase secrets set PAYMOB_MERCHANT_ID=1155713
supabase secrets set PAYMOB_SECRET_KEY_TEST=...
supabase secrets set PAYMOB_PUBLIC_KEY_TEST=...
supabase secrets set PAYMOB_HMAC_SECRET_TEST=...
supabase secrets set PAYMOB_TEST_INTEGRATION_IDS=5629685
supabase secrets set PAYMOB_CURRENCY=EGP
supabase secrets set GYMUNITY_PLATFORM_FEE_BPS=1500
supabase secrets set GYMUNITY_PAYOUT_HOLD_DAYS=0
supabase secrets set APP_PUBLIC_PAYMENT_REDIRECT_URL=https://pooelnnveljiikpdrvqw.functions.supabase.co/paymob-payment-response
supabase secrets set PAYMOB_NOTIFICATION_URL=https://pooelnnveljiikpdrvqw.functions.supabase.co/paymob-transaction-callback
```

Never put `PAYMOB_SECRET_KEY_TEST`, `PAYMOB_HMAC_SECRET_TEST`, the service role key, or admin tokens in Flutter.

## Deploy

```bash
supabase db push
supabase functions deploy create-coach-paymob-checkout
supabase functions deploy paymob-transaction-callback
supabase functions deploy paymob-payment-response
supabase functions deploy sync-paymob-payment-status
supabase functions deploy admin-payment-settings
```

Add admins manually from Supabase SQL or the dashboard:

```sql
insert into public.app_admins (user_id, role)
values ('ADMIN_USER_UUID', 'finance_admin')
on conflict (user_id) do update
set role = excluded.role, is_active = true;
```

## Paymob Dashboard

In the Paymob test dashboard:

- Confirm merchant ID `1155713`, integration ID `5629685`, Online Card, EGP, Test status.
- Set transaction processed callback to `PAYMOB_NOTIFICATION_URL`.
- Set transaction response callback to `APP_PUBLIC_PAYMENT_REDIRECT_URL`.
- Deploy functions before updating the Paymob Dashboard callbacks.

## Flutter Test Mode

Enable Paymob checkout explicitly:

```json
{
  "ENABLE_COACH_SUBSCRIPTIONS": "true",
  "ENABLE_COACH_PAYMOB_PAYMENTS": "true",
  "ENABLE_COACH_MANUAL_PAYMENT_PROOFS": "false"
}
```

Manual proof remains legacy-only and disabled for the Paymob MVP run. Paymob orders show a `TEST PAYMENT` badge and never expose coach approve/reject actions.

For the full setup checklist, see `docs/paymob_test_mode_setup.md`.

## Paymob Test Credentials

Use only in docs/manual QA, never in app code.

- Mastercard: `5123456789012346`, Expiry `01/39`, CVV `123`, Name `Test Account`
- Mastercard: `5123450000000008`, Expiry `01/39`, CVV `123`, Name `Test Account`
- Visa: `4111111111111111`, Expiry `01/39`, CVV `123`, Name `Test Account`
- Wallet: `01010101010`, MPIN `123456`, OTP `123456`

## Verification Checklist

1. Create a published active coach package.
2. Log in as a member.
3. Open the package and tap `Start secure payment`.
4. Confirm the Paymob hosted checkout opens and shows a test transaction.
5. Pay using a Paymob test card or wallet.
6. Confirm Paymob dashboard shows the test transaction.
7. Confirm `coach_payment_orders.status = paid`.
8. Confirm `subscriptions.status = active` and `checkout_status = paid`.
9. Confirm `coach_member_threads` has one row for the subscription.
10. Confirm the member and coach can send messages.
11. Confirm an admin notification was created.
12. Confirm `coach_payout_items` has one item for the payment order.
13. Confirm the coach billing screen shows payout status and no approve/fail actions for Paymob orders.

## Limitations

- No automatic coach payout.
- No Paymob split amount.
- No live mode.
- No automated refund or dispute handling.
- Admin settlement is backend-only for this MVP.

## Before Live Mode

Rotate any credentials shared outside the secrets store, add live Paymob credentials separately, configure production callback URLs, document refund/dispute policy, add finance approval checks, run reconciliation tests, and complete a live-mode rollout checklist.
