# Coach Relationship Backend Parity Audit

Date: 2026-04-26

Target project: `gymunity` (`pooelnnveljiikpdrvqw`)

This audit is based on the local migration set and the read-only linked migration check. The linked project reports remote migrations through `20260425000032`, matching local history before the new hardening migration.

## Exists Already

Core relationship tables are already defined in migrations:

- `coach_checkout_requests`
- `coach_payment_receipts`
- `coach_payment_audit_events`
- `coach_member_threads`
- `coach_messages`
- `weekly_checkins`
- `progress_photos`
- `coach_client_records`
- `coach_client_notes`
- `coach_automation_events`
- `coach_program_templates`
- `coach_exercise_library`
- `member_habit_assignments`
- `coach_resources`
- `coach_resource_assignments`
- `coach_onboarding_templates`
- `coach_onboarding_applications`
- `coach_session_types`
- `coach_bookings`
- `coach_member_visibility_settings`
- `coach_member_visibility_audit`
- `member_product_recommendations`

Storage buckets are defined and are hardened to private by the new migration:

- `coach-payment-receipts`
- `coach-resources`

Core RPCs already existed before hardening:

- `create_coach_checkout`
- `submit_coach_payment_receipt`
- `verify_coach_payment`
- `fail_coach_payment`
- `ensure_coach_member_thread`
- `submit_weekly_checkin`
- `submit_coach_checkin_feedback`
- Privacy, workspace, resource, booking, program, and onboarding RPCs used by the Flutter app.

## Missing

Before this patch, the repo did not define a dedicated RPC for ordinary coach/client message sending. The app inserted directly into `coach_messages`.

Added:

- `send_coaching_message(target_thread_id uuid, input_content text)`

## Mismatched

The following behavior did not fully match the locked product rule that paused relationships are read-only:

- `submit_weekly_checkin` allowed paused subscriptions.
- Flutter member check-ins listed paused subscriptions as eligible.
- Message sending relied on direct table inserts rather than a state-aware RPC.

The new hardening migration changes core write behavior to active-only:

- ordinary messages require `subscriptions.status = active`
- weekly check-ins require `subscriptions.status = active`
- coach check-in feedback requires `subscriptions.status = active`

Flutter compatibility changes route message sends through `send_coaching_message` and hide paused subscriptions from check-in submission.

## Risky

Direct `coach_messages` inserts were risky because clients could attempt to write sender metadata directly. Existing RLS checked role ownership, but the safer model is to infer sender role server-side.

Hardened:

- dropped direct authenticated insert policy on `coach_messages`
- added `send_coaching_message` security-definer RPC
- sender role is inferred from `public.current_role()`
- empty messages and non-active subscriptions are rejected

Payment review also needed stricter latest-receipt behavior:

- `verify_coach_payment` now approves only the latest submitted/receipt-uploaded/under-verification receipt.
- `fail_coach_payment` now fails only the latest submitted/receipt-uploaded/under-verification receipt.
- `fail_coach_payment` requires a non-empty reason.
- corrected proof submission after failure is allowed by `submit_coach_payment_receipt`.

## Verification Artifacts

Added:

- `supabase/sql/coach_relationship_core_audit.sql`
- `supabase/sql/coach_relationship_core_smoke_test.sql`
- `supabase/migrations/20260426000033_coach_relationship_core_hardening.sql`

Recommended local verification:

```powershell
supabase db reset
supabase db push --local
psql "<local-db-url>" -f supabase/sql/coach_relationship_core_audit.sql
psql "<local-db-url>" -f supabase/sql/coach_relationship_core_smoke_test.sql
flutter test
```

Recommended read-only live verification before any live push:

```powershell
$env:SUPABASE_ACCESS_TOKEN='<token from secure shell env>'
supabase migration list --linked
psql "<linked-db-url>" -f supabase/sql/coach_relationship_core_audit.sql
```

Do not run `supabase db push --linked` until this migration and audit output are reviewed.
