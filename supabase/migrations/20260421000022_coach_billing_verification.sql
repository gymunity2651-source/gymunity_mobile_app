-- Coach manual billing verification, receipts, and audit trail
-- Date: 2026-04-21

insert into storage.buckets (id, name, public)
values ('coach-payment-receipts', 'coach-payment-receipts', false)
on conflict (id) do nothing;

alter table public.subscriptions
  drop constraint if exists subscriptions_checkout_status_check;

alter table public.subscriptions
  add constraint subscriptions_checkout_status_check check (
    checkout_status in (
      'not_started',
      'checkout_pending',
      'submitted',
      'receipt_uploaded',
      'under_verification',
      'paid',
      'failed',
      'refunded'
    )
  );

create table if not exists public.coach_payment_receipts (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  amount numeric(10,2) not null check (amount >= 0),
  currency text not null default 'EGP',
  payment_reference text,
  receipt_storage_path text,
  status text not null default 'submitted' check (
    status in ('awaiting_payment', 'submitted', 'receipt_uploaded', 'under_verification', 'activated', 'failed')
  ),
  reviewed_by uuid references public.profiles(user_id) on delete set null,
  reviewed_at timestamptz,
  failure_reason text,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.coach_payment_audit_events (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  receipt_id uuid references public.coach_payment_receipts(id) on delete set null,
  actor_user_id uuid references public.profiles(user_id) on delete set null,
  old_state text,
  new_state text not null,
  note text,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_payment_receipts_coach_status
  on public.coach_payment_receipts(coach_id, status, created_at desc);
create index if not exists idx_payment_receipts_member_subscription
  on public.coach_payment_receipts(member_id, subscription_id, created_at desc);
create index if not exists idx_payment_audit_subscription
  on public.coach_payment_audit_events(subscription_id, created_at desc);

alter table public.coach_payment_receipts enable row level security;
alter table public.coach_payment_audit_events enable row level security;

drop policy if exists payment_receipts_read_participants on public.coach_payment_receipts;
create policy payment_receipts_read_participants
on public.coach_payment_receipts for select
to authenticated
using (coach_id = auth.uid() or member_id = auth.uid());

drop policy if exists payment_receipts_insert_member on public.coach_payment_receipts;
create policy payment_receipts_insert_member
on public.coach_payment_receipts for insert
to authenticated
with check (member_id = auth.uid());

drop policy if exists payment_receipts_update_coach on public.coach_payment_receipts;
create policy payment_receipts_update_coach
on public.coach_payment_receipts for update
to authenticated
using (coach_id = auth.uid())
with check (coach_id = auth.uid());

drop policy if exists payment_audit_read_participants on public.coach_payment_audit_events;
create policy payment_audit_read_participants
on public.coach_payment_audit_events for select
to authenticated
using (
  exists (
    select 1
    from public.subscriptions s
    where s.id = coach_payment_audit_events.subscription_id
      and (s.coach_id = auth.uid() or s.member_id = auth.uid())
  )
);

drop policy if exists payment_receipts_storage_select_participants on storage.objects;
create policy payment_receipts_storage_select_participants
on storage.objects for select
to authenticated
using (
  bucket_id = 'coach-payment-receipts'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or exists (
      select 1
      from public.coach_payment_receipts r
      where r.receipt_storage_path = name
        and (r.member_id = auth.uid() or r.coach_id = auth.uid())
    )
  )
);

drop policy if exists payment_receipts_storage_insert_own on storage.objects;
create policy payment_receipts_storage_insert_own
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'coach-payment-receipts'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists payment_receipts_storage_update_own on storage.objects;
create policy payment_receipts_storage_update_own
on storage.objects for update
to authenticated
using (
  bucket_id = 'coach-payment-receipts'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'coach-payment-receipts'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop trigger if exists touch_coach_payment_receipts_updated_at on public.coach_payment_receipts;
create trigger touch_coach_payment_receipts_updated_at
before update on public.coach_payment_receipts
for each row execute function public.touch_updated_at();

create or replace function public.coach_billing_state(subscription_status text, checkout_status text, latest_receipt_status text)
returns text
language sql
immutable
as $$
  select case
    when subscription_status = 'active' or latest_receipt_status = 'activated' or checkout_status = 'paid' then 'activated'
    when latest_receipt_status = 'failed' or checkout_status = 'failed' then 'failed_needs_follow_up'
    when latest_receipt_status = 'under_verification' then 'under_verification'
    when latest_receipt_status = 'receipt_uploaded' then 'receipt_uploaded'
    when latest_receipt_status = 'submitted' then 'payment_submitted'
    when subscription_status in ('checkout_pending', 'pending_payment', 'pending_activation') or checkout_status = 'checkout_pending' then 'awaiting_payment'
    else 'not_started'
  end;
$$;

create or replace function public.submit_coach_payment_receipt(
  target_subscription_id uuid,
  input_payment_reference text default null,
  input_receipt_storage_path text default null,
  input_amount numeric default null
)
returns public.coach_payment_receipts
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  subscription_record public.subscriptions%rowtype;
  receipt_record public.coach_payment_receipts%rowtype;
  resolved_status text;
begin
  if requester is null or public.current_role() <> 'member' then
    raise exception 'Only members can submit payment receipts.';
  end if;

  select *
  into subscription_record
  from public.subscriptions
  where id = target_subscription_id
    and member_id = requester;

  if subscription_record.id is null then
    raise exception 'Subscription not found.';
  end if;

  if subscription_record.status not in ('checkout_pending', 'pending_payment', 'pending_activation') then
    raise exception 'This subscription is not awaiting manual payment.';
  end if;

  resolved_status := case
    when coalesce(input_receipt_storage_path, '') <> '' then 'receipt_uploaded'
    else 'submitted'
  end;

  insert into public.coach_payment_receipts (
    subscription_id, member_id, coach_id, amount, currency, payment_reference,
    receipt_storage_path, status
  )
  values (
    subscription_record.id,
    requester,
    subscription_record.coach_id,
    coalesce(input_amount, subscription_record.amount),
    'EGP',
    input_payment_reference,
    input_receipt_storage_path,
    resolved_status
  )
  returning * into receipt_record;

  update public.subscriptions
  set checkout_status = resolved_status,
      payment_reference = coalesce(input_payment_reference, payment_reference),
      updated_at = timezone('utc', now())
  where id = subscription_record.id;

  update public.coach_checkout_requests
  set payment_reference = coalesce(input_payment_reference, payment_reference),
      updated_at = timezone('utc', now())
  where subscription_id = subscription_record.id;

  insert into public.coach_payment_audit_events (
    subscription_id, receipt_id, actor_user_id, old_state, new_state, note
  )
  values (
    subscription_record.id,
    receipt_record.id,
    requester,
    public.coach_billing_state(subscription_record.status, subscription_record.checkout_status, null),
    public.coach_billing_state(subscription_record.status, subscription_record.checkout_status, receipt_record.status),
    'Member submitted manual payment proof.'
  );

  insert into public.notifications (user_id, type, title, body, data)
  values (
    subscription_record.coach_id,
    'coaching',
    'Payment proof submitted',
    'A member submitted payment proof for review.',
    jsonb_build_object('subscription_id', subscription_record.id, 'receipt_id', receipt_record.id)
  );

  return receipt_record;
end;
$$;

create or replace function public.list_coach_payment_queue()
returns table (
  receipt_id uuid,
  subscription_id uuid,
  member_id uuid,
  member_name text,
  package_title text,
  amount numeric,
  currency text,
  payment_reference text,
  receipt_storage_path text,
  receipt_status text,
  billing_state text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  failure_reason text
)
language sql
stable
security definer
set search_path = public
as $$
  with latest_receipts as (
    select distinct on (r.subscription_id)
      r.*
    from public.coach_payment_receipts r
    where r.coach_id = auth.uid()
    order by r.subscription_id, r.created_at desc
  )
  select
    r.id as receipt_id,
    s.id as subscription_id,
    s.member_id,
    coalesce(nullif(p.full_name, ''), 'Member') as member_name,
    coalesce(pkg.title, s.plan_name, 'Coaching') as package_title,
    coalesce(r.amount, s.amount) as amount,
    coalesce(r.currency, 'EGP') as currency,
    coalesce(r.payment_reference, s.payment_reference) as payment_reference,
    r.receipt_storage_path,
    coalesce(r.status, 'awaiting_payment') as receipt_status,
    public.coach_billing_state(s.status, s.checkout_status, r.status) as billing_state,
    coalesce(r.created_at, s.created_at) as submitted_at,
    r.reviewed_at,
    r.failure_reason
  from public.subscriptions s
  join public.profiles p on p.user_id = s.member_id
  left join public.coach_packages pkg on pkg.id = s.package_id
  left join latest_receipts r on r.subscription_id = s.id
  where s.coach_id = auth.uid()
    and (
      s.status in ('checkout_pending', 'pending_payment', 'pending_activation')
      or r.status in ('submitted', 'receipt_uploaded', 'under_verification', 'failed')
    )
  order by
    case public.coach_billing_state(s.status, s.checkout_status, r.status)
      when 'under_verification' then 0
      when 'receipt_uploaded' then 1
      when 'payment_submitted' then 2
      when 'awaiting_payment' then 3
      else 4
    end,
    coalesce(r.created_at, s.created_at) desc;
$$;

create or replace function public.verify_coach_payment(
  target_receipt_id uuid,
  input_note text default null
)
returns public.coach_payment_receipts
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  receipt_record public.coach_payment_receipts%rowtype;
  subscription_record public.subscriptions%rowtype;
  package_record public.coach_packages%rowtype;
  computed_next_renewal timestamptz;
  computed_end timestamptz;
  thread_id uuid;
begin
  if requester is null or public.current_role() <> 'coach' then
    raise exception 'Only coaches can verify payments.';
  end if;

  select *
  into receipt_record
  from public.coach_payment_receipts
  where id = target_receipt_id
    and coach_id = requester
  for update;

  if receipt_record.id is null then
    raise exception 'Receipt not found.';
  end if;

  select *
  into subscription_record
  from public.subscriptions
  where id = receipt_record.subscription_id
    and coach_id = requester
  for update;

  if subscription_record.id is null then
    raise exception 'Subscription not found.';
  end if;

  select *
  into package_record
  from public.coach_packages
  where id = subscription_record.package_id;

  computed_next_renewal := case subscription_record.billing_cycle
    when 'weekly' then timezone('utc', now()) + interval '7 days'
    when 'quarterly' then timezone('utc', now()) + interval '3 months'
    when 'one_time' then null
    else timezone('utc', now()) + interval '1 month'
  end;

  computed_end := case subscription_record.billing_cycle
    when 'one_time' then timezone('utc', now()) + make_interval(days => greatest(coalesce(package_record.trial_days, 0), 1))
    else computed_next_renewal
  end;

  update public.subscriptions
  set status = 'active',
      checkout_status = 'paid',
      payment_method = coalesce(payment_method, 'manual'),
      starts_at = coalesce(starts_at, timezone('utc', now())),
      ends_at = coalesce(ends_at, computed_end),
      activated_at = coalesce(activated_at, timezone('utc', now())),
      next_renewal_at = computed_next_renewal,
      payment_reference = coalesce(receipt_record.payment_reference, payment_reference),
      updated_at = timezone('utc', now())
  where id = subscription_record.id
  returning * into subscription_record;

  update public.coach_checkout_requests
  set status = 'confirmed',
      payment_reference = coalesce(receipt_record.payment_reference, payment_reference),
      updated_at = timezone('utc', now())
  where subscription_id = subscription_record.id;

  update public.coach_payment_receipts
  set status = 'activated',
      reviewed_by = requester,
      reviewed_at = timezone('utc', now()),
      failure_reason = null
  where id = receipt_record.id
  returning * into receipt_record;

  thread_id := public.ensure_coach_member_thread(subscription_record.id);

  insert into public.coach_payment_audit_events (
    subscription_id, receipt_id, actor_user_id, old_state, new_state, note
  )
  values (
    subscription_record.id,
    receipt_record.id,
    requester,
    'under_verification',
    'activated',
    coalesce(input_note, 'Coach verified manual payment.')
  );

  insert into public.notifications (user_id, type, title, body, data)
  values (
    subscription_record.member_id,
    'coaching',
    'Payment verified',
    'Your coach verified payment and activated your coaching workspace.',
    jsonb_build_object('subscription_id', subscription_record.id, 'thread_id', thread_id)
  );

  return receipt_record;
end;
$$;

create or replace function public.fail_coach_payment(
  target_receipt_id uuid,
  input_reason text
)
returns public.coach_payment_receipts
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  receipt_record public.coach_payment_receipts%rowtype;
begin
  if requester is null or public.current_role() <> 'coach' then
    raise exception 'Only coaches can review payments.';
  end if;

  update public.coach_payment_receipts
  set status = 'failed',
      reviewed_by = requester,
      reviewed_at = timezone('utc', now()),
      failure_reason = nullif(trim(input_reason), '')
  where id = target_receipt_id
    and coach_id = requester
  returning * into receipt_record;

  if receipt_record.id is null then
    raise exception 'Receipt not found.';
  end if;

  update public.subscriptions
  set checkout_status = 'failed',
      updated_at = timezone('utc', now())
  where id = receipt_record.subscription_id
    and status in ('checkout_pending', 'pending_payment', 'pending_activation');

  update public.coach_checkout_requests
  set status = 'failed',
      updated_at = timezone('utc', now())
  where subscription_id = receipt_record.subscription_id;

  insert into public.coach_payment_audit_events (
    subscription_id, receipt_id, actor_user_id, old_state, new_state, note
  )
  values (
    receipt_record.subscription_id,
    receipt_record.id,
    requester,
    'under_verification',
    'failed_needs_follow_up',
    input_reason
  );

  insert into public.notifications (user_id, type, title, body, data)
  values (
    receipt_record.member_id,
    'coaching',
    'Payment needs follow-up',
    coalesce(nullif(trim(input_reason), ''), 'Your coach could not verify the payment proof.'),
    jsonb_build_object('subscription_id', receipt_record.subscription_id, 'receipt_id', receipt_record.id)
  );

  return receipt_record;
end;
$$;

create or replace function public.list_coach_payment_audit(target_subscription_id uuid)
returns table (
  id uuid,
  receipt_id uuid,
  actor_user_id uuid,
  actor_name text,
  old_state text,
  new_state text,
  note text,
  metadata_json jsonb,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select a.id, a.receipt_id, a.actor_user_id, coalesce(nullif(p.full_name, ''), 'System'),
         a.old_state, a.new_state, a.note, a.metadata_json, a.created_at
  from public.coach_payment_audit_events a
  left join public.profiles p on p.user_id = a.actor_user_id
  join public.subscriptions s on s.id = a.subscription_id
  where a.subscription_id = target_subscription_id
    and (s.coach_id = auth.uid() or s.member_id = auth.uid())
  order by a.created_at desc;
$$;

grant execute on function public.coach_billing_state(text, text, text) to authenticated;
grant execute on function public.submit_coach_payment_receipt(uuid, text, text, numeric) to authenticated;
grant execute on function public.list_coach_payment_queue() to authenticated;
grant execute on function public.verify_coach_payment(uuid, text) to authenticated;
grant execute on function public.fail_coach_payment(uuid, text) to authenticated;
grant execute on function public.list_coach_payment_audit(uuid) to authenticated;
