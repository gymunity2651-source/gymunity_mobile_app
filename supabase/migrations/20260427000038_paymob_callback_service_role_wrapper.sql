-- Paymob callback processing is invoked through Supabase Edge Functions with
-- the service role key. Some PostgREST deployments expose the DB role as
-- service_role while leaving request.jwt.claim.role empty, so the original
-- processor's internal claim check can reject legitimate Edge Function calls.
-- This wrapper is granted only to service_role and sets the expected local
-- claim before delegating to the hardened, idempotent processor.

create or replace function public.process_coach_paymob_callback_as_service(
  input_raw_payload jsonb,
  input_hmac_verified boolean,
  input_paymob_transaction_id text default null,
  input_paymob_order_id text default null,
  input_paymob_intention_id text default null,
  input_special_reference text default null,
  input_success boolean default null,
  input_pending boolean default null,
  input_is_voided boolean default null,
  input_is_refunded boolean default null,
  input_amount_cents integer default null,
  input_currency text default null,
  input_source_data_type text default null,
  input_failure_reason text default null,
  input_payout_hold_days integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('request.jwt.claim.role', 'service_role', true);

  return public.process_coach_paymob_callback(
    input_raw_payload,
    input_hmac_verified,
    input_paymob_transaction_id,
    input_paymob_order_id,
    input_paymob_intention_id,
    input_special_reference,
    input_success,
    input_pending,
    input_is_voided,
    input_is_refunded,
    input_amount_cents,
    input_currency,
    input_source_data_type,
    input_failure_reason,
    input_payout_hold_days
  );
end;
$$;

revoke all on function public.process_coach_paymob_callback_as_service(
  jsonb,
  boolean,
  text,
  text,
  text,
  text,
  boolean,
  boolean,
  boolean,
  boolean,
  integer,
  text,
  text,
  text,
  integer
) from public, anon, authenticated;

grant execute on function public.process_coach_paymob_callback_as_service(
  jsonb,
  boolean,
  text,
  text,
  text,
  text,
  boolean,
  boolean,
  boolean,
  boolean,
  integer,
  text,
  text,
  text,
  integer
) to service_role;
