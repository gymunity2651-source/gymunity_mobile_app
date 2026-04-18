-- Egypt-first coaching marketplace, digital checkout, messaging, and weekly check-ins
-- Date: 2026-03-18

alter table public.member_profiles
  add column if not exists budget_egp integer check (budget_egp is null or budget_egp >= 0),
  add column if not exists city text,
  add column if not exists coaching_preference text check (
    coaching_preference is null
    or coaching_preference in ('online', 'in_person', 'hybrid')
  ),
  add column if not exists training_place text check (
    training_place is null
    or training_place in ('home', 'gym', 'both')
  ),
  add column if not exists preferred_language text check (
    preferred_language is null
    or preferred_language in ('arabic', 'english')
  ),
  add column if not exists preferred_coach_gender text check (
    preferred_coach_gender is null
    or preferred_coach_gender in ('male', 'female', 'any')
  );

alter table public.coach_profiles
  add column if not exists city text,
  add column if not exists remote_only boolean not null default false,
  add column if not exists languages text[] not null default '{english}',
  add column if not exists coach_gender text check (
    coach_gender is null
    or coach_gender in ('male', 'female')
  ),
  add column if not exists verification_status text not null default 'unverified' check (
    verification_status in ('unverified', 'pending', 'verified')
  ),
  add column if not exists response_sla_hours integer not null default 12 check (
    response_sla_hours between 1 and 168
  ),
  add column if not exists trial_offer_enabled boolean not null default true,
  add column if not exists trial_price_egp numeric(10,2) not null default 0 check (
    trial_price_egp >= 0
  ),
  add column if not exists limited_spots boolean not null default false,
  add column if not exists testimonials_json jsonb not null default '[]'::jsonb,
  add column if not exists result_media_json jsonb not null default '[]'::jsonb;

alter table public.coach_packages
  add column if not exists target_goal_tags text[] not null default '{weight_loss}',
  add column if not exists location_mode text not null default 'online' check (
    location_mode in ('online', 'in_person', 'hybrid')
  ),
  add column if not exists delivery_mode text not null default 'chat' check (
    delivery_mode in ('chat', 'video', 'hybrid')
  ),
  add column if not exists weekly_checkin_type text not null default 'form' check (
    weekly_checkin_type in ('form', 'chat', 'call', 'hybrid')
  ),
  add column if not exists trial_days integer not null default 7 check (trial_days between 0 and 30),
  add column if not exists deposit_amount_egp numeric(10,2) not null default 0 check (
    deposit_amount_egp >= 0
  ),
  add column if not exists renewal_price_egp numeric(10,2) not null default 0 check (
    renewal_price_egp >= 0
  ),
  add column if not exists max_slots integer not null default 100 check (max_slots > 0),
  add column if not exists pause_allowed boolean not null default true,
  add column if not exists payment_rails text[] not null default '{card,instapay,wallet}';

alter table public.subscriptions
  add column if not exists checkout_status text not null default 'not_started' check (
    checkout_status in (
      'not_started',
      'checkout_pending',
      'paid',
      'failed',
      'refunded'
    )
  ),
  add column if not exists next_renewal_at timestamptz,
  add column if not exists cancel_at_period_end boolean not null default false,
  add column if not exists paused_at timestamptz,
  add column if not exists switched_from_subscription_id uuid references public.subscriptions(id) on delete set null,
  add column if not exists payment_reference text;

drop index if exists public.idx_subscriptions_member_package_open;
create unique index if not exists idx_subscriptions_member_package_open
  on public.subscriptions(member_id, package_id)
  where package_id is not null
    and status in ('checkout_pending', 'pending_payment', 'pending_activation', 'active', 'paused');

