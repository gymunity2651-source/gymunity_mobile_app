-- GymUnity coaching outcome system
-- Adds member-facing coaching hub foundations, structured feedback, agenda,
-- package deliverables, and stricter active-subscription delivery rules.

alter table public.coach_packages
  add column if not exists weekly_checkins_included integer not null default 1 check (weekly_checkins_included >= 0),
  add column if not exists feedback_sla_hours integer not null default 24 check (feedback_sla_hours between 1 and 168),
  add column if not exists initial_plan_sla_hours integer not null default 48 check (initial_plan_sla_hours between 1 and 336),
  add column if not exists workout_plan_included boolean not null default true,
  add column if not exists nutrition_guidance_included boolean not null default false,
  add column if not exists habits_included boolean not null default true,
  add column if not exists resources_included boolean not null default true,
  add column if not exists sessions_included boolean not null default false,
  add column if not exists monthly_review_included boolean not null default false,
  add column if not exists session_count_per_month integer not null default 0 check (session_count_per_month >= 0),
  add column if not exists package_summary_for_member text not null default '';

update public.coach_packages
set sessions_included = true
where session_count_per_month > 0
  and sessions_included = false;

create table if not exists public.coach_subscription_kickoffs (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null unique references public.subscriptions(id) on delete cascade,
  coach_id uuid not null references public.coach_profiles(user_id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  primary_goal text not null default '',
  training_level text not null default '',
  preferred_training_days text[] not null default '{}',
  available_equipment text[] not null default '{}',
  injuries_limitations text not null default '',
  schedule_constraints text not null default '',
  nutrition_situation text not null default '',
  sleep_recovery_notes text not null default '',
  biggest_obstacle text not null default '',
  coach_expectations text not null default '',
  member_note text not null default '',
  completed_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_coach_subscription_kickoffs_member
  on public.coach_subscription_kickoffs(member_id, completed_at desc);
create index if not exists idx_coach_subscription_kickoffs_coach
  on public.coach_subscription_kickoffs(coach_id, completed_at desc);

alter table public.coach_subscription_kickoffs enable row level security;

drop policy if exists coach_subscription_kickoffs_read_participants on public.coach_subscription_kickoffs;
create policy coach_subscription_kickoffs_read_participants
on public.coach_subscription_kickoffs for select
to authenticated
using (member_id = auth.uid() or coach_id = auth.uid());

drop policy if exists coach_subscription_kickoffs_member_manage on public.coach_subscription_kickoffs;
create policy coach_subscription_kickoffs_member_manage
on public.coach_subscription_kickoffs for all
to authenticated
using (member_id = auth.uid())
with check (member_id = auth.uid());

alter table public.weekly_checkins
  add column if not exists workouts_completed integer check (workouts_completed is null or workouts_completed >= 0),
  add column if not exists missed_workouts integer check (missed_workouts is null or missed_workouts >= 0),
  add column if not exists missed_workouts_reason text,
  add column if not exists soreness_score integer check (soreness_score is null or soreness_score between 1 and 10),
  add column if not exists fatigue_score integer check (fatigue_score is null or fatigue_score between 1 and 10),
  add column if not exists pain_warning text,
  add column if not exists nutrition_adherence_score integer check (nutrition_adherence_score is null or nutrition_adherence_score between 0 and 100),
  add column if not exists habit_adherence_score integer check (habit_adherence_score is null or habit_adherence_score between 0 and 100),
  add column if not exists biggest_obstacle text,
  add column if not exists support_needed text,
  add column if not exists checkin_metadata_json jsonb not null default '{}'::jsonb,
  add column if not exists coach_feedback_json jsonb not null default '{}'::jsonb,
  add column if not exists coach_feedback_at timestamptz,
  add column if not exists next_checkin_date date;

alter table public.coach_resource_assignments
  add column if not exists viewed_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists member_note text;

create or replace function public.derive_coaching_relationship_stage(target_subscription_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  subscription_record public.subscriptions%rowtype;
  latest_checkin public.weekly_checkins%rowtype;
  latest_plan_at timestamptz;
  pending_feedback_count integer := 0;
begin
  select * into subscription_record
  from public.subscriptions
  where id = target_subscription_id;

  if subscription_record.id is null then
    return 'not_found';
  end if;

  if subscription_record.status in ('checkout_pending', 'pending_payment', 'pending_activation') then
    return 'checkout_pending';
  end if;

  if subscription_record.status = 'paused' then
    return 'paused_readonly';
  end if;

  if subscription_record.status in ('cancelled', 'expired') then
    return 'completed';
  end if;

  if subscription_record.status <> 'active' then
    return subscription_record.status;
  end if;

  if not exists (
    select 1 from public.coach_subscription_kickoffs k
    where k.subscription_id = subscription_record.id
  ) then
    return 'awaiting_kickoff';
  end if;

  select max(wp.assigned_at) into latest_plan_at
  from public.workout_plans wp
  where wp.member_id = subscription_record.member_id
    and wp.coach_id = subscription_record.coach_id
    and wp.status = 'active';

  if latest_plan_at is null then
    return 'awaiting_coach_plan';
  end if;

  select * into latest_checkin
  from public.weekly_checkins wc
  where wc.subscription_id = subscription_record.id
  order by wc.week_start desc, wc.created_at desc
  limit 1;

  select count(*) into pending_feedback_count
  from public.weekly_checkins wc
  where wc.subscription_id = subscription_record.id
    and coalesce(wc.coach_reply, '') = ''
    and wc.coach_feedback_json = '{}'::jsonb;

  if pending_feedback_count > 0 then
    if exists (
      select 1
      from public.weekly_checkins wc
      left join public.coach_packages pkg on pkg.id = subscription_record.package_id
      where wc.subscription_id = subscription_record.id
        and coalesce(wc.coach_reply, '') = ''
        and wc.coach_feedback_json = '{}'::jsonb
        and wc.created_at < timezone('utc', now()) - make_interval(hours => coalesce(pkg.feedback_sla_hours, 24))
    ) then
      return 'feedback_overdue';
    end if;
    return 'awaiting_coach_feedback';
  end if;

  if latest_checkin.id is null
     or latest_checkin.week_start < (current_date - ((extract(dow from current_date)::integer + 6) % 7))::date then
    return 'checkin_due';
  end if;

  if exists (
    select 1 from public.weekly_checkins wc
    where wc.subscription_id = subscription_record.id
      and (
        coalesce(wc.adherence_score, 100) < 50
        or coalesce(wc.pain_warning, '') <> ''
      )
      and wc.created_at > timezone('utc', now()) - interval '14 days'
  ) then
    return 'at_risk';
  end if;

  return 'in_weekly_coaching';
end;
$$;

grant execute on function public.derive_coaching_relationship_stage(uuid) to authenticated;

create or replace function public.submit_coach_kickoff(
  target_subscription_id uuid,
  input_primary_goal text default '',
  input_training_level text default '',
  input_preferred_training_days text[] default '{}',
  input_available_equipment text[] default '{}',
  input_injuries_limitations text default '',
  input_schedule_constraints text default '',
  input_nutrition_situation text default '',
  input_sleep_recovery_notes text default '',
  input_biggest_obstacle text default '',
  input_coach_expectations text default '',
  input_member_note text default '',
  input_share_progress_summary boolean default false,
  input_share_nutrition_summary boolean default false,
  input_share_ai_summary boolean default false,
  input_share_workout_adherence boolean default false,
  input_share_product_context boolean default false
)
returns public.coach_subscription_kickoffs
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  subscription_record public.subscriptions%rowtype;
  kickoff_record public.coach_subscription_kickoffs%rowtype;
begin
  if requester is null or public.current_role() <> 'member' then
    raise exception 'Only members can complete coach kickoff.';
  end if;

  select * into subscription_record
  from public.subscriptions
  where id = target_subscription_id
    and member_id = requester
    and status = 'active';

  if subscription_record.id is null then
    raise exception 'Kickoff requires an active coaching subscription.';
  end if;

  insert into public.coach_subscription_kickoffs (
    subscription_id,
    coach_id,
    member_id,
    primary_goal,
    training_level,
    preferred_training_days,
    available_equipment,
    injuries_limitations,
    schedule_constraints,
    nutrition_situation,
    sleep_recovery_notes,
    biggest_obstacle,
    coach_expectations,
    member_note,
    completed_at
  )
  values (
    subscription_record.id,
    subscription_record.coach_id,
    requester,
    trim(coalesce(input_primary_goal, '')),
    trim(coalesce(input_training_level, '')),
    coalesce(input_preferred_training_days, '{}'),
    coalesce(input_available_equipment, '{}'),
    trim(coalesce(input_injuries_limitations, '')),
    trim(coalesce(input_schedule_constraints, '')),
    trim(coalesce(input_nutrition_situation, '')),
    trim(coalesce(input_sleep_recovery_notes, '')),
    trim(coalesce(input_biggest_obstacle, '')),
    trim(coalesce(input_coach_expectations, '')),
    trim(coalesce(input_member_note, '')),
    timezone('utc', now())
  )
  on conflict (subscription_id) do update
    set primary_goal = excluded.primary_goal,
        training_level = excluded.training_level,
        preferred_training_days = excluded.preferred_training_days,
        available_equipment = excluded.available_equipment,
        injuries_limitations = excluded.injuries_limitations,
        schedule_constraints = excluded.schedule_constraints,
        nutrition_situation = excluded.nutrition_situation,
        sleep_recovery_notes = excluded.sleep_recovery_notes,
        biggest_obstacle = excluded.biggest_obstacle,
        coach_expectations = excluded.coach_expectations,
        member_note = excluded.member_note,
        completed_at = timezone('utc', now()),
        updated_at = timezone('utc', now())
  returning * into kickoff_record;

  perform public.upsert_coach_member_visibility(
    subscription_record.id,
    subscription_record.coach_id,
    coalesce(input_share_ai_summary, false),
    coalesce(input_share_workout_adherence, false),
    coalesce(input_share_progress_summary, false),
    coalesce(input_share_nutrition_summary, false),
    coalesce(input_share_product_context, false),
    coalesce(input_share_product_context, false)
  );

  insert into public.notifications (user_id, type, title, body, data)
  values (
    subscription_record.coach_id,
    'coaching',
    'Kickoff completed',
    'A new coaching client completed their kickoff intake.',
    jsonb_build_object('subscription_id', subscription_record.id, 'member_id', requester)
  );

  return kickoff_record;
end;
$$;

grant execute on function public.submit_coach_kickoff(
  uuid, text, text, text[], text[], text, text, text, text, text, text, text,
  boolean, boolean, boolean, boolean, boolean
) to authenticated;

create or replace function public.list_member_assigned_habits(
  target_subscription_id uuid default null,
  input_date date default current_date
)
returns table (
  id uuid,
  subscription_id uuid,
  coach_id uuid,
  coach_name text,
  member_id uuid,
  title text,
  habit_type text,
  description text,
  target_value numeric,
  target_unit text,
  frequency text,
  status text,
  start_date date,
  end_date date,
  log_id uuid,
  log_date date,
  completion_status text,
  value numeric,
  note text,
  completed_this_week integer,
  total_this_week integer,
  adherence_percent integer
)
language sql
stable
security definer
set search_path = public
as $$
  with scoped as (
    select a.*
    from public.member_habit_assignments a
    join public.subscriptions s on s.id = a.subscription_id
    where a.member_id = auth.uid()
      and s.member_id = auth.uid()
      and (target_subscription_id is null or a.subscription_id = target_subscription_id)
      and a.status = 'active'
      and a.start_date <= coalesce(input_date, current_date)
      and (a.end_date is null or a.end_date >= coalesce(input_date, current_date))
  ),
  week_logs as (
    select
      l.assignment_id,
      count(*)::integer as total_this_week,
      count(*) filter (where l.completion_status in ('completed', 'partial'))::integer as completed_this_week
    from public.member_habit_logs l
    where l.member_id = auth.uid()
      and l.log_date between (coalesce(input_date, current_date) - ((extract(dow from coalesce(input_date, current_date))::integer + 6) % 7))
                         and (coalesce(input_date, current_date) - ((extract(dow from coalesce(input_date, current_date))::integer + 6) % 7) + 6)
    group by l.assignment_id
  )
  select
    a.id,
    a.subscription_id,
    a.coach_id,
    coalesce(nullif(p.full_name, ''), 'Coach') as coach_name,
    a.member_id,
    a.title,
    a.habit_type,
    a.description,
    a.target_value,
    a.target_unit,
    a.frequency,
    a.status,
    a.start_date,
    a.end_date,
    today_log.id as log_id,
    today_log.log_date,
    today_log.completion_status,
    today_log.value,
    today_log.note,
    coalesce(w.completed_this_week, 0) as completed_this_week,
    coalesce(w.total_this_week, 0) as total_this_week,
    case when coalesce(w.total_this_week, 0) = 0 then 0
      else round((w.completed_this_week::numeric / w.total_this_week::numeric) * 100)::integer
    end as adherence_percent
  from scoped a
  left join public.profiles p on p.user_id = a.coach_id
  left join public.member_habit_logs today_log
    on today_log.assignment_id = a.id
   and today_log.member_id = auth.uid()
   and today_log.log_date = coalesce(input_date, current_date)
  left join week_logs w on w.assignment_id = a.id
  order by a.created_at desc, a.title;
$$;

grant execute on function public.list_member_assigned_habits(uuid, date) to authenticated;

create or replace function public.log_member_assigned_habit(
  target_assignment_id uuid,
  input_log_date date default current_date,
  input_completion_status text default 'completed',
  input_value numeric default null,
  input_note text default null
)
returns public.member_habit_logs
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  assignment_record public.member_habit_assignments%rowtype;
  log_record public.member_habit_logs%rowtype;
begin
  if requester is null or public.current_role() <> 'member' then
    raise exception 'Only members can log assigned habits.';
  end if;

  if input_completion_status not in ('completed', 'partial', 'skipped') then
    raise exception 'Unsupported habit completion status.';
  end if;

  select a.* into assignment_record
  from public.member_habit_assignments a
  join public.subscriptions s on s.id = a.subscription_id
  where a.id = target_assignment_id
    and a.member_id = requester
    and s.member_id = requester
    and s.status = 'active'
    and a.status = 'active';

  if assignment_record.id is null then
    raise exception 'Active assigned habit not found.';
  end if;

  insert into public.member_habit_logs (
    assignment_id,
    member_id,
    log_date,
    completion_status,
    value,
    note
  )
  values (
    assignment_record.id,
    requester,
    coalesce(input_log_date, current_date),
    input_completion_status,
    input_value,
    nullif(trim(coalesce(input_note, '')), '')
  )
  on conflict (assignment_id, log_date) do update
    set completion_status = excluded.completion_status,
        value = excluded.value,
        note = excluded.note,
        updated_at = timezone('utc', now())
  returning * into log_record;

  return log_record;
end;
$$;

grant execute on function public.log_member_assigned_habit(uuid, date, text, numeric, text) to authenticated;

create or replace function public.list_member_assigned_resources(
  target_subscription_id uuid default null
)
returns table (
  id uuid,
  resource_id uuid,
  subscription_id uuid,
  coach_id uuid,
  coach_name text,
  member_id uuid,
  title text,
  description text,
  resource_type text,
  storage_path text,
  external_url text,
  note text,
  assigned_at timestamptz,
  viewed_at timestamptz,
  completed_at timestamptz,
  member_note text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    ra.id,
    cr.id as resource_id,
    ra.subscription_id,
    ra.coach_id,
    coalesce(nullif(p.full_name, ''), 'Coach') as coach_name,
    ra.member_id,
    cr.title,
    cr.description,
    cr.resource_type,
    cr.storage_path,
    cr.external_url,
    ra.note,
    ra.created_at as assigned_at,
    ra.viewed_at,
    ra.completed_at,
    ra.member_note
  from public.coach_resource_assignments ra
  join public.coach_resources cr on cr.id = ra.resource_id
  join public.subscriptions s on s.id = ra.subscription_id
  left join public.profiles p on p.user_id = ra.coach_id
  where ra.member_id = auth.uid()
    and s.member_id = auth.uid()
    and (target_subscription_id is null or ra.subscription_id = target_subscription_id)
  order by coalesce(ra.completed_at, ra.viewed_at, ra.created_at) desc;
$$;

grant execute on function public.list_member_assigned_resources(uuid) to authenticated;

create or replace function public.mark_member_resource_progress(
  target_assignment_id uuid,
  input_mark_viewed boolean default true,
  input_mark_completed boolean default false,
  input_member_note text default null
)
returns public.coach_resource_assignments
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  assignment_record public.coach_resource_assignments%rowtype;
begin
  if requester is null or public.current_role() <> 'member' then
    raise exception 'Only members can update assigned resources.';
  end if;

  update public.coach_resource_assignments ra
  set viewed_at = case when coalesce(input_mark_viewed, true) or coalesce(input_mark_completed, false) then coalesce(ra.viewed_at, timezone('utc', now())) else ra.viewed_at end,
      completed_at = case when coalesce(input_mark_completed, false) then coalesce(ra.completed_at, timezone('utc', now())) else ra.completed_at end,
      member_note = coalesce(nullif(trim(input_member_note), ''), ra.member_note)
  from public.subscriptions s
  where ra.id = target_assignment_id
    and ra.member_id = requester
    and s.id = ra.subscription_id
    and s.member_id = requester
    and s.status = 'active'
  returning ra.* into assignment_record;

  if assignment_record.id is null then
    raise exception 'Active assigned resource not found.';
  end if;

  return assignment_record;
end;
$$;

grant execute on function public.mark_member_resource_progress(uuid, boolean, boolean, text) to authenticated;

create or replace function public.list_member_bookable_session_types(
  target_subscription_id uuid
)
returns table (
  id uuid,
  coach_id uuid,
  title text,
  session_kind text,
  duration_minutes integer,
  delivery_mode text,
  location_note text,
  cancellation_notice_hours integer,
  reschedule_notice_hours integer,
  is_self_bookable boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    st.id,
    st.coach_id,
    st.title,
    st.session_kind,
    st.duration_minutes,
    st.delivery_mode,
    st.location_note,
    st.cancellation_notice_hours,
    st.reschedule_notice_hours,
    st.is_self_bookable
  from public.subscriptions s
  join public.coach_session_types st on st.coach_id = s.coach_id
  where s.id = target_subscription_id
    and s.member_id = auth.uid()
    and s.status = 'active'
    and st.is_active = true
    and st.is_self_bookable = true
  order by st.created_at asc;
$$;

grant execute on function public.list_member_bookable_session_types(uuid) to authenticated;

create or replace function public.list_member_coach_agenda(
  target_subscription_id uuid,
  input_date_from date default current_date,
  input_date_to date default current_date
)
returns table (
  id text,
  type text,
  title text,
  description text,
  status text,
  due_at timestamptz,
  completed_at timestamptz,
  source_table text,
  source_id uuid,
  coach_id uuid,
  member_id uuid,
  subscription_id uuid,
  priority integer,
  metadata jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  with subscription_scope as (
    select s.*
    from public.subscriptions s
    where s.id = target_subscription_id
      and s.member_id = auth.uid()
  ),
  dates as (
    select coalesce(input_date_from, current_date) as date_from,
           coalesce(input_date_to, current_date) as date_to
  ),
  latest_feedback as (
    select wc.*
    from public.weekly_checkins wc
    join subscription_scope s on s.id = wc.subscription_id
    where coalesce(wc.coach_reply, '') <> ''
       or wc.coach_feedback_json <> '{}'::jsonb
    order by coalesce(wc.coach_feedback_at, wc.updated_at, wc.created_at) desc
    limit 1
  )
  select
    'workout_task:' || t.id::text as id,
    'workout_task'::text as type,
    t.title,
    t.instructions as description,
    coalesce(l.completion_status, case when t.scheduled_date < current_date then 'missed' else 'pending' end) as status,
    (t.scheduled_date::text || ' ' || coalesce(t.scheduled_time, t.reminder_time, time '09:00')::text)::timestamp at time zone 'UTC' as due_at,
    l.logged_at as completed_at,
    'workout_plan_tasks'::text as source_table,
    t.id as source_id,
    s.coach_id,
    s.member_id,
    s.id as subscription_id,
    10 as priority,
    jsonb_build_object('task_type', t.task_type, 'target_value', t.target_value, 'target_unit', t.target_unit)
  from subscription_scope s
  join public.workout_plans wp on wp.member_id = s.member_id and wp.coach_id = s.coach_id and wp.status = 'active'
  join public.workout_plan_tasks t on t.workout_plan_id = wp.id
  cross join dates d
  left join public.workout_task_logs l on l.task_id = t.id
  where t.scheduled_date between d.date_from and d.date_to

  union all

  select
    'habit:' || a.id::text,
    'habit',
    a.title,
    a.description,
    coalesce(l.completion_status, 'pending'),
    (coalesce(input_date_from, current_date)::text || ' 20:00:00')::timestamp at time zone 'UTC',
    l.created_at,
    'member_habit_assignments',
    a.id,
    s.coach_id,
    s.member_id,
    s.id,
    20,
    jsonb_build_object('target_value', a.target_value, 'target_unit', a.target_unit, 'frequency', a.frequency)
  from subscription_scope s
  join public.member_habit_assignments a on a.subscription_id = s.id and a.status = 'active'
  cross join dates d
  left join public.member_habit_logs l on l.assignment_id = a.id and l.log_date = d.date_from
  where a.start_date <= d.date_to
    and (a.end_date is null or a.end_date >= d.date_from)

  union all

  select
    'checkin_due:' || s.id::text,
    'checkin_due',
    'Submit weekly check-in',
    'Tell your coach what happened this week so they can adjust your plan.',
    case when exists (
      select 1 from public.weekly_checkins wc
      where wc.subscription_id = s.id
        and wc.week_start = (current_date - ((extract(dow from current_date)::integer + 6) % 7))::date
    ) then 'completed' else 'pending' end,
    ((current_date - ((extract(dow from current_date)::integer + 6) % 7) + 6)::text || ' 20:00:00')::timestamp at time zone 'UTC',
    (select max(wc.created_at) from public.weekly_checkins wc where wc.subscription_id = s.id and wc.week_start = (current_date - ((extract(dow from current_date)::integer + 6) % 7))::date),
    'weekly_checkins',
    s.id,
    s.coach_id,
    s.member_id,
    s.id,
    30,
    jsonb_build_object('week_start', (current_date - ((extract(dow from current_date)::integer + 6) % 7))::date)
  from subscription_scope s
  cross join dates d
  where d.date_from <= current_date + 7
    and d.date_to >= current_date - 7

  union all

  select
    'resource:' || ra.id::text,
    'resource',
    cr.title,
    coalesce(nullif(ra.note, ''), cr.description),
    case when ra.completed_at is not null then 'completed' when ra.viewed_at is not null then 'viewed' else 'pending' end,
    ra.created_at,
    coalesce(ra.completed_at, ra.viewed_at),
    'coach_resource_assignments',
    ra.id,
    s.coach_id,
    s.member_id,
    s.id,
    40,
    jsonb_build_object('resource_type', cr.resource_type, 'resource_id', cr.id)
  from subscription_scope s
  join public.coach_resource_assignments ra on ra.subscription_id = s.id
  join public.coach_resources cr on cr.id = ra.resource_id

  union all

  select
    'booking:' || b.id::text,
    'booking',
    b.title,
    coalesce(b.location_note, b.delivery_mode),
    b.status,
    b.starts_at,
    case when b.status in ('completed', 'cancelled', 'no_show') then b.updated_at else null end,
    'coach_bookings',
    b.id,
    s.coach_id,
    s.member_id,
    s.id,
    15,
    jsonb_build_object('delivery_mode', b.delivery_mode, 'ends_at', b.ends_at)
  from subscription_scope s
  join public.coach_bookings b on b.subscription_id = s.id
  cross join dates d
  where b.starts_at::date between d.date_from and d.date_to

  union all

  select
    'coach_feedback:' || lf.id::text,
    'coach_feedback',
    'Coach feedback ready',
    coalesce(lf.coach_feedback_json ->> 'one_priority', lf.coach_reply, 'Review your coach feedback.'),
    'ready',
    coalesce(lf.coach_feedback_at, lf.updated_at, lf.created_at),
    coalesce(lf.coach_feedback_at, lf.updated_at, lf.created_at),
    'weekly_checkins',
    lf.id,
    s.coach_id,
    s.member_id,
    s.id,
    5,
    lf.coach_feedback_json
  from subscription_scope s
  join latest_feedback lf on lf.subscription_id = s.id
  order by priority, due_at nulls last, title;
$$;

grant execute on function public.list_member_coach_agenda(uuid, date, date) to authenticated;

create or replace function public.get_member_coach_hub(target_subscription_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  subscription_record public.subscriptions%rowtype;
  result jsonb;
  current_week_start date := (current_date - ((extract(dow from current_date)::integer + 6) % 7))::date;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  select * into subscription_record
  from public.subscriptions s
  where s.member_id = requester
    and (target_subscription_id is null or s.id = target_subscription_id)
  order by
    case when s.status = 'active' then 0 else 1 end,
    s.created_at desc
  limit 1;

  if subscription_record.id is null then
    return jsonb_build_object('subscription', null, 'relationship_stage', 'none');
  end if;

  select jsonb_build_object(
    'subscription', (
      select to_jsonb(row_data)
      from (
        select
          s.id,
          s.member_id,
          s.coach_id,
          coalesce(nullif(p.full_name, ''), 'Coach') as coach_name,
          p.avatar_path as coach_avatar_path,
          s.package_id,
          coalesce(pkg.title, s.plan_name, 'Coaching') as package_title,
          s.plan_name,
          s.status,
          s.checkout_status,
          s.billing_cycle,
          s.amount,
          s.currency,
          s.activated_at,
          s.next_renewal_at,
          thread.id as thread_id,
          coalesce(pkg.feedback_sla_hours, cp.response_sla_hours, 24) as feedback_sla_hours,
          coalesce(pkg.initial_plan_sla_hours, 48) as initial_plan_sla_hours,
          coalesce(pkg.weekly_checkins_included, 1) as weekly_checkins_included,
          coalesce(pkg.session_count_per_month, 0) as session_count_per_month,
          coalesce(nullif(pkg.package_summary_for_member, ''), pkg.support_summary, pkg.description, '') as package_summary_for_member
        from public.subscriptions s
        left join public.profiles p on p.user_id = s.coach_id
        left join public.coach_profiles cp on cp.user_id = s.coach_id
        left join public.coach_packages pkg on pkg.id = s.package_id
        left join public.coach_member_threads thread on thread.subscription_id = s.id
        where s.id = subscription_record.id
      ) row_data
    ),
    'relationship_stage', public.derive_coaching_relationship_stage(subscription_record.id),
    'kickoff', coalesce((select to_jsonb(k) from public.coach_subscription_kickoffs k where k.subscription_id = subscription_record.id), '{}'::jsonb),
    'today_agenda', coalesce((
      select jsonb_agg(to_jsonb(a) order by a.priority, a.due_at nulls last)
      from public.list_member_coach_agenda(subscription_record.id, current_date, current_date) a
    ), '[]'::jsonb),
    'week_agenda', coalesce((
      select jsonb_agg(to_jsonb(a) order by a.priority, a.due_at nulls last)
      from public.list_member_coach_agenda(subscription_record.id, current_week_start, current_week_start + 6) a
    ), '[]'::jsonb),
    'progress_snapshot', jsonb_build_object(
      'workouts_completed_this_week', coalesce((
        select count(*)
        from public.workout_task_logs l
        join public.workout_plan_tasks t on t.id = l.task_id
        where l.member_id = requester
          and t.scheduled_date between current_week_start and current_week_start + 6
          and l.completion_status = 'completed'
      ), 0),
      'habits_completed_this_week', coalesce((
        select count(*)
        from public.member_habit_logs l
        join public.member_habit_assignments a on a.id = l.assignment_id
        where a.subscription_id = subscription_record.id
          and l.member_id = requester
          and l.log_date between current_week_start and current_week_start + 6
          and l.completion_status in ('completed', 'partial')
      ), 0),
      'checkin_status', case when exists (
        select 1 from public.weekly_checkins wc
        where wc.subscription_id = subscription_record.id
          and wc.week_start = current_week_start
      ) then 'submitted' else 'due' end
    ),
    'latest_feedback', coalesce((
      select jsonb_build_object(
        'checkin_id', wc.id,
        'week_start', wc.week_start,
        'coach_reply', wc.coach_reply,
        'feedback', wc.coach_feedback_json,
        'feedback_at', coalesce(wc.coach_feedback_at, wc.updated_at, wc.created_at),
        'next_checkin_date', wc.next_checkin_date
      )
      from public.weekly_checkins wc
      where wc.subscription_id = subscription_record.id
        and (coalesce(wc.coach_reply, '') <> '' or wc.coach_feedback_json <> '{}'::jsonb)
      order by coalesce(wc.coach_feedback_at, wc.updated_at, wc.created_at) desc
      limit 1
    ), '{}'::jsonb),
    'habits', coalesce((
      select jsonb_agg(to_jsonb(h) order by h.title)
      from public.list_member_assigned_habits(subscription_record.id, current_date) h
    ), '[]'::jsonb),
    'resources', coalesce((
      select jsonb_agg(to_jsonb(r) order by r.assigned_at desc)
      from public.list_member_assigned_resources(subscription_record.id) r
    ), '[]'::jsonb),
    'bookings', coalesce((
      select jsonb_agg(row_to_json(b) order by b.starts_at asc)
      from public.coach_bookings b
      where b.subscription_id = subscription_record.id
        and b.member_id = requester
        and b.starts_at >= timezone('utc', now()) - interval '1 day'
    ), '[]'::jsonb)
  )
  into result
  from public.subscriptions s
  where s.id = subscription_record.id;

  return result;
end;
$$;

grant execute on function public.get_member_coach_hub(uuid) to authenticated;

create or replace function public.submit_weekly_checkin(
  target_subscription_id uuid,
  input_week_start date,
  input_weight_kg numeric default null,
  input_waist_cm numeric default null,
  input_adherence_score integer default 0,
  input_energy_score integer default null,
  input_sleep_score integer default null,
  input_wins text default null,
  input_blockers text default null,
  input_questions text default null,
  input_photo_paths jsonb default '[]'::jsonb,
  input_workouts_completed integer default null,
  input_missed_workouts integer default null,
  input_missed_workouts_reason text default null,
  input_soreness_score integer default null,
  input_fatigue_score integer default null,
  input_pain_warning text default null,
  input_nutrition_adherence_score integer default null,
  input_habit_adherence_score integer default null,
  input_biggest_obstacle text default null,
  input_support_needed text default null,
  input_metadata_json jsonb default '{}'::jsonb
)
returns public.weekly_checkins
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  subscription_record public.subscriptions%rowtype;
  thread_record public.coach_member_threads%rowtype;
  saved_checkin public.weekly_checkins%rowtype;
  photo_item jsonb;
begin
  if requester is null or public.current_role() <> 'member' then
    raise exception 'Only members can submit weekly check-ins.';
  end if;

  select * into subscription_record
  from public.subscriptions
  where id = target_subscription_id
    and member_id = requester
    and status = 'active';

  if subscription_record.id is null then
    raise exception 'Weekly check-ins are only available for active subscriptions.';
  end if;

  select * into thread_record
  from public.ensure_coach_member_thread(subscription_record.id);

  insert into public.weekly_checkins (
    subscription_id, thread_id, member_id, coach_id, week_start,
    weight_kg, waist_cm, adherence_score, energy_score, sleep_score,
    wins, blockers, questions, workouts_completed, missed_workouts,
    missed_workouts_reason, soreness_score, fatigue_score, pain_warning,
    nutrition_adherence_score, habit_adherence_score, biggest_obstacle,
    support_needed, checkin_metadata_json
  )
  values (
    subscription_record.id, thread_record.id, requester, subscription_record.coach_id,
    coalesce(input_week_start, current_date), input_weight_kg, input_waist_cm,
    coalesce(input_adherence_score, 0), input_energy_score, input_sleep_score,
    nullif(trim(coalesce(input_wins, '')), ''),
    nullif(trim(coalesce(input_blockers, '')), ''),
    nullif(trim(coalesce(input_questions, '')), ''),
    input_workouts_completed, input_missed_workouts,
    nullif(trim(coalesce(input_missed_workouts_reason, '')), ''),
    input_soreness_score, input_fatigue_score,
    nullif(trim(coalesce(input_pain_warning, '')), ''),
    input_nutrition_adherence_score, input_habit_adherence_score,
    nullif(trim(coalesce(input_biggest_obstacle, '')), ''),
    nullif(trim(coalesce(input_support_needed, '')), ''),
    coalesce(input_metadata_json, '{}'::jsonb)
  )
  on conflict (subscription_id, week_start) do update
    set weight_kg = excluded.weight_kg,
        waist_cm = excluded.waist_cm,
        adherence_score = excluded.adherence_score,
        energy_score = excluded.energy_score,
        sleep_score = excluded.sleep_score,
        wins = excluded.wins,
        blockers = excluded.blockers,
        questions = excluded.questions,
        workouts_completed = excluded.workouts_completed,
        missed_workouts = excluded.missed_workouts,
        missed_workouts_reason = excluded.missed_workouts_reason,
        soreness_score = excluded.soreness_score,
        fatigue_score = excluded.fatigue_score,
        pain_warning = excluded.pain_warning,
        nutrition_adherence_score = excluded.nutrition_adherence_score,
        habit_adherence_score = excluded.habit_adherence_score,
        biggest_obstacle = excluded.biggest_obstacle,
        support_needed = excluded.support_needed,
        checkin_metadata_json = excluded.checkin_metadata_json,
        updated_at = timezone('utc', now())
  returning * into saved_checkin;

  delete from public.progress_photos where checkin_id = saved_checkin.id;
  for photo_item in select value from jsonb_array_elements(coalesce(input_photo_paths, '[]'::jsonb))
  loop
    if coalesce(photo_item ->> 'storage_path', '') <> '' then
      insert into public.progress_photos (checkin_id, member_id, storage_path, angle)
      values (saved_checkin.id, requester, photo_item ->> 'storage_path', coalesce(nullif(photo_item ->> 'angle', ''), 'other'));
    end if;
  end loop;

  insert into public.coach_automation_events (
    coach_id, member_id, subscription_id, event_type, severity, title, body, cta_label, due_at, metadata_json
  )
  values (
    subscription_record.coach_id,
    requester,
    subscription_record.id,
    case when coalesce(saved_checkin.pain_warning, '') <> '' then 'low_adherence' else 'no_recent_checkin' end,
    case when coalesce(saved_checkin.pain_warning, '') <> '' then 'high' else 'medium' end,
    case when coalesce(saved_checkin.pain_warning, '') <> '' then 'Pain or injury reported' else 'Check-in submitted' end,
    'A member submitted a weekly check-in and is waiting for feedback.',
    'Send feedback',
    timezone('utc', now()) + interval '24 hours',
    jsonb_build_object('checkin_id', saved_checkin.id)
  );

  insert into public.notifications (user_id, type, title, body, data)
  values (
    subscription_record.coach_id,
    'coaching',
    'Check-in submitted',
    'A member submitted a weekly check-in and is waiting for feedback.',
    jsonb_build_object('subscription_id', subscription_record.id, 'checkin_id', saved_checkin.id, 'thread_id', thread_record.id)
  );

  return saved_checkin;
end;
$$;

grant execute on function public.submit_weekly_checkin(
  uuid, date, numeric, numeric, integer, integer, integer, text, text, text, jsonb,
  integer, integer, text, integer, integer, text, integer, integer, text, text, jsonb
) to authenticated;

create or replace function public.submit_coach_checkin_feedback(
  target_checkin_id uuid,
  target_thread_id uuid,
  input_feedback text default '',
  input_what_went_well text default '',
  input_what_needs_attention text default '',
  input_adjustment_for_next_week text default '',
  input_one_priority text default '',
  input_coach_note text default '',
  input_plan_changes_summary text default '',
  input_next_checkin_date date default null
)
returns public.weekly_checkins
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  checkin_record public.weekly_checkins%rowtype;
  thread_record public.coach_member_threads%rowtype;
  cleaned_feedback text := trim(coalesce(input_feedback, ''));
  feedback_json jsonb;
begin
  if requester is null or public.current_role() <> 'coach' then
    raise exception 'Only coaches can submit check-in feedback.';
  end if;

  feedback_json := jsonb_build_object(
    'what_went_well', trim(coalesce(input_what_went_well, '')),
    'what_needs_attention', trim(coalesce(input_what_needs_attention, '')),
    'adjustment_for_next_week', trim(coalesce(input_adjustment_for_next_week, '')),
    'one_priority', trim(coalesce(input_one_priority, '')),
    'coach_note', trim(coalesce(input_coach_note, '')),
    'plan_changes_summary', trim(coalesce(input_plan_changes_summary, ''))
  );

  if cleaned_feedback = '' then
    cleaned_feedback := coalesce(nullif(trim(coalesce(input_one_priority, '')), ''), nullif(trim(coalesce(input_adjustment_for_next_week, '')), ''), nullif(trim(coalesce(input_coach_note, '')), ''));
  end if;

  if cleaned_feedback is null or cleaned_feedback = '' then
    raise exception 'Feedback cannot be empty.';
  end if;

  select * into checkin_record
  from public.weekly_checkins
  where id = target_checkin_id
    and coach_id = requester;

  if checkin_record.id is null then
    raise exception 'Check-in not found for this coach.';
  end if;

  if not exists (
    select 1 from public.subscriptions s
    where s.id = checkin_record.subscription_id
      and s.coach_id = requester
      and s.status = 'active'
  ) then
    raise exception 'Check-in feedback is only available for active subscriptions.';
  end if;

  select * into thread_record
  from public.coach_member_threads
  where id = target_thread_id
    and subscription_id = checkin_record.subscription_id
    and coach_id = requester;

  if thread_record.id is null then
    select * into thread_record
    from public.ensure_coach_member_thread(checkin_record.subscription_id);
  end if;

  update public.weekly_checkins
  set coach_reply = cleaned_feedback,
      coach_feedback_json = feedback_json,
      coach_feedback_at = timezone('utc', now()),
      next_checkin_date = input_next_checkin_date,
      updated_at = timezone('utc', now())
  where id = checkin_record.id
  returning * into checkin_record;

  insert into public.coach_messages (thread_id, sender_user_id, sender_role, message_type, content)
  values (thread_record.id, requester, 'coach', 'checkin_feedback', cleaned_feedback);

  update public.coach_member_threads
  set last_message_preview = left(cleaned_feedback, 160),
      last_message_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  where id = thread_record.id;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    checkin_record.member_id,
    'coaching',
    'Coach feedback ready',
    'Your coach replied to your weekly check-in.',
    jsonb_build_object('subscription_id', checkin_record.subscription_id, 'checkin_id', checkin_record.id, 'thread_id', thread_record.id)
  );

  return checkin_record;
end;
$$;

grant execute on function public.submit_coach_checkin_feedback(uuid, uuid, text, text, text, text, text, text, text, date) to authenticated;

create or replace function public.create_coach_booking(
  target_subscription_id uuid,
  target_session_type_id uuid,
  input_starts_at timestamptz,
  input_timezone text default 'UTC',
  input_note text default null
)
returns public.coach_bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  subscription_record public.subscriptions%rowtype;
  session_type_record public.coach_session_types%rowtype;
  booking_record public.coach_bookings%rowtype;
  computed_ends_at timestamptz;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  select * into subscription_record
  from public.subscriptions
  where id = target_subscription_id
    and (member_id = requester or coach_id = requester)
    and status = 'active';

  if subscription_record.id is null then
    raise exception 'Booking requires an active coaching subscription.';
  end if;

  select * into session_type_record
  from public.coach_session_types
  where id = target_session_type_id
    and coach_id = subscription_record.coach_id
    and is_active = true;

  if session_type_record.id is null then
    raise exception 'Session type not found.';
  end if;

  if requester = subscription_record.member_id and session_type_record.is_self_bookable = false then
    raise exception 'This session type is not self-bookable.';
  end if;

  computed_ends_at := input_starts_at + make_interval(mins => session_type_record.duration_minutes);

  if exists (
    select 1
    from public.coach_bookings b
    where b.coach_id = subscription_record.coach_id
      and b.status in ('scheduled', 'confirmed')
      and tstzrange(b.starts_at, b.ends_at, '[)') &&
          tstzrange(
            input_starts_at - make_interval(mins => session_type_record.buffer_before_minutes),
            computed_ends_at + make_interval(mins => session_type_record.buffer_after_minutes),
            '[)'
          )
  ) then
    raise exception 'This time is no longer available.';
  end if;

  insert into public.coach_bookings (
    coach_id, member_id, subscription_id, session_type_id, title, starts_at,
    ends_at, timezone, status, delivery_mode, location_note, created_by,
    metadata_json
  )
  values (
    subscription_record.coach_id,
    subscription_record.member_id,
    subscription_record.id,
    session_type_record.id,
    session_type_record.title,
    input_starts_at,
    computed_ends_at,
    coalesce(input_timezone, 'UTC'),
    'scheduled',
    session_type_record.delivery_mode,
    session_type_record.location_note,
    requester,
    jsonb_build_object('note', input_note)
  )
  returning * into booking_record;

  insert into public.notifications (user_id, type, title, body, data)
  values
    (subscription_record.coach_id, 'coaching', 'Session booked', 'A coaching session was booked.', jsonb_build_object('booking_id', booking_record.id, 'subscription_id', subscription_record.id)),
    (subscription_record.member_id, 'coaching', 'Session booked', 'Your coaching session is scheduled.', jsonb_build_object('booking_id', booking_record.id, 'subscription_id', subscription_record.id));

  return booking_record;
end;
$$;

grant execute on function public.create_coach_booking(uuid, uuid, timestamptz, text, text) to authenticated;

create or replace function public.update_coach_booking_status(
  target_booking_id uuid,
  input_status text,
  input_reason text default null
)
returns public.coach_bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  booking_record public.coach_bookings%rowtype;
  requester_role text := public.current_role();
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  select * into booking_record
  from public.coach_bookings
  where id = target_booking_id
    and (coach_id = requester or member_id = requester);

  if booking_record.id is null then
    raise exception 'Booking not found.';
  end if;

  if requester_role = 'member' and input_status not in ('cancelled', 'rescheduled') then
    raise exception 'Members can only cancel or reschedule their own sessions.';
  end if;

  if requester_role = 'coach' and input_status not in ('scheduled', 'confirmed', 'completed', 'cancelled', 'rescheduled', 'no_show') then
    raise exception 'Unsupported booking status.';
  end if;

  update public.coach_bookings
  set status = input_status,
      cancellation_reason = case when input_status = 'cancelled' then input_reason else cancellation_reason end,
      updated_at = timezone('utc', now())
  where id = target_booking_id
  returning * into booking_record;

  insert into public.notifications (user_id, type, title, body, data)
  values
    (booking_record.coach_id, 'coaching', 'Session updated', 'A coaching session status changed.', jsonb_build_object('booking_id', booking_record.id, 'status', booking_record.status)),
    (booking_record.member_id, 'coaching', 'Session updated', 'Your coaching session status changed.', jsonb_build_object('booking_id', booking_record.id, 'status', booking_record.status));

  return booking_record;
end;
$$;

grant execute on function public.update_coach_booking_status(uuid, text, text) to authenticated;

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
      'awaiting_kickoff_review'::text as event_type,
      'medium'::text as severity,
      'open'::text as status,
      'Kickoff submitted'::text as title,
      coalesce(nullif(p.full_name, ''), 'Member') || ' completed kickoff and needs the first coaching plan.' as body,
      'Open client'::text as cta_label,
      s.member_id,
      coalesce(nullif(p.full_name, ''), 'Member') as member_name,
      s.id as subscription_id,
      coalesce(k.completed_at, k.created_at) as due_at,
      jsonb_build_object('source', 'generated', 'relationship_stage', public.derive_coaching_relationship_stage(s.id)) as metadata_json,
      coalesce(k.completed_at, k.created_at) as created_at
    from public.subscriptions s
    join public.profiles p on p.user_id = s.member_id
    join public.coach_subscription_kickoffs k on k.subscription_id = s.id
    where s.coach_id = auth.uid()
      and s.status = 'active'
      and not exists (
        select 1
        from public.workout_plans wp
        where wp.member_id = s.member_id
          and wp.coach_id = s.coach_id
          and wp.status in ('active', 'published')
      )

    union all

    select
      gen_random_uuid(),
      'awaiting_initial_plan',
      'high',
      'open',
      'Initial plan due',
      coalesce(nullif(p.full_name, ''), 'Member') || ' is active but does not have an active coach plan yet.',
      'Create plan',
      s.member_id,
      coalesce(nullif(p.full_name, ''), 'Member'),
      s.id,
      coalesce(s.activated_at, s.created_at) + make_interval(hours => coalesce(cp.initial_plan_sla_hours, 48)),
      jsonb_build_object('source', 'generated', 'sla_hours', coalesce(cp.initial_plan_sla_hours, 48)),
      coalesce(s.activated_at, s.created_at)
    from public.subscriptions s
    join public.profiles p on p.user_id = s.member_id
    left join public.coach_packages cp on cp.id = s.package_id
    where s.coach_id = auth.uid()
      and s.status = 'active'
      and coalesce(s.activated_at, s.created_at) + make_interval(hours => coalesce(cp.initial_plan_sla_hours, 48)) <= now()
      and not exists (
        select 1
        from public.workout_plans wp
        where wp.member_id = s.member_id
          and wp.coach_id = s.coach_id
          and wp.status in ('active', 'published')
      )

    union all

    select
      gen_random_uuid(),
      case
        when wc.created_at + make_interval(hours => coalesce(cp.feedback_sla_hours, 24)) <= now()
          then 'feedback_overdue'
        else 'checkin_submitted'
      end,
      case
        when wc.created_at + make_interval(hours => coalesce(cp.feedback_sla_hours, 24)) <= now()
          then 'high'
        else 'medium'
      end,
      'open',
      case
        when wc.created_at + make_interval(hours => coalesce(cp.feedback_sla_hours, 24)) <= now()
          then 'Feedback overdue'
        else 'Check-in submitted'
      end,
      coalesce(nullif(p.full_name, ''), 'Member') || ' is waiting for structured coach feedback.',
      'Send feedback',
      s.member_id,
      coalesce(nullif(p.full_name, ''), 'Member'),
      s.id,
      wc.created_at + make_interval(hours => coalesce(cp.feedback_sla_hours, 24)),
      jsonb_build_object('source', 'generated', 'checkin_id', wc.id, 'sla_hours', coalesce(cp.feedback_sla_hours, 24)),
      wc.created_at
    from public.weekly_checkins wc
    join public.subscriptions s on s.id = wc.subscription_id
    join public.profiles p on p.user_id = s.member_id
    left join public.coach_packages cp on cp.id = s.package_id
    where s.coach_id = auth.uid()
      and s.status = 'active'
      and wc.coach_reply is null

    union all

    select
      gen_random_uuid(),
      'member_at_risk',
      'high',
      'open',
      'Risk signal reported',
      coalesce(nullif(p.full_name, ''), 'Member') || ' reported pain, injury, or low adherence.',
      'Review check-in',
      s.member_id,
      coalesce(nullif(p.full_name, ''), 'Member'),
      s.id,
      wc.created_at,
      jsonb_build_object(
        'source', 'generated',
        'checkin_id', wc.id,
        'pain_warning', wc.pain_warning,
        'adherence_score', wc.adherence_score
      ),
      wc.created_at
    from public.weekly_checkins wc
    join public.subscriptions s on s.id = wc.subscription_id
    join public.profiles p on p.user_id = s.member_id
    where s.coach_id = auth.uid()
      and s.status = 'active'
      and (
        nullif(wc.pain_warning, '') is not null
        or coalesce(wc.adherence_score, 100) < 50
        or coalesce(wc.missed_workouts, 0) >= 3
      )

    union all

    select
      gen_random_uuid(),
      'upcoming_session',
      'low',
      'open',
      'Upcoming session',
      coalesce(nullif(p.full_name, ''), 'Member') || ' has a coaching session soon.',
      'Open session',
      s.member_id,
      coalesce(nullif(p.full_name, ''), 'Member'),
      s.id,
      b.starts_at,
      jsonb_build_object('source', 'generated', 'booking_id', b.id),
      b.created_at
    from public.coach_bookings b
    join public.subscriptions s on s.id = b.subscription_id
    join public.profiles p on p.user_id = s.member_id
    where s.coach_id = auth.uid()
      and s.status = 'active'
      and b.status in ('scheduled', 'confirmed')
      and b.starts_at between now() and now() + interval '24 hours'
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

grant execute on function public.list_coach_action_items() to authenticated;
