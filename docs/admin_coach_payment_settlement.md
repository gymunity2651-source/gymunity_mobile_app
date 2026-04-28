# GymUnity Admin Coach Payment Settlement

This admin dashboard is for Paymob coach-payment settlement in test mode. It records manual coach payouts after GymUnity transfers money outside the app. It does not trigger bank, wallet, Instapay, or Paymob Split Amount transfers.

## Admin Setup

Admins are not part of public role selection. Grant access manually:

```sql
insert into public.app_admins (user_id, role)
values ('ADMIN_USER_UUID', 'finance_admin')
on conflict (user_id) do update
set role = excluded.role, is_active = true;
```

Supported roles:

- `super_admin`: full access, including raw Paymob payload visibility.
- `finance_admin`: payment and payout operations, including mark paid.
- `support_admin`: read-only payment, payout, coach, subscription, audit, and settings visibility.

## Admin Route

Open directly:

```text
/admin-dashboard
```

The route is guarded by `app_admins` and admin RPC permissions. It is not exposed in normal member, coach, or seller navigation.

## Manual QA

1. Insert an admin row in `app_admins`.
2. Log in as that admin.
3. Open `/admin-dashboard`.
4. Confirm the `TEST MODE` badge appears.
5. Complete a Paymob test payment as a client.
6. Return to the dashboard and confirm the paid payment appears.
7. Confirm the coach payout appears as pending/ready.
8. Open payout details.
9. Mark payout paid with a fake external reference after confirming the coach was paid outside GymUnity.
10. Confirm `coach_payouts.status = paid`, `paid_at` is set, and `admin_id` is the admin.
11. Confirm a coach notification exists.
12. Confirm `admin_audit_events` contains the payout action.
13. Log in as a non-admin and verify `/admin-dashboard` shows Access Denied.

## Limitations

- Test mode only.
- Manual payout recording only.
- Transfer proof upload is deferred; `transfer_proof_path` remains nullable.
- No automatic payout, Paymob split, live-mode reconciliation, refund automation, or dispute automation.

Rotate/revoke any Supabase access token shared outside the secrets store before deployment.
