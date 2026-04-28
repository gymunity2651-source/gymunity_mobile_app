-- Coach workspace CRM, dashboard aggregates, private notes, action events, and read state
-- Date: 2026-04-21

create table if not exists public.coach_client_records (
  subscription_id uuid primary key references public.subscriptions(id) on delete cascade,
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  pipeline_stage text not null default 'lead' check (
    pipeline_stage in ('lead', 'pending_payment', 'active', 'at_risk', 'paused', 'completed', 'archived')
  ),
  internal_status text not null default 'new' check (
    internal_status in ('new', 'contacted', 'onboarding', 'active', 'needs_follow_up', 'paused', 'completed', 'archived')
  ),
  risk_status text not null default 'none' check (
    risk_status in ('none', 'watch', 'at_risk', 'critical')
  ),
  tags text[] not null default '{}',
  coach_notes text not null default '',
  preferred_language text,
  follow_up_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (coach_id, member_id, subscription_id)
);

create table if not exists public.coach_client_notes (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  note text not null,
  note_type text not null default 'general' check (
    note_type in ('general', 'goal', 'risk', 'billing', 'program', 'nutrition', 'call')
  ),
  is_pinned boolean not null default false,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.coach_automation_events (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  member_id uuid references public.profiles(user_id) on delete cascade,
  subscription_id uuid references public.subscriptions(id) on delete cascade,
  event_type text not null check (
    event_type in (
      'low_adherence',
      'many_missed_workouts',
      'no_recent_checkin',
      'payment_pending_too_long',
      'renewal_soon',
      'missed_checkin',
      'inactive_client',
      'unread_message'
    )
  ),
  severity text not null default 'medium' check (severity in ('low', 'medium', 'high', 'critical')),
  status text not null default 'open' check (status in ('open', 'snoozed', 'resolved', 'dismissed')),
  title text not null,
  body text not null default '',
  cta_label text not null default 'Open client',
  due_at timestamptz,
  resolved_at timestamptz,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.coach_thread_reads (
  thread_id uuid not null references public.coach_member_threads(id) on delete cascade,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  last_read_at timestamptz not null default '1970-01-01'::timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (thread_id, user_id)
);

create index if not exists idx_coach_client_records_coach_stage
  on public.coach_client_records(coach_id, pipeline_stage, updated_at desc);
create index if not exists idx_coach_client_notes_subscription_created
  on public.coach_client_notes(subscription_id, created_at desc);
create index if not exists idx_coach_events_coach_status_due
  on public.coach_automation_events(coach_id, status, due_at nulls first, created_at desc);
create index if not exists idx_coach_thread_reads_user
  on public.coach_thread_reads(user_id, updated_at desc);

alter table public.coach_client_records enable row level security;
alter table public.coach_client_notes enable row level security;
alter table public.coach_automation_events enable row level security;
alter table public.coach_thread_reads enable row level security;

drop policy if exists coach_client_records_manage_own on public.coach_client_records;
create policy coach_client_records_manage_own
on public.coach_client_records for all
to authenticated
using (coach_id = auth.uid())
with check (coach_id = auth.uid());

drop policy if exists coach_client_notes_manage_own on public.coach_client_notes;
create policy coach_client_notes_manage_own
on public.coach_client_notes for all
to authenticated
using (coach_id = auth.uid())
with check (coach_id = auth.uid());

drop policy if exists coach_automation_events_manage_own on public.coach_automation_events;
create policy coach_automation_events_manage_own
on public.coach_automation_events for all
to authenticated
using (coach_id = auth.uid())
with check (coach_id = auth.uid());

drop policy if exists coach_thread_reads_manage_participant on public.coach_thread_reads;
create policy coach_thread_reads_manage_participant
on public.coach_thread_reads for all
to authenticated
using (
  user_id = auth.uid()
  and exists (
    select 1
    from public.coach_member_threads t
    where t.id = coach_thread_reads.thread_id
      and (t.coach_id = auth.uid() or t.member_id = auth.uid())
  )
)
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.coach_member_threads t
    where t.id = coach_thread_reads.thread_id
      and (t.coach_id = auth.uid() or t.member_id = auth.uid())
  )
);

drop trigger if exists touch_coach_client_records_updated_at on public.coach_client_records;
create trigger touch_coach_client_records_updated_at
before update on public.coach_client_records
for each row execute function public.touch_updated_at();