create table if not exists public.coach_checkout_requests (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  package_id uuid not null references public.coach_packages(id) on delete cascade,
  payment_rail text not null check (
    payment_rail in ('card', 'instapay', 'wallet', 'manual_fallback')
  ),
  requested_amount numeric(10,2) not null check (requested_amount >= 0),
  currency text not null default 'EGP',
  status text not null default 'pending' check (
    status in ('pending', 'confirmed', 'failed', 'expired')
  ),
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
  message_type text not null default 'text' check (
    message_type in ('text', 'checkin_prompt', 'system')
  ),
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

create table if not exists public.coach_verifications (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null unique references public.coach_profiles(user_id) on delete cascade,
  government_id_last4 text,
  certificate_summary text,
  reviewed_by uuid references public.profiles(user_id) on delete set null,
  status text not null default 'pending' check (
    status in ('pending', 'verified', 'rejected')
  ),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.coach_payouts (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  gross_amount numeric(10,2) not null check (gross_amount >= 0),
  commission_amount numeric(10,2) not null check (commission_amount >= 0),
  net_amount numeric(10,2) not null check (net_amount >= 0),
  payout_status text not null default 'held' check (
    payout_status in ('held', 'eligible', 'paid', 'reversed')
  ),
  eligible_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.coach_referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_user_id uuid not null references public.profiles(user_id) on delete cascade,
  referred_user_id uuid references public.profiles(user_id) on delete set null,
  referral_code text not null,
  referral_status text not null default 'sent' check (
    referral_status in ('sent', 'signed_up', 'paid', 'rewarded')
  ),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_coach_checkout_requests_subscription_status
  on public.coach_checkout_requests(subscription_id, status, created_at desc);
create index if not exists idx_coach_threads_member_updated
  on public.coach_member_threads(member_id, updated_at desc);
create index if not exists idx_coach_threads_coach_updated
  on public.coach_member_threads(coach_id, updated_at desc);
create index if not exists idx_coach_messages_thread_created
  on public.coach_messages(thread_id, created_at asc);
create index if not exists idx_weekly_checkins_member_created
  on public.weekly_checkins(member_id, created_at desc);
create index if not exists idx_weekly_checkins_coach_created
  on public.weekly_checkins(coach_id, created_at desc);
create index if not exists idx_progress_photos_checkin_created
  on public.progress_photos(checkin_id, created_at asc);
create index if not exists idx_coach_payouts_coach_created
  on public.coach_payouts(coach_id, created_at desc);
create index if not exists idx_coach_referrals_referrer_created
  on public.coach_referrals(referrer_user_id, created_at desc);

alter table public.coach_checkout_requests enable row level security;
alter table public.coach_member_threads enable row level security;
alter table public.coach_messages enable row level security;
alter table public.weekly_checkins enable row level security;
alter table public.progress_photos enable row level security;
alter table public.coach_verifications enable row level security;
alter table public.coach_payouts enable row level security;
alter table public.coach_referrals enable row level security;

drop policy if exists coach_checkout_requests_read_participants on public.coach_checkout_requests;
create policy coach_checkout_requests_read_participants
on public.coach_checkout_requests for select
using (member_id = auth.uid() or coach_id = auth.uid());

drop policy if exists coach_checkout_requests_insert_member on public.coach_checkout_requests;
create policy coach_checkout_requests_insert_member
on public.coach_checkout_requests for insert
with check (member_id = auth.uid());

drop policy if exists coach_checkout_requests_update_participants on public.coach_checkout_requests;
create policy coach_checkout_requests_update_participants
on public.coach_checkout_requests for update
using (member_id = auth.uid() or coach_id = auth.uid())
with check (member_id = auth.uid() or coach_id = auth.uid());

drop policy if exists coach_member_threads_read_participants on public.coach_member_threads;
create policy coach_member_threads_read_participants
on public.coach_member_threads for select
using (member_id = auth.uid() or coach_id = auth.uid());

drop policy if exists coach_messages_read_participants on public.coach_messages;
create policy coach_messages_read_participants
on public.coach_messages for select
using (
  exists (
    select 1
    from public.coach_member_threads t
    where t.id = coach_messages.thread_id
      and (t.member_id = auth.uid() or t.coach_id = auth.uid())
  )
);

drop policy if exists coach_messages_insert_participants on public.coach_messages;
create policy coach_messages_insert_participants
on public.coach_messages for insert
with check (
  sender_user_id = auth.uid()
  and exists (
    select 1
    from public.coach_member_threads t
    where t.id = coach_messages.thread_id
      and (t.member_id = auth.uid() or t.coach_id = auth.uid())
  )
);

drop policy if exists weekly_checkins_read_participants on public.weekly_checkins;
create policy weekly_checkins_read_participants
on public.weekly_checkins for select
using (member_id = auth.uid() or coach_id = auth.uid());

drop policy if exists weekly_checkins_insert_member on public.weekly_checkins;
create policy weekly_checkins_insert_member
on public.weekly_checkins for insert
with check (member_id = auth.uid());

drop policy if exists weekly_checkins_update_participants on public.weekly_checkins;
create policy weekly_checkins_update_participants
on public.weekly_checkins for update
using (member_id = auth.uid() or coach_id = auth.uid())
with check (member_id = auth.uid() or coach_id = auth.uid());

drop policy if exists progress_photos_read_participants on public.progress_photos;
create policy progress_photos_read_participants
on public.progress_photos for select
using (
  exists (
    select 1
    from public.weekly_checkins c
    where c.id = progress_photos.checkin_id
      and (c.member_id = auth.uid() or c.coach_id = auth.uid())
  )
);

drop policy if exists progress_photos_insert_member on public.progress_photos;
create policy progress_photos_insert_member
on public.progress_photos for insert
with check (member_id = auth.uid());

drop policy if exists coach_verifications_read_all on public.coach_verifications;
create policy coach_verifications_read_all
on public.coach_verifications for select
using (true);

drop policy if exists coach_verifications_manage_own on public.coach_verifications;
create policy coach_verifications_manage_own
on public.coach_verifications for all
using (coach_id = auth.uid())
with check (coach_id = auth.uid());

drop policy if exists coach_payouts_read_own on public.coach_payouts;
create policy coach_payouts_read_own
on public.coach_payouts for select
using (coach_id = auth.uid());

drop policy if exists coach_referrals_read_participants on public.coach_referrals;
create policy coach_referrals_read_participants
on public.coach_referrals for select
using (referrer_user_id = auth.uid() or referred_user_id = auth.uid());

drop policy if exists coach_referrals_insert_referrer on public.coach_referrals;
create policy coach_referrals_insert_referrer
on public.coach_referrals for insert
with check (referrer_user_id = auth.uid());

drop trigger if exists touch_coach_checkout_requests_updated_at on public.coach_checkout_requests;
create trigger touch_coach_checkout_requests_updated_at
before update on public.coach_checkout_requests
for each row execute function public.touch_updated_at();

drop trigger if exists touch_coach_member_threads_updated_at on public.coach_member_threads;
create trigger touch_coach_member_threads_updated_at
before update on public.coach_member_threads
for each row execute function public.touch_updated_at();

drop trigger if exists touch_weekly_checkins_updated_at on public.weekly_checkins;
create trigger touch_weekly_checkins_updated_at
before update on public.weekly_checkins
for each row execute function public.touch_updated_at();

drop trigger if exists touch_coach_verifications_updated_at on public.coach_verifications;
create trigger touch_coach_verifications_updated_at
before update on public.coach_verifications
for each row execute function public.touch_updated_at();

drop trigger if exists touch_coach_referrals_updated_at on public.coach_referrals;
create trigger touch_coach_referrals_updated_at
before update on public.coach_referrals
for each row execute function public.touch_updated_at();

create or replace function public.list_coach_directory_v2(
  specialty_filter text default null,
  city_filter text default null,
  language_filter text default null,
  gender_filter text default null,
  max_budget_egp numeric default null,
  limit_count integer default 20
)
returns table (
  user_id uuid,
  full_name text,
  city text,
  specialties text[],
  languages text[],
  coach_gender text,
  hourly_rate numeric,
  pricing_currency text,
  rating_avg numeric,
  rating_count integer,
  is_verified boolean,
  verification_status text,
  response_sla_hours integer,
  starting_package_price numeric,
  starting_package_billing_cycle text,
  active_package_count integer,
  active_client_count integer,
  trial_offer_enabled boolean,
  trial_price_egp numeric,
  limited_spots boolean,
  remote_only boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with offer_summary as (
    select
      pkg.coach_id,
      min(
        case
          when cp.trial_offer_enabled and cp.trial_price_egp > 0 then cp.trial_price_egp
          when pkg.deposit_amount_egp > 0 then pkg.deposit_amount_egp
          when pkg.renewal_price_egp > 0 then pkg.renewal_price_egp
          else pkg.price
        end
      ) as starting_package_price,
      (
        select pkg2.billing_cycle
        from public.coach_packages pkg2
        join public.coach_profiles cp2 on cp2.user_id = pkg2.coach_id
        where pkg2.coach_id = pkg.coach_id
          and pkg2.visibility_status = 'published'
        order by
          case
            when cp2.trial_offer_enabled and cp2.trial_price_egp > 0 then cp2.trial_price_egp
            when pkg2.deposit_amount_egp > 0 then pkg2.deposit_amount_egp
            when pkg2.renewal_price_egp > 0 then pkg2.renewal_price_egp
            else pkg2.price
          end asc,
          pkg2.created_at asc
        limit 1
      ) as starting_package_billing_cycle,
      count(*) filter (where pkg.visibility_status = 'published')::integer as active_package_count
    from public.coach_packages pkg
    join public.coach_profiles cp on cp.user_id = pkg.coach_id
    where pkg.visibility_status = 'published'
    group by pkg.coach_id
  )
  select
    cp.user_id,
    coalesce(nullif(p.full_name, ''), 'Coach') as full_name,
    cp.city,
    cp.specialties,
    cp.languages,
    cp.coach_gender,
    cp.hourly_rate,
    cp.pricing_currency,
    cp.rating_avg,
    cp.rating_count,
    cp.is_verified,
    cp.verification_status,
    cp.response_sla_hours,
    offer.starting_package_price,
    offer.starting_package_billing_cycle,
    coalesce(offer.active_package_count, 0) as active_package_count,
    coalesce((
      select count(distinct s.member_id)
      from public.subscriptions s
      where s.coach_id = cp.user_id
        and s.status = 'active'
    ), 0)::integer as active_client_count,
    cp.trial_offer_enabled,
    cp.trial_price_egp,
    cp.limited_spots,
    cp.remote_only
  from public.coach_profiles cp
  join public.profiles p on p.user_id = cp.user_id
  left join offer_summary offer on offer.coach_id = cp.user_id
  where (
    specialty_filter is null
    or specialty_filter = ''
    or specialty_filter = 'All'
    or exists (
      select 1 from unnest(cp.specialties) specialty
      where lower(specialty) = lower(specialty_filter)
    )
  )
    and (
      city_filter is null
      or city_filter = ''
      or lower(coalesce(cp.city, '')) = lower(city_filter)
    )
    and (
      language_filter is null
      or language_filter = ''
      or exists (
        select 1 from unnest(cp.languages) coach_language
        where lower(coach_language) = lower(language_filter)
      )
    )
    and (
      gender_filter is null
      or gender_filter = ''
      or gender_filter = 'any'
      or lower(coalesce(cp.coach_gender, '')) = lower(gender_filter)
    )
    and (
      max_budget_egp is null
      or coalesce(
        offer.starting_package_price,
        nullif(cp.trial_price_egp, 0),
        cp.hourly_rate
      ) <= max_budget_egp
    )
  order by
    cp.is_verified desc,
    cp.rating_avg desc,
    cp.rating_count desc,
    offer.starting_package_price asc nulls last,
    cp.created_at desc
  limit greatest(limit_count, 1);
$$;

create or replace function public.list_coach_directory(
  specialty_filter text default null,
  limit_count integer default 20
)
returns table (
  user_id uuid,
  full_name text,
  specialties text[],
  hourly_rate numeric,
  pricing_currency text,
  rating_avg numeric,
  rating_count integer,
  is_verified boolean,
  starting_package_price numeric,
  starting_package_billing_cycle text,
  active_package_count integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    user_id,
    full_name,
    specialties,
    hourly_rate,
    pricing_currency,
    rating_avg,
    rating_count,
    is_verified,
    starting_package_price,
    starting_package_billing_cycle,
    active_package_count
  from public.list_coach_directory_v2(
    specialty_filter => specialty_filter,
    limit_count => limit_count
  );
$$;

create or replace function public.list_coach_public_packages(target_coach_id uuid)
returns table (
  id uuid,
  coach_id uuid,
  title text,
  description text,
  billing_cycle text,
  price numeric,
  subtitle text,
  outcome_summary text,
  ideal_for text[],
  duration_weeks integer,
  sessions_per_week integer,
  difficulty_level text,
  equipment_tags text[],
  included_features text[],
  check_in_frequency text,
  support_summary text,
  faq_json jsonb,
  plan_preview_json jsonb,
  visibility_status text,
  is_active boolean,
  created_at timestamptz,
  target_goal_tags text[],
  location_mode text,
  delivery_mode text,
  weekly_checkin_type text,
  trial_days integer,
  deposit_amount_egp numeric,
  renewal_price_egp numeric,
  max_slots integer,
  pause_allowed boolean,
  payment_rails text[]
)
language sql
stable
security definer
set search_path = public
as $$
  select
    cp.id,
    cp.coach_id,
    cp.title,
    cp.description,
    cp.billing_cycle,
    cp.price,
    cp.subtitle,
    cp.outcome_summary,
    cp.ideal_for,
    cp.duration_weeks,
    cp.sessions_per_week,
    cp.difficulty_level,
    cp.equipment_tags,
    cp.included_features,
    cp.check_in_frequency,
    cp.support_summary,
    cp.faq_json,
    cp.plan_preview_json,
    cp.visibility_status,
    cp.is_active,
    cp.created_at,
    cp.target_goal_tags,
    cp.location_mode,
    cp.delivery_mode,
    cp.weekly_checkin_type,
    cp.trial_days,
    cp.deposit_amount_egp,
    cp.renewal_price_egp,
    cp.max_slots,
    cp.pause_allowed,
    cp.payment_rails
  from public.coach_packages cp
  where cp.coach_id = target_coach_id
    and cp.visibility_status = 'published'
  order by
    case
      when cp.deposit_amount_egp > 0 then cp.deposit_amount_egp
      when cp.renewal_price_egp > 0 then cp.renewal_price_egp
      else cp.price
    end asc,
    cp.created_at asc;
$$;

create or replace function public.coach_dashboard_summary()
returns table (
  active_clients integer,
  pending_requests integer,
  active_packages integer,
  active_plans integer,
  rating_avg numeric,
  rating_count integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce((select count(distinct s.member_id) from public.subscriptions s where s.coach_id = auth.uid() and s.status = 'active'), 0)::integer as active_clients,
    coalesce((select count(*) from public.subscriptions s where s.coach_id = auth.uid() and s.status in ('pending_payment', 'checkout_pending', 'pending_activation')), 0)::integer as pending_requests,
    coalesce((select count(*) from public.coach_packages cp where cp.coach_id = auth.uid() and cp.is_active = true), 0)::integer as active_packages,
    coalesce((select count(*) from public.workout_plans wp where wp.coach_id = auth.uid() and wp.status = 'active'), 0)::integer as active_plans,
    coalesce((select cp.rating_avg from public.coach_profiles cp where cp.user_id = auth.uid()), 0)::numeric as rating_avg,
    coalesce((select cp.rating_count from public.coach_profiles cp where cp.user_id = auth.uid()), 0)::integer as rating_count;
$$;

create or replace function public.list_member_subscriptions_live()
returns table (
  id uuid,
  member_id uuid,
  coach_id uuid,
  coach_name text,
  coach_city text,
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
  next_renewal_at timestamptz,
  cancel_at_period_end boolean,
  trial_days integer,
  renewal_price_egp numeric,
  response_sla_hours integer,
  verification_status text,
  weekly_checkin_type text,
  delivery_mode text,
  location_mode text,
  thread_id uuid
)
language sql
stable
security definer
set search_path = public
as $$
  select
    s.id,
    s.member_id,
    s.coach_id,
    coalesce(nullif(p.full_name, ''), 'Deleted coach') as coach_name,
    cp.city as coach_city,
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
    s.next_renewal_at,
    s.cancel_at_period_end,
    pkg.trial_days,
    pkg.renewal_price_egp,
    cp.response_sla_hours,
    cp.verification_status,
    pkg.weekly_checkin_type,
    pkg.delivery_mode,
    pkg.location_mode,
    thread.id as thread_id
  from public.subscriptions s
  left join public.profiles p on p.user_id = s.coach_id
  left join public.coach_profiles cp on cp.user_id = s.coach_id
  left join public.coach_packages pkg on pkg.id = s.package_id
  left join public.coach_member_threads thread on thread.subscription_id = s.id
  where s.member_id = auth.uid()
  order by
    case
      when s.status = 'active' then 0
      when s.status in ('checkout_pending', 'pending_payment', 'pending_activation') then 1
      else 2
    end,
    s.created_at desc;
$$;

create or replace function public.ensure_coach_member_thread(
  target_subscription_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_thread_id uuid;
  subscription_record public.subscriptions%rowtype;
begin
  select id
  into existing_thread_id
  from public.coach_member_threads
  where subscription_id = target_subscription_id;

  if existing_thread_id is not null then
    return existing_thread_id;
  end if;

  select *
  into subscription_record
  from public.subscriptions
  where id = target_subscription_id;

  if subscription_record.id is null then
    raise exception 'Subscription not found.';
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

  select *
  into package_record
  from public.coach_packages
  where id = target_package_id
    and visibility_status = 'published';

  if package_record.id is null then
    raise exception 'Coach package not found.';
  end if;

  select *
  into coach_record
  from public.coach_profiles
  where user_id = package_record.coach_id;

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

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data
  )
  values (
    package_record.coach_id,
    'coaching',
    'New paid checkout started',
    'A member started checkout for "' || package_record.title || '".',
    jsonb_build_object(
      'subscription_id', created_subscription.id,
      'package_id', package_record.id,
      'checkout_status', 'checkout_pending',
      'payment_rail', selected_payment_rail
    )
  );

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data
  )
  values (
    requester,
    'coaching',
    'Checkout started',
    'Complete the payment to activate your coaching thread and weekly check-ins.',
    jsonb_build_object(
      'subscription_id', created_subscription.id,
      'package_id', package_record.id,
      'checkout_status', 'checkout_pending',
      'payment_rail', selected_payment_rail
    )
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

create or replace function public.confirm_coach_payment(
  target_subscription_id uuid,
  input_payment_reference text default null
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
  existing_subscription public.subscriptions%rowtype;
  package_record public.coach_packages%rowtype;
  checkout_record public.coach_checkout_requests%rowtype;
  effective_start timestamptz := timezone('utc', now());
  computed_end timestamptz;
  computed_next_renewal timestamptz;
  created_thread_id uuid;
  commission_amount numeric(10,2);
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can confirm coach payments.';
  end if;

  select *
  into existing_subscription
  from public.subscriptions
  where id = target_subscription_id
    and member_id = requester;

  if existing_subscription.id is null then
    raise exception 'Subscription not found.';
  end if;

  if existing_subscription.status not in ('checkout_pending', 'pending_payment', 'pending_activation') then
    raise exception 'This subscription is not waiting for payment confirmation.';
  end if;

  select *
  into package_record
  from public.coach_packages
  where id = existing_subscription.package_id;

  select *
  into checkout_record
  from public.coach_checkout_requests
  where subscription_id = existing_subscription.id
  order by created_at desc
  limit 1;

  if checkout_record.id is null then
    raise exception 'Checkout request not found.';
  end if;

  computed_next_renewal := case existing_subscription.billing_cycle
    when 'weekly' then effective_start + interval '7 days'
    when 'quarterly' then effective_start + interval '3 months'
    when 'one_time' then null
    else effective_start + interval '1 month'
  end;

  computed_end := case existing_subscription.billing_cycle
    when 'one_time' then effective_start + make_interval(days => greatest(coalesce(package_record.trial_days, 0), 1))
    else computed_next_renewal
  end;

  update public.subscriptions
  set status = 'active',
      checkout_status = 'paid',
      payment_method = checkout_record.payment_rail,
      starts_at = coalesce(starts_at, effective_start),
      ends_at = coalesce(ends_at, computed_end),
      activated_at = coalesce(activated_at, effective_start),
      next_renewal_at = computed_next_renewal,
      payment_reference = coalesce(input_payment_reference, payment_reference),
      updated_at = timezone('utc', now())
  where id = existing_subscription.id
  returning * into existing_subscription;

  update public.coach_checkout_requests
  set status = 'confirmed',
      payment_reference = coalesce(input_payment_reference, payment_reference),
      updated_at = timezone('utc', now())
  where id = checkout_record.id;

  created_thread_id := public.ensure_coach_member_thread(existing_subscription.id);

  commission_amount := round(existing_subscription.amount * 0.15, 2);

  insert into public.coach_payouts (
    coach_id,
    subscription_id,
    gross_amount,
    commission_amount,
    net_amount,
    payout_status,
    eligible_at
  )
  select
    existing_subscription.coach_id,
    existing_subscription.id,
    existing_subscription.amount,
    commission_amount,
    greatest(existing_subscription.amount - commission_amount, 0),
    'held',
    effective_start + interval '14 days'
  where not exists (
    select 1
    from public.coach_payouts cp
    where cp.subscription_id = existing_subscription.id
  );

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data
  )
  values (
    existing_subscription.coach_id,
    'coaching',
    'Checkout paid',
    'A member completed payment and the coaching thread is now live.',
    jsonb_build_object(
      'subscription_id', existing_subscription.id,
      'thread_id', created_thread_id,
      'status', 'active'
    )
  );

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data
  )
  values (
    requester,
    'coaching',
    'Payment confirmed',
    'Your coaching subscription is active. Start your first weekly check-in now.',
    jsonb_build_object(
      'subscription_id', existing_subscription.id,
      'thread_id', created_thread_id,
      'status', 'active'
    )
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
  where s.id = existing_subscription.id;
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

  if existing_subscription.status not in ('active', 'paused') then
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
    insert into public.member_weight_entries (
      member_id,
      weight_kg,
      recorded_at,
      note
    )
    values (
      requester,
      input_weight_kg,
      timezone('utc', now()),
      'Weekly coaching check-in'
    );
  end if;

  if input_waist_cm is not null then
    insert into public.member_body_measurements (
      member_id,
      recorded_at,
      waist_cm,
      note
    )
    values (
      requester,
      timezone('utc', now()),
      input_waist_cm,
      'Weekly coaching check-in'
    );
  end if;

  if jsonb_typeof(coalesce(input_photo_paths, '[]'::jsonb)) = 'array' then
    delete from public.progress_photos
    where checkin_id = saved_checkin.id;

    insert into public.progress_photos (
      checkin_id,
      member_id,
      storage_path,
      angle
    )
    select
      saved_checkin.id,
      requester,
      photo_item.value ->> 'storage_path',
      coalesce(nullif(photo_item.value ->> 'angle', ''), 'front')
    from jsonb_array_elements(coalesce(input_photo_paths, '[]'::jsonb)) as photo_item(value)
    where coalesce(photo_item.value ->> 'storage_path', '') <> '';
  end if;

  insert into public.coach_messages (
    thread_id,
    sender_user_id,
    sender_role,
    message_type,
    content
  )
  values (
    thread_record_id,
    requester,
    'member',
    'checkin_prompt',
    'Weekly check-in submitted. Adherence: ' ||
      greatest(0, least(coalesce(input_adherence_score, 0), 100))::text || '%.'
  );

  update public.coach_payouts
  set payout_status = case
        when payout_status = 'held' then 'eligible'
        else payout_status
      end,
      eligible_at = coalesce(eligible_at, timezone('utc', now()))
  where subscription_id = existing_subscription.id
    and payout_status in ('held', 'eligible');

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data
  )
  values (
    existing_subscription.coach_id,
    'coaching',
    'New weekly check-in',
    'A member submitted a weekly check-in and is waiting for feedback.',
    jsonb_build_object(
      'subscription_id', existing_subscription.id,
      'checkin_id', saved_checkin.id,
      'thread_id', thread_record_id
    )
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

create or replace function public.pause_coach_subscription(
  target_subscription_id uuid,
  pause_now boolean default true
)
returns table (
  id uuid,
  status text,
  checkout_status text,
  paused_at timestamptz,
  cancel_at_period_end boolean,
  next_renewal_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  existing_subscription public.subscriptions%rowtype;
  package_record public.coach_packages%rowtype;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  select *
  into existing_subscription
  from public.subscriptions
  where id = target_subscription_id
    and (member_id = requester or coach_id = requester);

  if existing_subscription.id is null then
    raise exception 'Subscription not found.';
  end if;

  select *
  into package_record
  from public.coach_packages
  where id = existing_subscription.package_id;

  if coalesce(package_record.pause_allowed, true) = false then
    raise exception 'This coaching offer does not allow pausing.';
  end if;

  update public.subscriptions
  set status = case when pause_now then 'paused' else 'active' end,
      paused_at = case when pause_now then timezone('utc', now()) else null end,
      updated_at = timezone('utc', now())
  where id = existing_subscription.id
  returning * into existing_subscription;

  return query
  select
    s.id,
    s.status,
    s.checkout_status,
    s.paused_at,
    s.cancel_at_period_end,
    s.next_renewal_at
  from public.subscriptions s
  where s.id = existing_subscription.id;
end;
$$;

create or replace function public.switch_coach_request(
  target_subscription_id uuid,
  new_package_id uuid,
  input_reason text default null
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
  current_subscription public.subscriptions%rowtype;
  target_package public.coach_packages%rowtype;
  created_subscription public.subscriptions%rowtype;
  charge_amount numeric(10,2);
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can switch coaches.';
  end if;

  select *
  into current_subscription
  from public.subscriptions
  where id = target_subscription_id
    and member_id = requester;

  if current_subscription.id is null then
    raise exception 'Current subscription not found.';
  end if;

  select *
  into target_package
  from public.coach_packages
  where id = new_package_id
    and visibility_status = 'published';

  if target_package.id is null then
    raise exception 'Target coaching offer not found.';
  end if;

  if current_subscription.package_id = target_package.id then
    raise exception 'Choose a different coaching offer to switch.';
  end if;

  charge_amount := case
    when coalesce(target_package.deposit_amount_egp, 0) > 0 then target_package.deposit_amount_egp
    when coalesce(target_package.renewal_price_egp, 0) > 0 then target_package.renewal_price_egp
    else target_package.price
  end;

  update public.subscriptions
  set cancel_at_period_end = true,
      updated_at = timezone('utc', now())
  where id = current_subscription.id;

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
    intake_snapshot_json,
    switched_from_subscription_id
  )
  values (
    requester,
    target_package.coach_id,
    target_package.id,
    target_package.title,
    target_package.billing_cycle,
    charge_amount,
    'checkout_pending',
    'checkout_pending',
    'instapay',
    input_reason,
    coalesce(current_subscription.intake_snapshot_json, '{}'::jsonb),
    current_subscription.id
  )
  returning * into created_subscription;

  insert into public.coach_checkout_requests (
    subscription_id,
    member_id,
    coach_id,
    package_id,
    payment_rail,
    requested_amount
  )
  values (
    created_subscription.id,
    created_subscription.member_id,
    created_subscription.coach_id,
    created_subscription.package_id,
    'instapay',
    charge_amount
  );

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data
  )
  values (
    target_package.coach_id,
    'coaching',
    'Switch request started',
    'A member started checkout to switch into your coaching offer.',
    jsonb_build_object(
      'subscription_id', created_subscription.id,
      'switched_from_subscription_id', current_subscription.id
    )
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

create or replace function public.sync_coach_thread_after_message()
returns trigger
language plpgsql
as $$
begin
  update public.coach_member_threads
  set last_message_preview = left(new.content, 120),
      last_message_at = new.created_at,
      updated_at = timezone('utc', now())
  where id = new.thread_id;

  return new;
end;
$$;

drop trigger if exists sync_coach_thread_after_message on public.coach_messages;
create trigger sync_coach_thread_after_message
after insert on public.coach_messages
for each row execute function public.sync_coach_thread_after_message();

grant execute on function public.list_coach_directory_v2(text, text, text, text, numeric, integer) to authenticated;
grant execute on function public.list_coach_directory(text, integer) to authenticated;
grant execute on function public.list_coach_public_packages(uuid) to authenticated;
grant execute on function public.coach_dashboard_summary() to authenticated;
grant execute on function public.list_member_subscriptions_live() to authenticated;
grant execute on function public.ensure_coach_member_thread(uuid) to authenticated;
grant execute on function public.create_coach_checkout(uuid, text, text, jsonb) to authenticated;
grant execute on function public.confirm_coach_payment(uuid, text) to authenticated;
grant execute on function public.submit_weekly_checkin(uuid, date, numeric, numeric, integer, integer, integer, text, text, text, jsonb) to authenticated;
grant execute on function public.pause_coach_subscription(uuid, boolean) to authenticated;
grant execute on function public.switch_coach_request(uuid, uuid, text) to authenticated;
