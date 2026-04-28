-- Public coach profile conversion fields and community/group coaching hooks
-- Date: 2026-04-21

alter table public.coach_profiles
  add column if not exists headline text not null default '',
  add column if not exists positioning_statement text not null default '',
  add column if not exists certifications_json jsonb not null default '[]'::jsonb,
  add column if not exists trust_badges_json jsonb not null default '[]'::jsonb,
  add column if not exists faq_json jsonb not null default '[]'::jsonb,
  add column if not exists response_metrics_json jsonb not null default '{}'::jsonb;

-- Prepared but hidden v1 community/group coaching hooks.
create table if not exists public.coach_group_programs (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  title text not null,
  description text not null default '',
  program_template_id uuid references public.coach_program_templates(id) on delete set null,
  capacity integer not null default 20 check (capacity > 0),
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.coach_challenges (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  group_program_id uuid references public.coach_group_programs(id) on delete cascade,
  title text not null,
  challenge_type text not null default 'habit' check (
    challenge_type in ('habit', 'steps', 'workouts', 'checkins', 'custom')
  ),
  starts_on date,
  ends_on date,
  leaderboard_enabled boolean not null default false,
  status text not null default 'draft' check (status in ('draft', 'active', 'completed', 'archived')),
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (ends_on is null or starts_on is null or ends_on >= starts_on)
);

create table if not exists public.coach_group_memberships (
  id uuid primary key default gen_random_uuid(),
  group_program_id uuid not null references public.coach_group_programs(id) on delete cascade,
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  status text not null default 'active' check (status in ('active', 'paused', 'completed', 'removed')),
  joined_at timestamptz not null default timezone('utc', now()),
  unique (group_program_id, member_id)
);

create table if not exists public.coach_group_posts (
  id uuid primary key default gen_random_uuid(),
  group_program_id uuid not null references public.coach_group_programs(id) on delete cascade,
  author_user_id uuid not null references public.profiles(user_id) on delete cascade,
  content text not null,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.coach_group_programs enable row level security;
alter table public.coach_challenges enable row level security;
alter table public.coach_group_memberships enable row level security;
alter table public.coach_group_posts enable row level security;

drop policy if exists group_programs_read_published_or_own on public.coach_group_programs;
create policy group_programs_read_published_or_own
on public.coach_group_programs for select
to authenticated
using (
  coach_id = auth.uid()
  or status = 'published'
  or exists (
    select 1
    from public.coach_group_memberships m
    where m.group_program_id = coach_group_programs.id
      and m.member_id = auth.uid()
  )
);

drop policy if exists group_programs_manage_own on public.coach_group_programs;
create policy group_programs_manage_own
on public.coach_group_programs for all
to authenticated
using (coach_id = auth.uid())
with check (coach_id = auth.uid());

drop policy if exists challenges_read_participants on public.coach_challenges;
create policy challenges_read_participants
on public.coach_challenges for select
to authenticated
using (
  coach_id = auth.uid()
  or exists (
    select 1
    from public.coach_group_memberships m
    where m.group_program_id = coach_challenges.group_program_id
      and m.member_id = auth.uid()
  )
);

drop policy if exists challenges_manage_own on public.coach_challenges;
create policy challenges_manage_own
on public.coach_challenges for all
to authenticated
using (coach_id = auth.uid())
with check (coach_id = auth.uid());

drop policy if exists group_memberships_read_participants on public.coach_group_memberships;
create policy group_memberships_read_participants
on public.coach_group_memberships for select
to authenticated
using (coach_id = auth.uid() or member_id = auth.uid());

drop policy if exists group_memberships_manage_coach on public.coach_group_memberships;
create policy group_memberships_manage_coach
on public.coach_group_memberships for all
to authenticated
using (coach_id = auth.uid())
with check (coach_id = auth.uid());

drop policy if exists group_posts_read_participants on public.coach_group_posts;
create policy group_posts_read_participants
on public.coach_group_posts for select
to authenticated
using (
  exists (
    select 1
    from public.coach_group_programs gp
    left join public.coach_group_memberships m
      on m.group_program_id = gp.id and m.member_id = auth.uid()
    where gp.id = coach_group_posts.group_program_id
      and (gp.coach_id = auth.uid() or m.id is not null)
  )
);

drop policy if exists group_posts_insert_participants on public.coach_group_posts;
create policy group_posts_insert_participants
on public.coach_group_posts for insert
to authenticated
with check (
  author_user_id = auth.uid()
  and exists (
    select 1
    from public.coach_group_programs gp
    left join public.coach_group_memberships m
      on m.group_program_id = gp.id and m.member_id = auth.uid()
    where gp.id = coach_group_posts.group_program_id
      and (gp.coach_id = auth.uid() or m.id is not null)
  )
);

drop trigger if exists touch_coach_group_programs_updated_at on public.coach_group_programs;
create trigger touch_coach_group_programs_updated_at
before update on public.coach_group_programs
for each row execute function public.touch_updated_at();

drop trigger if exists touch_coach_challenges_updated_at on public.coach_challenges;
create trigger touch_coach_challenges_updated_at
before update on public.coach_challenges
for each row execute function public.touch_updated_at();

drop trigger if exists touch_coach_group_posts_updated_at on public.coach_group_posts;
create trigger touch_coach_group_posts_updated_at
before update on public.coach_group_posts
for each row execute function public.touch_updated_at();

drop function if exists public.list_coach_directory_v2(text, text, text, text, numeric, integer);

create function public.list_coach_directory_v2(
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
  remote_only boolean,
  headline text,
  positioning_statement text,
  certifications_json jsonb,
  trust_badges_json jsonb,
  response_metrics_json jsonb
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
    cp.remote_only,
    cp.headline,
    cp.positioning_statement,
    cp.certifications_json,
    cp.trust_badges_json,
    cp.response_metrics_json
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

grant execute on function public.list_coach_directory_v2(text, text, text, text, numeric, integer) to authenticated;