drop trigger if exists touch_coach_client_notes_updated_at on public.coach_client_notes;
create trigger touch_coach_client_notes_updated_at
before update on public.coach_client_notes
for each row execute function public.touch_updated_at();

drop trigger if exists touch_coach_automation_events_updated_at on public.coach_automation_events;
create trigger touch_coach_automation_events_updated_at
before update on public.coach_automation_events
for each row execute function public.touch_updated_at();

drop trigger if exists touch_coach_thread_reads_updated_at on public.coach_thread_reads;
create trigger touch_coach_thread_reads_updated_at
before update on public.coach_thread_reads
for each row execute function public.touch_updated_at();

create or replace function public.derive_coach_pipeline_stage(subscription_status text, checkout_status text)
returns text
language sql
immutable
as $$
  select case
    when subscription_status in ('checkout_pending', 'pending_payment', 'pending_activation')
      or checkout_status in ('checkout_pending', 'submitted', 'receipt_uploaded', 'under_verification') then 'pending_payment'
    when subscription_status = 'active' then 'active'
    when subscription_status = 'paused' then 'paused'
    when subscription_status in ('completed', 'cancelled') then 'completed'
    else 'lead'
  end;
$$;

create or replace function public.coach_workspace_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  today_start timestamptz := date_trunc('day', timezone('utc', now()));
  result jsonb;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  select jsonb_build_object(
    'active_clients', coalesce((select count(distinct s.member_id) from public.subscriptions s where s.coach_id = requester and s.status = 'active'), 0),
    'new_leads', coalesce((select count(*) from public.subscriptions s where s.coach_id = requester and s.status in ('checkout_pending', 'pending_payment', 'pending_activation')), 0),
    'pending_payment_verifications', coalesce((select count(*) from public.coach_payment_receipts r where r.coach_id = requester and r.status in ('submitted', 'under_verification')), 0),
    'at_risk_clients', coalesce((select count(*) from public.coach_client_records r where r.coach_id = requester and (r.pipeline_stage = 'at_risk' or r.risk_status in ('at_risk', 'critical'))), 0),
    'overdue_checkins', coalesce((
      select count(*)
      from public.subscriptions s
      where s.coach_id = requester
        and s.status = 'active'
        and coalesce((select max(wc.created_at) from public.weekly_checkins wc where wc.subscription_id = s.id), s.activated_at, s.created_at) < now() - interval '14 days'
    ), 0),
    'unread_messages', coalesce((
      select count(*)
      from public.coach_messages m
      join public.coach_member_threads t on t.id = m.thread_id
      left join public.coach_thread_reads r on r.thread_id = t.id and r.user_id = requester
      where t.coach_id = requester
        and m.sender_user_id <> requester
        and m.created_at > coalesce(r.last_read_at, '1970-01-01'::timestamptz)
    ), 0),
    'renewals_due_soon', coalesce((select count(*) from public.subscriptions s where s.coach_id = requester and s.status = 'active' and s.next_renewal_at between now() and now() + interval '14 days'), 0),
    'today_sessions', coalesce((select count(*) from public.coach_bookings b where b.coach_id = requester and b.starts_at >= today_start and b.starts_at < today_start + interval '1 day' and b.status in ('scheduled', 'confirmed')), 0),
    'revenue_month', coalesce((select sum(s.amount) from public.subscriptions s where s.coach_id = requester and s.status = 'active' and s.activated_at >= date_trunc('month', now())), 0),
    'package_performance', coalesce((
      select jsonb_agg(jsonb_build_object(
        'package_id', pkg.id,
        'title', pkg.title,
        'active_clients', coalesce(stats.active_clients, 0),
        'pending_clients', coalesce(stats.pending_clients, 0),
        'revenue', coalesce(stats.revenue, 0)
      ) order by coalesce(stats.revenue, 0) desc, pkg.created_at desc)
      from public.coach_packages pkg
      left join lateral (
        select
          count(*) filter (where s.status = 'active') as active_clients,
          count(*) filter (where s.status in ('checkout_pending', 'pending_payment', 'pending_activation')) as pending_clients,
          sum(s.amount) filter (where s.status = 'active') as revenue
        from public.subscriptions s
        where s.package_id = pkg.id
      ) stats on true
      where pkg.coach_id = requester
    ), '[]'::jsonb)
  )
  into result;

  return result;
