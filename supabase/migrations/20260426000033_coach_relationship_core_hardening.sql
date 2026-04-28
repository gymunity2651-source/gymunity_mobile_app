-- Coach relationship core hardening and live/backend parity safeguards.
-- Date: 2026-04-26
--
-- This migration is intentionally idempotent and non-destructive. It assumes
-- the broader coach relationship schema from earlier migrations may already
-- exist, then tightens the core checkout, payment, messaging, and check-in
-- behavior used by the Flutter app.

insert into storage.buckets (id, name, public)
values
  ('coach-payment-receipts', 'coach-payment-receipts', false),
  ('coach-resources', 'coach-resources', false)
on conflict (id) do update set public = false;

alter table public.subscriptions
  add column if not exists package_id uuid references public.coach_packages(id) on delete set null,
  add column if not exists checkout_status text not null default 'not_started',
  add column if not exists intake_snapshot_json jsonb not null default '{}'::jsonb,
  add column if not exists next_renewal_at timestamptz,
  add column if not exists cancel_at_period_end boolean not null default false,
  add column if not exists paused_at timestamptz,
  add column if not exists switched_from_subscription_id uuid references public.subscriptions(id) on delete set null,
  add column if not exists payment_reference text,
  add column if not exists payment_method text not null default 'manual',
  add column if not exists member_note text,
  add column if not exists activated_at timestamptz,
  add column if not exists cancelled_at timestamptz;

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
  ) not valid;

alter table public.subscriptions
  drop constraint if exists subscriptions_status_check;
alter table public.subscriptions
  add constraint subscriptions_status_check check (
    status in (
      'checkout_pending',
      'pending_payment',
      'pending_activation',
      'active',
      'paused',
      'completed',
      'cancelled'
    )
  ) not valid;

drop index if exists public.idx_subscriptions_member_package_open;
create unique index if not exists idx_subscriptions_member_package_open
  on public.subscriptions(member_id, package_id)
  where package_id is not null
    and status in ('checkout_pending', 'pending_payment', 'pending_activation', 'active', 'paused');
create index if not exists idx_subscriptions_coach_status
  on public.subscriptions(coach_id, status, created_at desc);
create index if not exists idx_subscriptions_member_status
  on public.subscriptions(member_id, status, created_at desc);