end;
$$;

create or replace function public.list_coach_action_items()
returns table (
  id uuid,
  event_type text,
  severity text,
  status text,
  title text,
  body text,
  cta_label text,
  member_id uuid,
  member_name text,
  subscription_id uuid,
  due_at timestamptz,
  metadata_json jsonb,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  with generated as (
    select
      gen_random_uuid() as id,
      'payment_pending_too_long'::text as event_type,
      'high'::text as severity,
      'open'::text as status,
      'Payment pending too long'::text as title,
      coalesce(nullif(p.full_name, ''), 'Member') || ' has been waiting more than 48 hours.' as body,
      'Review payment'::text as cta_label,
      s.member_id,
      coalesce(nullif(p.full_name, ''), 'Member') as member_name,
      s.id as subscription_id,
      s.created_at + interval '48 hours' as due_at,
      jsonb_build_object('source', 'generated') as metadata_json,
      s.created_at
    from public.subscriptions s
    join public.profiles p on p.user_id = s.member_id
    where s.coach_id = auth.uid()
      and s.status in ('checkout_pending', 'pending_payment', 'pending_activation')
      and s.created_at < now() - interval '48 hours'

    union all

    select
      gen_random_uuid(),
      'renewal_soon',
      'medium',
      'open',
      'Subscription renewal soon',
      coalesce(nullif(p.full_name, ''), 'Member') || ' renews soon.',
      'Open client',
      s.member_id,
      coalesce(nullif(p.full_name, ''), 'Member'),
      s.id,
      s.next_renewal_at,
      jsonb_build_object('source', 'generated'),
      coalesce(s.next_renewal_at, s.created_at)
    from public.subscriptions s
    join public.profiles p on p.user_id = s.member_id
    where s.coach_id = auth.uid()
      and s.status = 'active'
      and s.next_renewal_at between now() and now() + interval '14 days'

    union all

    select
      gen_random_uuid(),
      'no_recent_checkin',
      'medium',
      'open',
      'No recent check-in',
      coalesce(nullif(p.full_name, ''), 'Member') || ' has not checked in recently.',
      'Send reminder',
      s.member_id,
      coalesce(nullif(p.full_name, ''), 'Member') as member_name,
      s.id as subscription_id,
      now() as due_at,
      jsonb_build_object('source', 'generated') as metadata_json,
      coalesce((select max(wc.created_at) from public.weekly_checkins wc where wc.subscription_id = s.id), s.activated_at, s.created_at) as created_at
    from public.subscriptions s
    join public.profiles p on p.user_id = s.member_id
    where s.coach_id = auth.uid()
      and s.status = 'active'
      and coalesce((select max(wc.created_at) from public.weekly_checkins wc where wc.subscription_id = s.id), s.activated_at, s.created_at) < now() - interval '14 days'
  )
  select e.id, e.event_type, e.severity, e.status, e.title, e.body, e.cta_label,
         e.member_id,
         coalesce(nullif(p.full_name, ''), 'Member') as member_name,
         e.subscription_id, e.due_at, e.metadata_json, e.created_at
  from public.coach_automation_events e
  left join public.profiles p on p.user_id = e.member_id
  where e.coach_id = auth.uid()
    and e.status in ('open', 'snoozed')
  union all
  select * from generated
  order by due_at nulls first, created_at desc
  limit 50;
$$;

create or replace function public.list_coach_client_pipeline(input_filters jsonb default '{}'::jsonb)
returns table (
  subscription_id uuid,
  member_id uuid,
  member_name text,
  member_avatar_path text,
  package_id uuid,
  package_title text,
  status text,
  checkout_status text,
  billing_cycle text,
  amount numeric,
  pipeline_stage text,
  internal_status text,
  risk_status text,
  tags text[],
  coach_notes text,
  goal text,
  city text,
  gender text,
  language text,
  started_at timestamptz,
  next_renewal_at timestamptz,
  last_checkin_at timestamptz,
  unread_messages integer,
  risk_flags text[]
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  filter_stage text := nullif(input_filters ->> 'pipeline_stage', '');
  filter_goal text := nullif(input_filters ->> 'goal', '');
  filter_package uuid := nullif(input_filters ->> 'package_id', '')::uuid;
  filter_city text := nullif(input_filters ->> 'city', '');
  filter_gender text := nullif(input_filters ->> 'gender', '');
  filter_language text := nullif(input_filters ->> 'language', '');
  filter_risk text := nullif(input_filters ->> 'risk_status', '');
  filter_subscription_id uuid := nullif(input_filters ->> 'subscription_id', '')::uuid;
  filter_start_from date := nullif(input_filters ->> 'start_date_from', '')::date;
  filter_start_to date := nullif(input_filters ->> 'start_date_to', '')::date;
  filter_renewal_status text := nullif(input_filters ->> 'renewal_status', '');
  search_text text := lower(coalesce(input_filters ->> 'search', ''));
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  return query
  with base as (
    select
      s.id as subscription_id,
      s.member_id,
      coalesce(nullif(p.full_name, ''), 'Member') as member_name,
      p.avatar_path as member_avatar_path,
      s.package_id,
      coalesce(pkg.title, s.plan_name, 'Coaching') as package_title,
      s.status,
      s.checkout_status,
      s.billing_cycle,
      s.amount,
      coalesce(r.pipeline_stage, public.derive_coach_pipeline_stage(s.status, s.checkout_status)) as pipeline_stage,
      coalesce(r.internal_status, case when s.status = 'active' then 'active' else 'new' end) as internal_status,
      coalesce(r.risk_status, 'none') as risk_status,
      coalesce(r.tags, '{}'::text[]) as tags,
      coalesce(r.coach_notes, '') as coach_notes,
      mp.goal,
      mp.city,
      mp.gender,
      coalesce(r.preferred_language, mp.preferred_language) as language,
      coalesce(s.activated_at, s.starts_at, s.created_at) as started_at,
      s.next_renewal_at,
      (select max(wc.created_at) from public.weekly_checkins wc where wc.subscription_id = s.id) as last_checkin_at,
      coalesce((
        select count(*)::integer
        from public.coach_member_threads t
        join public.coach_messages m on m.thread_id = t.id
        left join public.coach_thread_reads tr on tr.thread_id = t.id and tr.user_id = requester
        where t.subscription_id = s.id
          and m.sender_user_id <> requester
          and m.created_at > coalesce(tr.last_read_at, '1970-01-01'::timestamptz)
      ), 0) as unread_messages,
      array_remove(array[
        case when coalesce(r.risk_status, 'none') in ('at_risk', 'critical') then 'manual_risk' else null end,
        case when coalesce((select max(wc.created_at) from public.weekly_checkins wc where wc.subscription_id = s.id), s.activated_at, s.created_at) < now() - interval '14 days' and s.status = 'active' then 'no_recent_checkin' else null end,
        case when s.next_renewal_at between now() and now() + interval '14 days' then 'renewal_soon' else null end,
        case when s.status in ('checkout_pending', 'pending_payment', 'pending_activation') and s.created_at < now() - interval '48 hours' then 'payment_pending_too_long' else null end
      ], null) as risk_flags
    from public.subscriptions s
    join public.profiles p on p.user_id = s.member_id
    left join public.member_profiles mp on mp.user_id = s.member_id
    left join public.coach_packages pkg on pkg.id = s.package_id
    left join public.coach_client_records r on r.subscription_id = s.id and r.coach_id = requester
    where s.coach_id = requester
  )
  select *
  from base b
  where (filter_subscription_id is null or b.subscription_id = filter_subscription_id)
    and (filter_stage is null or b.pipeline_stage = filter_stage)
    and (filter_goal is null or lower(coalesce(b.goal, '')) = lower(filter_goal))
    and (filter_package is null or b.package_id = filter_package)
    and (filter_city is null or lower(coalesce(b.city, '')) = lower(filter_city))
    and (filter_gender is null or lower(coalesce(b.gender, '')) = lower(filter_gender))
    and (filter_language is null or lower(coalesce(b.language, '')) = lower(filter_language))
    and (filter_start_from is null or b.started_at::date >= filter_start_from)
    and (filter_start_to is null or b.started_at::date <= filter_start_to)
    and (
      filter_renewal_status is null
      or (filter_renewal_status = 'due_soon' and b.next_renewal_at between now() and now() + interval '14 days')
      or (filter_renewal_status = 'overdue' and b.next_renewal_at < now())
      or (filter_renewal_status = 'none' and b.next_renewal_at is null)
    )
    and (filter_risk is null or b.risk_status = filter_risk or filter_risk = any(b.risk_flags))
    and (
      search_text = ''
      or lower(b.member_name) like '%' || search_text || '%'
      or lower(coalesce(b.package_title, '')) like '%' || search_text || '%'
      or lower(coalesce(b.goal, '')) like '%' || search_text || '%'
    )
  order by
    case b.pipeline_stage
      when 'pending_payment' then 0
      when 'at_risk' then 1
      when 'lead' then 2
      when 'active' then 3
      when 'paused' then 4
      else 5
    end,
    b.started_at desc;
end;
$$;

create or replace function public.get_coach_client_workspace(target_subscription_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  result jsonb;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  select jsonb_build_object(
    'client', row_to_json(client_row),
    'notes', coalesce((select jsonb_agg(row_to_json(n) order by n.is_pinned desc, n.created_at desc) from public.coach_client_notes n where n.subscription_id = target_subscription_id and n.coach_id = requester), '[]'::jsonb),
    'threads', coalesce((select jsonb_agg(row_to_json(t) order by t.updated_at desc) from public.coach_member_threads t where t.subscription_id = target_subscription_id and t.coach_id = requester), '[]'::jsonb),
    'checkins', coalesce((select jsonb_agg(row_to_json(wc) order by wc.week_start desc) from public.weekly_checkins wc where wc.subscription_id = target_subscription_id and wc.coach_id = requester), '[]'::jsonb),
    'bookings', coalesce((select jsonb_agg(row_to_json(b) order by b.starts_at desc) from public.coach_bookings b where b.subscription_id = target_subscription_id and b.coach_id = requester), '[]'::jsonb),
    'resources', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', ra.id,
        'resource_id', cr.id,
        'title', cr.title,
        'resource_type', cr.resource_type,
        'storage_path', cr.storage_path,
        'external_url', cr.external_url,
        'assigned_at', ra.created_at
      ) order by ra.created_at desc)
      from public.coach_resource_assignments ra
      join public.coach_resources cr on cr.id = ra.resource_id
      where ra.subscription_id = target_subscription_id
        and ra.coach_id = requester
    ), '[]'::jsonb),
    'billing', coalesce((select jsonb_agg(row_to_json(r) order by r.created_at desc) from public.coach_payment_receipts r where r.subscription_id = target_subscription_id and r.coach_id = requester), '[]'::jsonb),
    'visibility', coalesce((select row_to_json(vs) from public.coach_member_visibility_settings vs where vs.subscription_id = target_subscription_id and vs.coach_id = requester), '{}'::jsonb)
  )
  into result
  from (
    select *
    from public.list_coach_client_pipeline(jsonb_build_object('subscription_id', target_subscription_id::text))
    where subscription_id = target_subscription_id
    limit 1
  ) client_row;

  if result is null then
    select jsonb_build_object(
      'client', row_to_json(client_row),
      'notes', '[]'::jsonb,
      'threads', '[]'::jsonb,
      'checkins', '[]'::jsonb,
      'bookings', '[]'::jsonb,
      'resources', '[]'::jsonb,
      'billing', '[]'::jsonb,
      'visibility', '{}'::jsonb
    )
    into result
    from (
      select *
      from public.list_coach_client_pipeline('{}'::jsonb)
      where subscription_id = target_subscription_id
      limit 1
    ) client_row;
  end if;

  return result;