create table if not exists public.coach_checkout_requests (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  package_id uuid not null references public.coach_packages(id) on delete cascade,
  payment_rail text not null check (payment_rail in ('card', 'instapay', 'wallet', 'manual_fallback')),
  requested_amount numeric(10,2) not null check (requested_amount >= 0),
  currency text not null default 'EGP',
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'failed', 'expired')),
  payment_reference text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.coach_member_threads (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null unique references public.subscriptions(id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  last_message_preview text not null default '',
  last_message_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.coach_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.coach_member_threads(id) on delete cascade,
  sender_user_id uuid not null references public.profiles(user_id) on delete cascade,
  sender_role text not null check (sender_role in ('member', 'coach', 'system')),
  message_type text not null default 'text' check (message_type in ('text', 'checkin_prompt', 'checkin_feedback', 'system')),
  content text not null,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.weekly_checkins (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  thread_id uuid references public.coach_member_threads(id) on delete set null,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  week_start date not null,
  weight_kg numeric(6,2) check (weight_kg is null or weight_kg > 0),
  waist_cm numeric(6,2) check (waist_cm is null or waist_cm > 0),
  adherence_score integer not null default 0 check (adherence_score between 0 and 100),
  energy_score integer check (energy_score is null or energy_score between 1 and 10),
  sleep_score integer check (sleep_score is null or sleep_score between 1 and 10),
  wins text,
  blockers text,
  questions text,
  coach_reply text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (subscription_id, week_start)
);

create table if not exists public.progress_photos (
  id uuid primary key default gen_random_uuid(),
  checkin_id uuid not null references public.weekly_checkins(id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  storage_path text not null,
  angle text not null default 'front' check (angle in ('front', 'side', 'back', 'other')),
  created_at timestamptz not null default timezone('utc', now())
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
  status text not null default 'submitted' check (status in ('awaiting_payment', 'submitted', 'receipt_uploaded', 'under_verification', 'activated', 'failed')),
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

create index if not exists idx_checkout_requests_subscription
  on public.coach_checkout_requests(subscription_id, created_at desc);
create index if not exists idx_checkout_requests_coach_status
  on public.coach_checkout_requests(coach_id, status, created_at desc);
create index if not exists idx_threads_member_updated
  on public.coach_member_threads(member_id, updated_at desc);
create index if not exists idx_threads_coach_updated
  on public.coach_member_threads(coach_id, updated_at desc);
create index if not exists idx_messages_thread_created
  on public.coach_messages(thread_id, created_at);
create index if not exists idx_weekly_checkins_member_created
  on public.weekly_checkins(member_id, created_at desc);
create index if not exists idx_weekly_checkins_coach_created
  on public.weekly_checkins(coach_id, created_at desc);
create index if not exists idx_weekly_checkins_subscription_week
  on public.weekly_checkins(subscription_id, week_start desc);
create index if not exists idx_progress_photos_checkin
  on public.progress_photos(checkin_id, created_at desc);
create index if not exists idx_payment_receipts_coach_status
  on public.coach_payment_receipts(coach_id, status, created_at desc);
create index if not exists idx_payment_receipts_member_subscription
  on public.coach_payment_receipts(member_id, subscription_id, created_at desc);
create index if not exists idx_payment_audit_subscription
  on public.coach_payment_audit_events(subscription_id, created_at desc);

alter table public.coach_checkout_requests enable row level security;
alter table public.coach_member_threads enable row level security;
alter table public.coach_messages enable row level security;
alter table public.weekly_checkins enable row level security;
alter table public.progress_photos enable row level security;
alter table public.coach_payment_receipts enable row level security;
alter table public.coach_payment_audit_events enable row level security;

drop policy if exists checkout_requests_read_participants on public.coach_checkout_requests;
create policy checkout_requests_read_participants
on public.coach_checkout_requests for select
to authenticated
using (member_id = auth.uid() or coach_id = auth.uid());

drop policy if exists checkout_requests_no_direct_insert on public.coach_checkout_requests;
drop policy if exists checkout_requests_no_direct_update on public.coach_checkout_requests;
drop policy if exists coach_member_threads_read_participants on public.coach_member_threads;
create policy coach_member_threads_read_participants
on public.coach_member_threads for select
to authenticated
using (member_id = auth.uid() or coach_id = auth.uid());

drop policy if exists coach_messages_read_participants on public.coach_messages;
create policy coach_messages_read_participants
on public.coach_messages for select
to authenticated
using (
  exists (
    select 1
    from public.coach_member_threads t
    where t.id = coach_messages.thread_id
      and (t.member_id = auth.uid() or t.coach_id = auth.uid())
  )
);

drop policy if exists coach_messages_insert_participants on public.coach_messages;

drop policy if exists weekly_checkins_read_participants on public.weekly_checkins;
create policy weekly_checkins_read_participants
on public.weekly_checkins for select
to authenticated
using (member_id = auth.uid() or coach_id = auth.uid());

drop policy if exists weekly_checkins_insert_member on public.weekly_checkins;
drop policy if exists weekly_checkins_update_participants on public.weekly_checkins;
drop policy if exists weekly_checkins_update_coach_feedback on public.weekly_checkins;

drop policy if exists progress_photos_read_participants on public.progress_photos;
create policy progress_photos_read_participants
on public.progress_photos for select
to authenticated
using (
  member_id = auth.uid()
  or exists (
    select 1
    from public.weekly_checkins c
    where c.id = progress_photos.checkin_id
      and c.coach_id = auth.uid()
  )
);

drop policy if exists progress_photos_member_manage_own on public.progress_photos;
create policy progress_photos_member_manage_own
on public.progress_photos for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists payment_receipts_read_participants on public.coach_payment_receipts;
create policy payment_receipts_read_participants
on public.coach_payment_receipts for select
to authenticated
using (member_id = auth.uid() or coach_id = auth.uid());

drop policy if exists payment_receipts_insert_member on public.coach_payment_receipts;
drop policy if exists payment_receipts_update_coach on public.coach_payment_receipts;

drop policy if exists payment_audit_read_participants on public.coach_payment_audit_events;
create policy payment_audit_read_participants
on public.coach_payment_audit_events for select
to authenticated
using (
  exists (
    select 1
    from public.subscriptions s
    where s.id = coach_payment_audit_events.subscription_id
      and (s.member_id = auth.uid() or s.coach_id = auth.uid())
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

drop policy if exists coach_resources_storage_select_participants on storage.objects;
create policy coach_resources_storage_select_participants
on storage.objects for select
to authenticated
using (
  bucket_id = 'coach-resources'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or exists (
      select 1
      from public.coach_resource_assignments ra
      join public.coach_resources cr on cr.id = ra.resource_id
      where cr.storage_path = name
        and (ra.member_id = auth.uid() or ra.coach_id = auth.uid())
    )
  )
);

drop policy if exists coach_resources_storage_insert_own on storage.objects;
create policy coach_resources_storage_insert_own
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'coach-resources'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create or replace function public.coach_billing_state(
  subscription_status text,
  checkout_status text,
  latest_receipt_status text
)
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

create or replace function public.ensure_coach_member_thread(target_subscription_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  existing_thread_id uuid;
  subscription_record public.subscriptions%rowtype;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  select *
  into subscription_record
  from public.subscriptions
  where id = target_subscription_id
    and (member_id = requester or coach_id = requester);

  if subscription_record.id is null then
    raise exception 'Subscription not found.';
  end if;

  if subscription_record.status <> 'active' then
    raise exception 'Coaching thread is available only for active subscriptions.';
  end if;

  select id
  into existing_thread_id
  from public.coach_member_threads
  where subscription_id = target_subscription_id;

  if existing_thread_id is not null then
    return existing_thread_id;
  end if;

  insert into public.coach_member_threads (
    subscription_id,
    member_id,
    coach_id,
    last_message_preview,
    last_message_at
  )
  values (
    subscription_record.id,
    subscription_record.member_id,
    subscription_record.coach_id,
    'Your coaching thread is ready.',
    timezone('utc', now())
  )
  returning id into existing_thread_id;

  insert into public.coach_messages (
    thread_id,
    sender_user_id,
    sender_role,
    message_type,
    content
  )
  values (
    existing_thread_id,
    subscription_record.coach_id,
    'system',
    'system',
    'Your coaching thread is ready. Use it for weekly check-ins and follow-up.'
  );

  return existing_thread_id;
end;
$$;

create or replace function public.send_coaching_message(
  target_thread_id uuid,
  input_content text
)
returns public.coach_messages
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  requester_role text := public.current_role();
  thread_record public.coach_member_threads%rowtype;
  subscription_record public.subscriptions%rowtype;
  cleaned_content text := trim(coalesce(input_content, ''));
  inserted_message public.coach_messages%rowtype;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if cleaned_content = '' then
    raise exception 'Message cannot be empty.';
  end if;

  select *
  into thread_record
  from public.coach_member_threads
  where id = target_thread_id
    and (
      (requester_role = 'member' and member_id = requester)
      or (requester_role = 'coach' and coach_id = requester)
    );

  if thread_record.id is null then
    raise exception 'Thread not found for this user.';
  end if;

  select *
  into subscription_record
  from public.subscriptions
  where id = thread_record.subscription_id;

  if subscription_record.status <> 'active' then
    raise exception 'Messages are available only for active coaching subscriptions.';
  end if;

  if requester_role not in ('member', 'coach') then
    raise exception 'Only members and coaches can send coaching messages.';
  end if;

  insert into public.coach_messages (
    thread_id,
    sender_user_id,
    sender_role,
    message_type,
    content
  )
  values (
    thread_record.id,
    requester,
    requester_role,
    'text',
    cleaned_content
  )
  returning * into inserted_message;

  update public.coach_member_threads
  set last_message_preview = left(cleaned_content, 160),
      last_message_at = inserted_message.created_at,
      updated_at = timezone('utc', now())
  where id = thread_record.id;

  return inserted_message;
end;
$$;

create or replace function public.create_coach_checkout(
  target_package_id uuid,
  selected_payment_rail text default 'instapay',
  input_member_note text default null,
  input_intake_snapshot jsonb default '{}'::jsonb
)
returns table (
  id uuid,
  member_id uuid,
  member_name text,
  coach_id uuid,
  package_id uuid,
  package_title text,
  plan_name text,
  billing_cycle text,
  amount numeric,
  status text,
  checkout_status text,
  payment_method text,
  starts_at timestamptz,
  ends_at timestamptz,
  activated_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz,
  member_note text,
  intake_snapshot_json jsonb,
  next_renewal_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  package_record public.coach_packages%rowtype;
  coach_record public.coach_profiles%rowtype;
  created_subscription public.subscriptions%rowtype;
  charge_amount numeric(10,2);
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can start coach checkout.';
  end if;

  if selected_payment_rail not in ('card', 'instapay', 'wallet', 'manual_fallback') then
    raise exception 'Unsupported payment rail.';
  end if;

  select pkg.*
  into package_record
  from public.coach_packages pkg
  where pkg.id = target_package_id
    and pkg.visibility_status = 'published'
    and pkg.is_active = true;

  if package_record.id is null then
    raise exception 'Coach package not found.';
  end if;

  select cp.*
  into coach_record
  from public.coach_profiles cp
  where cp.user_id = package_record.coach_id;

  if coach_record.user_id is null then
    raise exception 'Coach profile not found.';
  end if;

  if exists (
    select 1
    from public.subscriptions s
    where s.member_id = requester
      and s.package_id = package_record.id
      and s.status in ('checkout_pending', 'pending_payment', 'pending_activation', 'active', 'paused')
  ) then
    raise exception 'You already have an open coaching relationship for this offer.';
  end if;

  if selected_payment_rail <> 'manual_fallback'
     and not (coalesce(package_record.payment_rails, '{card,instapay,wallet}'::text[]) @> array[selected_payment_rail]) then
    raise exception 'Selected payment rail is not available for this offer.';
  end if;

  charge_amount := case
    when coach_record.trial_offer_enabled = true
      and coalesce(package_record.trial_days, 0) > 0
      and coalesce(coach_record.trial_price_egp, 0) > 0 then coach_record.trial_price_egp
    when coalesce(package_record.deposit_amount_egp, 0) > 0 then package_record.deposit_amount_egp
    when coalesce(package_record.renewal_price_egp, 0) > 0 then package_record.renewal_price_egp
    else package_record.price
  end;

  insert into public.subscriptions (
    member_id,
    coach_id,
    package_id,
    plan_name,
    billing_cycle,
    amount,
    status,
    checkout_status,
    payment_method,
    member_note,
    intake_snapshot_json
  )
  values (
    requester,
    package_record.coach_id,
    package_record.id,
    package_record.title,
    package_record.billing_cycle,
    charge_amount,
    'checkout_pending',
    'checkout_pending',
    selected_payment_rail,
    input_member_note,
    coalesce(input_intake_snapshot, '{}'::jsonb)
  )
  returning * into created_subscription;

  insert into public.coach_checkout_requests (
    subscription_id,
    member_id,
    coach_id,
    package_id,
    payment_rail,
    requested_amount,
    payment_reference
  )
  values (
    created_subscription.id,
    created_subscription.member_id,
    created_subscription.coach_id,
    created_subscription.package_id,
    selected_payment_rail,
    charge_amount,
    null
  );

  insert into public.notifications (user_id, type, title, body, data)
  values
    (
      package_record.coach_id,
      'coaching',
      'New paid checkout started',
      'A member started checkout for "' || package_record.title || '".',
      jsonb_build_object('subscription_id', created_subscription.id, 'package_id', package_record.id, 'checkout_status', 'checkout_pending', 'payment_rail', selected_payment_rail)
    ),
    (
      requester,
      'coaching',
      'Checkout started',
      'Complete the payment to activate your coaching thread and weekly check-ins.',
      jsonb_build_object('subscription_id', created_subscription.id, 'package_id', package_record.id, 'checkout_status', 'checkout_pending', 'payment_rail', selected_payment_rail)
    );

  return query
  select
    s.id,
    s.member_id,
    coalesce(nullif(p.full_name, ''), 'GymUnity Member') as member_name,
    s.coach_id,
    s.package_id,
    coalesce(pkg.title, nullif(s.plan_name, ''), 'Coaching Offer') as package_title,
    s.plan_name,
    s.billing_cycle,
    s.amount,
    s.status,
    s.checkout_status,
    s.payment_method,
    s.starts_at,
    s.ends_at,
    s.activated_at,
    s.cancelled_at,
    s.created_at,
    s.member_note,
    s.intake_snapshot_json,
    s.next_renewal_at
  from public.subscriptions s
  join public.profiles p on p.user_id = s.member_id
  left join public.coach_packages pkg on pkg.id = s.package_id
  where s.id = created_subscription.id;
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

  if subscription_record.status not in ('checkout_pending', 'pending_payment', 'pending_activation')
     and subscription_record.checkout_status <> 'failed' then
    raise exception 'This subscription is not awaiting manual payment.';
  end if;

  resolved_status := case
    when coalesce(input_receipt_storage_path, '') <> '' then 'receipt_uploaded'
    else 'submitted'
  end;

  insert into public.coach_payment_receipts (
    subscription_id,
    member_id,
    coach_id,
    amount,
    currency,
    payment_reference,
    receipt_storage_path,
    status
  )
  values (
    subscription_record.id,
    requester,
    subscription_record.coach_id,
    coalesce(input_amount, subscription_record.amount),
    'EGP',
    nullif(trim(coalesce(input_payment_reference, '')), ''),
    nullif(trim(coalesce(input_receipt_storage_path, '')), ''),
    resolved_status
  )
  returning * into receipt_record;

  update public.subscriptions
  set checkout_status = resolved_status,
      payment_reference = coalesce(receipt_record.payment_reference, payment_reference),
      updated_at = timezone('utc', now())
  where id = subscription_record.id;

  update public.coach_checkout_requests
  set status = 'pending',
      payment_reference = coalesce(receipt_record.payment_reference, payment_reference),
      updated_at = timezone('utc', now())
  where subscription_id = subscription_record.id
    and status in ('pending', 'failed');

  insert into public.coach_payment_audit_events (
    subscription_id,
    receipt_id,
    actor_user_id,
    old_state,
    new_state,
    note
  )
  values (
    subscription_record.id,
    receipt_record.id,
    requester,
    public.coach_billing_state(subscription_record.status, subscription_record.checkout_status, null),
    public.coach_billing_state(subscription_record.status, resolved_status, receipt_record.status),
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
  latest_receipt_id uuid;
  subscription_record public.subscriptions%rowtype;
  package_record public.coach_packages%rowtype;
  computed_next_renewal timestamptz;
  computed_end timestamptz;
  thread_id uuid;
  previous_billing_state text;
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

  select id
  into latest_receipt_id
  from public.coach_payment_receipts
  where subscription_id = receipt_record.subscription_id
    and coach_id = requester
    and status in ('submitted', 'receipt_uploaded', 'under_verification')
  order by created_at desc
  limit 1;

  if latest_receipt_id is distinct from receipt_record.id then
    raise exception 'Only the latest submitted payment proof can be approved.';
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

  previous_billing_state := public.coach_billing_state(
    subscription_record.status,
    subscription_record.checkout_status,
    receipt_record.status
  );

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
    subscription_id,
    receipt_id,
    actor_user_id,
    old_state,
    new_state,
    note
  )
  values (
    subscription_record.id,
    receipt_record.id,
    requester,
    previous_billing_state,
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
  latest_receipt_id uuid;
  cleaned_reason text := trim(coalesce(input_reason, ''));
  subscription_record public.subscriptions%rowtype;
  previous_billing_state text;
begin
  if requester is null or public.current_role() <> 'coach' then
    raise exception 'Only coaches can review payments.';
  end if;

  if cleaned_reason = '' then
    raise exception 'Failure reason is required.';
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

  select id
  into latest_receipt_id
  from public.coach_payment_receipts
  where subscription_id = receipt_record.subscription_id
    and coach_id = requester
    and status in ('submitted', 'receipt_uploaded', 'under_verification')
  order by created_at desc
  limit 1;

  if latest_receipt_id is distinct from receipt_record.id then
    raise exception 'Only the latest submitted payment proof can be failed.';
  end if;

  select *
  into subscription_record
  from public.subscriptions
  where id = receipt_record.subscription_id
    and coach_id = requester;

  previous_billing_state := public.coach_billing_state(
    subscription_record.status,
    subscription_record.checkout_status,
    receipt_record.status
  );

  update public.coach_payment_receipts
  set status = 'failed',
      reviewed_by = requester,
      reviewed_at = timezone('utc', now()),
      failure_reason = cleaned_reason
  where id = receipt_record.id
  returning * into receipt_record;

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
    subscription_id,
    receipt_id,
    actor_user_id,
    old_state,
    new_state,
    note
  )
  values (
    receipt_record.subscription_id,
    receipt_record.id,
    requester,
    previous_billing_state,
    'failed_needs_follow_up',
    cleaned_reason
  );

  insert into public.notifications (user_id, type, title, body, data)
  values (
    receipt_record.member_id,
    'coaching',
    'Payment needs follow-up',
    cleaned_reason,
    jsonb_build_object('subscription_id', receipt_record.subscription_id, 'receipt_id', receipt_record.id)
  );

  return receipt_record;
end;
$$;

create or replace function public.submit_weekly_checkin(
  target_subscription_id uuid,
  input_week_start date default current_date,
  input_weight_kg numeric default null,
  input_waist_cm numeric default null,
  input_adherence_score integer default 0,
  input_energy_score integer default null,
  input_sleep_score integer default null,
  input_wins text default null,
  input_blockers text default null,
  input_questions text default null,
  input_photo_paths jsonb default '[]'::jsonb
)
returns table (
  id uuid,
  subscription_id uuid,
  thread_id uuid,
  member_id uuid,
  coach_id uuid,
  week_start date,
  weight_kg numeric,
  waist_cm numeric,
  adherence_score integer,
  energy_score integer,
  sleep_score integer,
  wins text,
  blockers text,
  questions text,
  coach_reply text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  existing_subscription public.subscriptions%rowtype;
  effective_week_start date := date_trunc('week', coalesce(input_week_start, current_date)::timestamp)::date;
  thread_record_id uuid;
  saved_checkin public.weekly_checkins%rowtype;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can submit weekly check-ins.';
  end if;

  select *
  into existing_subscription
  from public.subscriptions
  where id = target_subscription_id
    and member_id = requester;

  if existing_subscription.id is null then
    raise exception 'Subscription not found.';
  end if;

  if existing_subscription.status <> 'active' then
    raise exception 'Weekly check-ins are only available for active subscriptions.';
  end if;

  thread_record_id := public.ensure_coach_member_thread(existing_subscription.id);

  insert into public.weekly_checkins (
    subscription_id,
    thread_id,
    member_id,
    coach_id,
    week_start,
    weight_kg,
    waist_cm,
    adherence_score,
    energy_score,
    sleep_score,
    wins,
    blockers,
    questions
  )
  values (
    existing_subscription.id,
    thread_record_id,
    existing_subscription.member_id,
    existing_subscription.coach_id,
    effective_week_start,
    input_weight_kg,
    input_waist_cm,
    greatest(0, least(coalesce(input_adherence_score, 0), 100)),
    input_energy_score,
    input_sleep_score,
    input_wins,
    input_blockers,
    input_questions
  )
  on conflict (subscription_id, week_start)
  do update
  set weight_kg = excluded.weight_kg,
      waist_cm = excluded.waist_cm,
      adherence_score = excluded.adherence_score,
      energy_score = excluded.energy_score,
      sleep_score = excluded.sleep_score,
      wins = excluded.wins,
      blockers = excluded.blockers,
      questions = excluded.questions,
      thread_id = excluded.thread_id,
      updated_at = timezone('utc', now())
  returning * into saved_checkin;

  if input_weight_kg is not null then
    insert into public.member_weight_entries (member_id, weight_kg, recorded_at, note)
    values (requester, input_weight_kg, timezone('utc', now()), 'Weekly coaching check-in');
  end if;

  if input_waist_cm is not null then
    insert into public.member_body_measurements (member_id, recorded_at, waist_cm, note)
    values (requester, timezone('utc', now()), input_waist_cm, 'Weekly coaching check-in');
  end if;

  if jsonb_typeof(coalesce(input_photo_paths, '[]'::jsonb)) = 'array' then
    delete from public.progress_photos
    where checkin_id = saved_checkin.id
      and member_id = requester;

    insert into public.progress_photos (checkin_id, member_id, storage_path, angle)
    select
      saved_checkin.id,
      requester,
      photo_item.value ->> 'storage_path',
      coalesce(nullif(photo_item.value ->> 'angle', ''), 'front')
    from jsonb_array_elements(coalesce(input_photo_paths, '[]'::jsonb)) as photo_item(value)
    where coalesce(photo_item.value ->> 'storage_path', '') <> '';
  end if;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    existing_subscription.coach_id,
    'coaching',
    'Weekly check-in submitted',
    'A member submitted a weekly check-in and is waiting for feedback.',
    jsonb_build_object('subscription_id', existing_subscription.id, 'checkin_id', saved_checkin.id, 'thread_id', thread_record_id)
  );

  return query
  select
    c.id,
    c.subscription_id,
    c.thread_id,
    c.member_id,
    c.coach_id,
    c.week_start,
    c.weight_kg,
    c.waist_cm,
    c.adherence_score,
    c.energy_score,
    c.sleep_score,
    c.wins,
    c.blockers,
    c.questions,
    c.coach_reply,
    c.created_at,
    c.updated_at
  from public.weekly_checkins c
  where c.id = saved_checkin.id;
end;
$$;

create or replace function public.submit_coach_checkin_feedback(
  target_checkin_id uuid,
  target_thread_id uuid default null,
  input_feedback text default ''
)
returns public.weekly_checkins
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  checkin_record public.weekly_checkins%rowtype;
  subscription_record public.subscriptions%rowtype;
  resolved_thread_id uuid;
  cleaned_feedback text := trim(coalesce(input_feedback, ''));
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() <> 'coach' then
    raise exception 'Only coaches can submit check-in feedback.';
  end if;

  if cleaned_feedback = '' then
    raise exception 'Feedback cannot be empty.';
  end if;

  select *
  into checkin_record
  from public.weekly_checkins
  where id = target_checkin_id
    and coach_id = requester
  for update;

  if checkin_record.id is null then
    raise exception 'Check-in not found for this coach.';
  end if;

  select *
  into subscription_record
  from public.subscriptions
  where id = checkin_record.subscription_id
    and coach_id = requester;

  if subscription_record.status <> 'active' then
    raise exception 'Check-in feedback is only available for active subscriptions.';
  end if;

  if target_thread_id is not null
     and target_thread_id <> checkin_record.thread_id then
    raise exception 'Thread does not match this check-in.';
  end if;

  resolved_thread_id := coalesce(
    checkin_record.thread_id,
    public.ensure_coach_member_thread(checkin_record.subscription_id)
  );

  update public.weekly_checkins
  set coach_reply = cleaned_feedback,
      thread_id = resolved_thread_id,
      updated_at = timezone('utc', now())
  where id = checkin_record.id
  returning * into checkin_record;

  insert into public.coach_messages (
    thread_id,
    sender_user_id,
    sender_role,
    message_type,
    content
  )
  values (
    resolved_thread_id,
    requester,
    'coach',
    'checkin_feedback',
    cleaned_feedback
  );

  update public.coach_member_threads
  set last_message_preview = left(cleaned_feedback, 160),
      last_message_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  where id = resolved_thread_id;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    checkin_record.member_id,
    'coaching',
    'Coach feedback received',
    'Your coach replied to your weekly check-in.',
    jsonb_build_object('subscription_id', checkin_record.subscription_id, 'checkin_id', checkin_record.id, 'thread_id', resolved_thread_id)
  );

  return checkin_record;
end;
$$;

revoke all on function public.send_coaching_message(uuid, text) from public, anon;
grant execute on function public.send_coaching_message(uuid, text) to authenticated;
grant execute on function public.coach_billing_state(text, text, text) to authenticated;
grant execute on function public.ensure_coach_member_thread(uuid) to authenticated;
grant execute on function public.create_coach_checkout(uuid, text, text, jsonb) to authenticated;
grant execute on function public.submit_coach_payment_receipt(uuid, text, text, numeric) to authenticated;
grant execute on function public.verify_coach_payment(uuid, text) to authenticated;
grant execute on function public.fail_coach_payment(uuid, text) to authenticated;
grant execute on function public.submit_weekly_checkin(uuid, date, numeric, numeric, integer, integer, integer, text, text, text, jsonb) to authenticated;
grant execute on function public.submit_coach_checkin_feedback(uuid, uuid, text) to authenticated;