end;
$$;

create or replace function public.upsert_coach_client_record(
  target_subscription_id uuid,
  input_pipeline_stage text default null,
  input_internal_status text default null,
  input_risk_status text default null,
  input_tags text[] default null,
  input_coach_notes text default null,
  input_preferred_language text default null,
  input_follow_up_at timestamptz default null
)
returns public.coach_client_records
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  subscription_record public.subscriptions%rowtype;
  result_record public.coach_client_records%rowtype;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  select *
  into subscription_record
  from public.subscriptions
  where id = target_subscription_id
    and coach_id = requester;

  if subscription_record.id is null then
    raise exception 'Subscription not found for this coach.';
  end if;

  insert into public.coach_client_records (
    subscription_id,
    coach_id,
    member_id,
    pipeline_stage,
    internal_status,
    risk_status,
    tags,
    coach_notes,
    preferred_language,
    follow_up_at,
    archived_at
  )
  values (
    subscription_record.id,
    requester,
    subscription_record.member_id,
    coalesce(input_pipeline_stage, public.derive_coach_pipeline_stage(subscription_record.status, subscription_record.checkout_status)),
    coalesce(input_internal_status, case when subscription_record.status = 'active' then 'active' else 'new' end),
    coalesce(input_risk_status, 'none'),
    coalesce(input_tags, '{}'::text[]),
    coalesce(input_coach_notes, ''),
    input_preferred_language,
    input_follow_up_at,
    case when input_pipeline_stage = 'archived' then timezone('utc', now()) else null end
  )
  on conflict (subscription_id) do update
    set pipeline_stage = coalesce(input_pipeline_stage, coach_client_records.pipeline_stage),
        internal_status = coalesce(input_internal_status, coach_client_records.internal_status),
        risk_status = coalesce(input_risk_status, coach_client_records.risk_status),
        tags = coalesce(input_tags, coach_client_records.tags),
        coach_notes = coalesce(input_coach_notes, coach_client_records.coach_notes),
        preferred_language = coalesce(input_preferred_language, coach_client_records.preferred_language),
        follow_up_at = coalesce(input_follow_up_at, coach_client_records.follow_up_at),
        archived_at = case
          when input_pipeline_stage = 'archived' then timezone('utc', now())
          when input_pipeline_stage is not null and input_pipeline_stage <> 'archived' then null
          else coach_client_records.archived_at
        end
  returning * into result_record;

  return result_record;
end;
$$;

create or replace function public.add_coach_client_note(
  target_subscription_id uuid,
  input_note text,
  input_note_type text default 'general',
  input_is_pinned boolean default false,
  input_metadata jsonb default '{}'::jsonb
)
returns public.coach_client_notes
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  subscription_record public.subscriptions%rowtype;
  note_record public.coach_client_notes%rowtype;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if coalesce(trim(input_note), '') = '' then
    raise exception 'Note cannot be empty.';
  end if;

  select *
  into subscription_record
  from public.subscriptions
  where id = target_subscription_id
    and coach_id = requester;

  if subscription_record.id is null then
    raise exception 'Subscription not found for this coach.';
  end if;

  insert into public.coach_client_notes (
    subscription_id,
    coach_id,
    member_id,
    note,
    note_type,
    is_pinned,
    metadata_json
  )
  values (
    subscription_record.id,
    requester,
    subscription_record.member_id,
    trim(input_note),
    coalesce(input_note_type, 'general'),
    coalesce(input_is_pinned, false),
    coalesce(input_metadata, '{}'::jsonb)
  )
  returning * into note_record;

  return note_record;
end;
$$;

create or replace function public.mark_coach_thread_read(target_thread_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if not exists (
    select 1
    from public.coach_member_threads t
    where t.id = target_thread_id
      and (t.coach_id = requester or t.member_id = requester)
  ) then
    raise exception 'Thread not found.';
  end if;

  insert into public.coach_thread_reads (thread_id, user_id, last_read_at)
  values (target_thread_id, requester, timezone('utc', now()))
  on conflict (thread_id, user_id) do update
    set last_read_at = excluded.last_read_at,
        updated_at = timezone('utc', now());
end;
$$;

create or replace function public.dismiss_coach_action_item(target_event_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.coach_automation_events
  set status = 'dismissed',
      resolved_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  where id = target_event_id
    and coach_id = auth.uid();
$$;

grant execute on function public.derive_coach_pipeline_stage(text, text) to authenticated;
grant execute on function public.coach_workspace_summary() to authenticated;
grant execute on function public.list_coach_action_items() to authenticated;
grant execute on function public.list_coach_client_pipeline(jsonb) to authenticated;
grant execute on function public.get_coach_client_workspace(uuid) to authenticated;
grant execute on function public.upsert_coach_client_record(uuid, text, text, text, text[], text, text, timestamptz) to authenticated;
grant execute on function public.add_coach_client_note(uuid, text, text, boolean, jsonb) to authenticated;
grant execute on function public.mark_coach_thread_read(uuid) to authenticated;
grant execute on function public.dismiss_coach_action_item(uuid) to authenticated;
