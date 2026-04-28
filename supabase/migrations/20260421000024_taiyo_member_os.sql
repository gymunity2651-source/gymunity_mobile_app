-- TAIYO Member OS foundations
-- Date: 2026-04-21

alter table public.workout_sessions
  add column if not exists readiness_score integer check (
    readiness_score is null or (readiness_score >= 0 and readiness_score <= 100)
  ),
  add column if not exists difficulty_score integer check (
    difficulty_score is null or (difficulty_score between 1 and 10)
  ),
  add column if not exists pace_delta_percent numeric(6,2),
  add column if not exists was_shortened boolean not null default false,
  add column if not exists was_swapped boolean not null default false,
  add column if not exists completion_rate numeric(5,2) check (
    completion_rate is null or (completion_rate >= 0 and completion_rate <= 100)
  ),
  add column if not exists summary_json jsonb not null default '{}'::jsonb;

alter table public.workout_task_logs
  add column if not exists difficulty_score integer check (
    difficulty_score is null or (difficulty_score between 1 and 10)
  ),
  add column if not exists pain_score integer check (
    pain_score is null or (pain_score between 0 and 10)
  ),
  add column if not exists was_substituted boolean not null default false,
  add column if not exists swap_reason text,
  add column if not exists actual_exercise_title text;

alter table public.workout_plans
  add column if not exists adaptation_mode text not null default 'semi_auto' check (
    adaptation_mode in ('manual', 'semi_auto', 'coach_locked')
  ),
  add column if not exists last_adapted_at timestamptz,
  add column if not exists last_ai_brief_at timestamptz;

create table if not exists public.member_daily_readiness_logs (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  log_date date not null default current_date,
  energy_level integer check (energy_level is null or energy_level between 1 and 5),
  soreness_level integer check (soreness_level is null or soreness_level between 1 and 5),
  stress_level integer check (stress_level is null or stress_level between 1 and 5),
  available_minutes integer check (available_minutes is null or available_minutes between 5 and 240),
  location_mode text check (
    location_mode is null or location_mode in ('gym', 'home', 'outdoor', 'travel', 'mixed')
  ),
  equipment_override text[] not null default '{}',
  readiness_score integer not null default 50 check (readiness_score between 0 and 100),
  intensity_band text not null default 'yellow' check (
    intensity_band in ('green', 'yellow', 'red')
  ),
  note text,
  source text not null default 'member',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (member_id, log_date)
);

create table if not exists public.member_ai_daily_briefs (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  brief_date date not null default current_date,
  plan_id uuid references public.workout_plans(id) on delete set null,
  day_id uuid references public.workout_plan_days(id) on delete set null,
  primary_task_id uuid references public.workout_plan_tasks(id) on delete set null,
  readiness_score integer not null default 50 check (readiness_score between 0 and 100),
  intensity_band text not null default 'yellow' check (
    intensity_band in ('green', 'yellow', 'red')
  ),
  coach_mode boolean not null default false,
  recommended_workout_json jsonb not null default '{}'::jsonb,
  habit_focus_json jsonb not null default '{}'::jsonb,
  nutrition_priority_json jsonb not null default '{}'::jsonb,
  recap_json jsonb not null default '{}'::jsonb,
  recommended_actions_json jsonb not null default '[]'::jsonb,
  why_short text not null default '',
  signals_used text[] not null default '{}',
  confidence numeric(4,3) not null default 0.850 check (
    confidence >= 0 and confidence <= 1
  ),
  source_context_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (member_id, brief_date)
);

create table if not exists public.member_ai_plan_adaptations (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  plan_id uuid not null references public.workout_plans(id) on delete cascade,
  day_id uuid references public.workout_plan_days(id) on delete set null,
  task_id uuid references public.workout_plan_tasks(id) on delete set null,
  adaptation_type text not null check (
    adaptation_type in (
      'shorten_workout',
      'swap_exercise',
      'move_to_tomorrow',
      'restart_week',
      'recovery_week',
      'volume_adjustment',
      'intensity_adjustment'
    )
  ),
  status text not null default 'applied' check (
    status in ('suggested', 'applied', 'blocked', 'dismissed')
  ),
  why_short text not null default '',
  signals_used text[] not null default '{}',
  confidence numeric(4,3) not null default 0.800 check (
    confidence >= 0 and confidence <= 1
  ),
  before_json jsonb not null default '{}'::jsonb,
  after_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  applied_at timestamptz
);

create table if not exists public.member_ai_nudges (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  nudge_type text not null check (
    nudge_type in (
      'missed_streak',
      'declining_adherence',
      'nutrition_inconsistency',
      'stalled_progress',
      'overtraining_risk',
      'restart_week',
      'habit_reset',
      'weekly_reflection',
      'motivational_intervention',
      'recovery_recommendation'
    )
  ),
  title text not null,
  body text not null default '',
  action_type text not null default 'open_ai' check (
    action_type in (
      'start_workout',
      'shorten_workout',
      'swap_workout',
      'move_to_tomorrow',
      'log_meal',
      'log_hydration',
      'open_ai',
      'open_meal_plan',
      'share_weekly_summary'
    )
  ),
  action_payload_json jsonb not null default '{}'::jsonb,
  why_short text not null default '',
  signals_used text[] not null default '{}',
  confidence numeric(4,3) not null default 0.800 check (
    confidence >= 0 and confidence <= 1
  ),
  status text not null default 'pending' check (
    status in ('pending', 'delivered', 'dismissed', 'acted_on', 'expired')
  ),
  available_at timestamptz not null default timezone('utc', now()),
  external_key text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  delivered_at timestamptz,
  acted_at timestamptz,
  unique (member_id, external_key)
);

create table if not exists public.member_active_workout_sessions (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  plan_id uuid references public.workout_plans(id) on delete set null,
  day_id uuid references public.workout_plan_days(id) on delete set null,
  source_task_id uuid references public.workout_plan_tasks(id) on delete set null,
  status text not null default 'active' check (
    status in ('active', 'completed', 'abandoned', 'shortened')
  ),
  started_at timestamptz not null default timezone('utc', now()),
  ended_at timestamptz,
  planned_minutes integer not null default 0 check (planned_minutes >= 0),
  active_minutes integer check (active_minutes is null or active_minutes >= 0),
  readiness_score integer check (
    readiness_score is null or (readiness_score between 0 and 100)
  ),
  difficulty_score integer check (
    difficulty_score is null or (difficulty_score between 1 and 10)
  ),
  pace_delta_percent numeric(6,2),
  was_shortened boolean not null default false,
  was_swapped boolean not null default false,
  completion_rate numeric(5,2) check (
    completion_rate is null or (completion_rate >= 0 and completion_rate <= 100)
  ),
  why_short text not null default '',
  signals_used text[] not null default '{}',
  confidence numeric(4,3) not null default 0.850 check (
    confidence >= 0 and confidence <= 1
  ),
  summary_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists idx_member_active_workout_sessions_one_active
  on public.member_active_workout_sessions(member_id)
  where status = 'active';

create table if not exists public.member_active_workout_events (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.member_active_workout_sessions(id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  event_type text not null check (
    event_type in (
      'session_started',
      'session_shortened',
      'exercise_swapped',
      'pace_update',
      'rest_suggestion',
      'milestone',
      'prompt',
      'session_completed'
    )
  ),
  event_payload_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.member_ai_weekly_summaries (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  coach_id uuid references public.coach_profiles(user_id) on delete set null,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  week_start date not null,
  adherence_score integer not null default 0 check (adherence_score between 0 and 100),
  summary_text text not null default '',
  wins text[] not null default '{}',
  blockers text[] not null default '{}',
  next_focus text not null default '',
  workout_summary_json jsonb not null default '{}'::jsonb,
  nutrition_summary_json jsonb not null default '{}'::jsonb,
  why_short text not null default '',
  signals_used text[] not null default '{}',
  confidence numeric(4,3) not null default 0.850 check (
    confidence >= 0 and confidence <= 1
  ),
  share_status text not null default 'private' check (
    share_status in ('private', 'shared')
  ),
  shared_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (member_id, week_start)
);

create index if not exists idx_member_daily_readiness_member_date
  on public.member_daily_readiness_logs(member_id, log_date desc);
create index if not exists idx_member_ai_briefs_member_date
  on public.member_ai_daily_briefs(member_id, brief_date desc);
create index if not exists idx_member_ai_adaptations_member_created
  on public.member_ai_plan_adaptations(member_id, created_at desc);
create index if not exists idx_member_ai_nudges_member_available
  on public.member_ai_nudges(member_id, available_at desc);
create index if not exists idx_member_active_workout_events_session_created
  on public.member_active_workout_events(session_id, created_at asc);
create index if not exists idx_member_ai_weekly_summaries_member_week
  on public.member_ai_weekly_summaries(member_id, week_start desc);

alter table public.member_daily_readiness_logs enable row level security;
alter table public.member_ai_daily_briefs enable row level security;
alter table public.member_ai_plan_adaptations enable row level security;
alter table public.member_ai_nudges enable row level security;
alter table public.member_active_workout_sessions enable row level security;
alter table public.member_active_workout_events enable row level security;
alter table public.member_ai_weekly_summaries enable row level security;

drop policy if exists member_daily_readiness_logs_read_own on public.member_daily_readiness_logs;
create policy member_daily_readiness_logs_read_own
on public.member_daily_readiness_logs for select
to authenticated
using (member_id = auth.uid());

drop policy if exists member_daily_readiness_logs_manage_own on public.member_daily_readiness_logs;
create policy member_daily_readiness_logs_manage_own
on public.member_daily_readiness_logs for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists member_ai_daily_briefs_read_own on public.member_ai_daily_briefs;
create policy member_ai_daily_briefs_read_own
on public.member_ai_daily_briefs for select
to authenticated
using (member_id = auth.uid());

drop policy if exists member_ai_daily_briefs_manage_own on public.member_ai_daily_briefs;
create policy member_ai_daily_briefs_manage_own
on public.member_ai_daily_briefs for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists member_ai_plan_adaptations_read_own on public.member_ai_plan_adaptations;
create policy member_ai_plan_adaptations_read_own
on public.member_ai_plan_adaptations for select
to authenticated
using (member_id = auth.uid());

drop policy if exists member_ai_plan_adaptations_manage_own on public.member_ai_plan_adaptations;
create policy member_ai_plan_adaptations_manage_own
on public.member_ai_plan_adaptations for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists member_ai_nudges_read_own on public.member_ai_nudges;
create policy member_ai_nudges_read_own
on public.member_ai_nudges for select
to authenticated
using (member_id = auth.uid());

drop policy if exists member_ai_nudges_manage_own on public.member_ai_nudges;
create policy member_ai_nudges_manage_own
on public.member_ai_nudges for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists member_active_workout_sessions_read_own on public.member_active_workout_sessions;
create policy member_active_workout_sessions_read_own
on public.member_active_workout_sessions for select
to authenticated
using (member_id = auth.uid());

drop policy if exists member_active_workout_sessions_manage_own on public.member_active_workout_sessions;
create policy member_active_workout_sessions_manage_own
on public.member_active_workout_sessions for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists member_active_workout_events_read_own on public.member_active_workout_events;
create policy member_active_workout_events_read_own
on public.member_active_workout_events for select
to authenticated
using (member_id = auth.uid());

drop policy if exists member_active_workout_events_manage_own on public.member_active_workout_events;
create policy member_active_workout_events_manage_own
on public.member_active_workout_events for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists member_ai_weekly_summaries_read_own on public.member_ai_weekly_summaries;
create policy member_ai_weekly_summaries_read_own
on public.member_ai_weekly_summaries for select
to authenticated
using (member_id = auth.uid());

drop policy if exists member_ai_weekly_summaries_manage_own on public.member_ai_weekly_summaries;
create policy member_ai_weekly_summaries_manage_own
on public.member_ai_weekly_summaries for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop trigger if exists touch_member_daily_readiness_logs_updated_at on public.member_daily_readiness_logs;
create trigger touch_member_daily_readiness_logs_updated_at
before update on public.member_daily_readiness_logs
for each row execute function public.touch_updated_at();

drop trigger if exists touch_member_ai_daily_briefs_updated_at on public.member_ai_daily_briefs;
create trigger touch_member_ai_daily_briefs_updated_at
before update on public.member_ai_daily_briefs
for each row execute function public.touch_updated_at();

drop trigger if exists touch_member_ai_nudges_updated_at on public.member_ai_nudges;
create trigger touch_member_ai_nudges_updated_at
before update on public.member_ai_nudges
for each row execute function public.touch_updated_at();

drop trigger if exists touch_member_active_workout_sessions_updated_at on public.member_active_workout_sessions;
create trigger touch_member_active_workout_sessions_updated_at
before update on public.member_active_workout_sessions
for each row execute function public.touch_updated_at();

drop trigger if exists touch_member_ai_weekly_summaries_updated_at on public.member_ai_weekly_summaries;
create trigger touch_member_ai_weekly_summaries_updated_at
before update on public.member_ai_weekly_summaries
for each row execute function public.touch_updated_at();

create or replace function public.upsert_member_readiness_log(
  input_log_date date default current_date,
  input_energy_level integer default null,
  input_soreness_level integer default null,
  input_stress_level integer default null,
  input_available_minutes integer default null,
  input_location_mode text default null,
  input_equipment_override text[] default '{}',
  input_note text default null,
  input_source text default 'member'
)
returns public.member_daily_readiness_logs
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  computed_score integer := 55;
  computed_band text := 'yellow';
  record_out public.member_daily_readiness_logs%rowtype;
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can log readiness.';
  end if;

  computed_score := computed_score
    + ((coalesce(input_energy_level, 3) - 3) * 12)
    - ((coalesce(input_soreness_level, 3) - 3) * 9)
    - ((coalesce(input_stress_level, 3) - 3) * 8);

  if input_available_minutes is not null then
    if input_available_minutes >= 45 then
      computed_score := computed_score + 8;
    elsif input_available_minutes >= 25 then
      computed_score := computed_score + 4;
    elsif input_available_minutes <= 15 then
      computed_score := computed_score - 8;
    end if;
  end if;

  computed_score := greatest(0, least(100, computed_score));
  computed_band := case
    when computed_score >= 70 then 'green'
    when computed_score >= 45 then 'yellow'
    else 'red'
  end;

  insert into public.member_daily_readiness_logs (
    member_id,
    log_date,
    energy_level,
    soreness_level,
    stress_level,
    available_minutes,
    location_mode,
    equipment_override,
    readiness_score,
    intensity_band,
    note,
    source
  )
  values (
    requester,
    coalesce(input_log_date, current_date),
    input_energy_level,
    input_soreness_level,
    input_stress_level,
    input_available_minutes,
    input_location_mode,
    coalesce(input_equipment_override, '{}'::text[]),
    computed_score,
    computed_band,
    input_note,
    coalesce(nullif(input_source, ''), 'member')
  )
  on conflict (member_id, log_date) do update
    set energy_level = excluded.energy_level,
        soreness_level = excluded.soreness_level,
        stress_level = excluded.stress_level,
        available_minutes = excluded.available_minutes,
        location_mode = excluded.location_mode,
        equipment_override = excluded.equipment_override,
        readiness_score = excluded.readiness_score,
        intensity_band = excluded.intensity_band,
        note = excluded.note,
        source = excluded.source,
        updated_at = timezone('utc', now())
  returning * into record_out;

  return record_out;
end;
$$;

grant execute on function public.upsert_member_readiness_log(
  date,
  integer,
  integer,
  integer,
  integer,
  text,
  text[],
  text,
  text
) to authenticated;

create or replace function public.get_member_ai_coach_context(
  input_target_date date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  profile_json jsonb := '{}'::jsonb;
  member_profile_json jsonb := '{}'::jsonb;
  preferences_json jsonb := '{}'::jsonb;
  readiness_json jsonb := 'null'::jsonb;
  active_plan_json jsonb := 'null'::jsonb;
  today_day_json jsonb := 'null'::jsonb;
  today_tasks_json jsonb := '[]'::jsonb;
  recent_sessions_json jsonb := '[]'::jsonb;
  recent_task_logs_json jsonb := '[]'::jsonb;
  nutrition_json jsonb := '{}'::jsonb;
  weight_json jsonb := 'null'::jsonb;
  measurement_json jsonb := 'null'::jsonb;
  checkin_json jsonb := 'null'::jsonb;
  subscription_json jsonb := 'null'::jsonb;
  memory_json jsonb := '{}'::jsonb;
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  select to_jsonb(p)
  into profile_json
  from (
    select
      pr.user_id,
      pr.full_name,
      pr.country,
      r.code as role_code
    from public.profiles pr
    left join public.roles r on r.id = pr.role_id
    where pr.user_id = requester
  ) p;

  select to_jsonb(mp)
  into member_profile_json
  from (
    select *
    from public.member_profiles
    where user_id = requester
  ) mp;

  select to_jsonb(up)
  into preferences_json
  from (
    select *
    from public.user_preferences
    where user_id = requester
  ) up;

  select to_jsonb(r)
  into readiness_json
  from (
    select *
    from public.member_daily_readiness_logs
    where member_id = requester
      and log_date = coalesce(input_target_date, current_date)
  ) r;

  select to_jsonb(wp)
  into active_plan_json
  from (
    select
      id,
      member_id,
      coach_id,
      source,
      title,
      status,
      plan_json,
      start_date,
      end_date,
      assigned_at,
      plan_version,
      default_reminder_time,
      adaptation_mode,
      last_adapted_at,
      last_ai_brief_at
    from public.workout_plans
    where member_id = requester
      and status = 'active'
    order by assigned_at desc
    limit 1
  ) wp;

  select to_jsonb(day_row)
  into today_day_json
  from (
    select
      d.id,
      d.workout_plan_id,
      d.week_number,
      d.day_number,
      d.day_index,
      d.scheduled_date,
      d.label,
      d.focus,
      d.is_rest_day
    from public.workout_plan_days d
    where d.member_id = requester
      and d.scheduled_date = coalesce(input_target_date, current_date)
    order by d.created_at desc
    limit 1
  ) day_row;

  select coalesce(jsonb_agg(to_jsonb(task_row)), '[]'::jsonb)
  into today_tasks_json
  from (
    select
      t.id,
      t.day_id,
      t.workout_plan_id,
      t.task_type,
      t.title,
      t.instructions,
      t.sets,
      t.reps,
      t.duration_minutes,
      t.target_value,
      t.target_unit,
      t.scheduled_time,
      t.reminder_time,
      t.is_required,
      t.sort_order,
      t.exercise_id,
      t.rest_seconds,
      t.substitution_options_json,
      t.progression_rule,
      t.coach_cues_json,
      t.block_label
    from public.workout_plan_tasks t
    where t.member_id = requester
      and t.scheduled_date = coalesce(input_target_date, current_date)
    order by t.sort_order, t.title
  ) task_row;

  select coalesce(jsonb_agg(to_jsonb(session_row)), '[]'::jsonb)
  into recent_sessions_json
  from (
    select
      id,
      workout_plan_id,
      coach_id,
      title,
      performed_at,
      duration_minutes,
      readiness_score,
      difficulty_score,
      pace_delta_percent,
      was_shortened,
      was_swapped,
      completion_rate,
      summary_json
    from public.workout_sessions
    where member_id = requester
      and performed_at >= timezone('utc', now()) - interval '30 days'
    order by performed_at desc
    limit 20
  ) session_row;

  select coalesce(jsonb_agg(to_jsonb(log_row)), '[]'::jsonb)
  into recent_task_logs_json
  from (
    select
      l.task_id,
      l.completion_status,
      l.completion_percent,
      l.duration_minutes,
      l.difficulty_score,
      l.pain_score,
      l.was_substituted,
      l.swap_reason,
      l.actual_exercise_title,
      l.logged_at,
      t.scheduled_date,
      t.task_type,
      t.title
    from public.workout_task_logs l
    join public.workout_plan_tasks t on t.id = l.task_id
    where l.member_id = requester
      and l.logged_at >= timezone('utc', now()) - interval '30 days'
    order by l.logged_at desc
    limit 40
  ) log_row;

  select to_jsonb(weight_row)
  into weight_json
  from (
    select weight_kg, recorded_at
    from public.member_weight_entries
    where member_id = requester
    order by recorded_at desc
    limit 1
  ) weight_row;

  select to_jsonb(measurement_row)
  into measurement_json
  from (
    select recorded_at, waist_cm, chest_cm, hips_cm, arm_cm, thigh_cm, body_fat_percent
    from public.member_body_measurements
    where member_id = requester
    order by recorded_at desc
    limit 1
  ) measurement_row;

  select jsonb_build_object(
    'target', to_jsonb(tgt),
    'meal_logs_today', coalesce((
      select count(*)
      from public.meal_logs ml
      where ml.member_id = requester
        and ml.log_date = coalesce(input_target_date, current_date)
    ), 0),
    'planned_meals_today', coalesce((
      select count(*)
      from public.member_planned_meals pm
      where pm.member_id = requester
        and pm.plan_date = coalesce(input_target_date, current_date)
    ), 0),
    'hydration_ml_today', coalesce((
      select sum(h.amount_ml)
      from public.hydration_logs h
      where h.member_id = requester
        and h.log_date = coalesce(input_target_date, current_date)
    ), 0),
    'last_nutrition_checkin', (
      select to_jsonb(nc)
      from (
        select week_start, adherence_score, hunger_score, energy_score, notes, suggested_adjustment_json
        from public.nutrition_checkins
        where member_id = requester
        order by week_start desc
        limit 1
      ) nc
    )
  )
  into nutrition_json
  from (
    select *
    from public.nutrition_targets
    where member_id = requester
      and status = 'active'
    order by created_at desc
    limit 1
  ) tgt;

  select to_jsonb(checkin_row)
  into checkin_json
  from (
    select
      week_start,
      adherence_score,
      energy_score,
      sleep_score,
      blockers,
      wins,
      questions,
      created_at
    from public.weekly_checkins
    where member_id = requester
    order by week_start desc
    limit 1
  ) checkin_row;

  select to_jsonb(subscription_row)
  into subscription_json
  from (
    select
      s.id,
      s.coach_id,
      s.status,
      s.package_id,
      s.package_title,
      s.plan_name,
      s.thread_id,
      s.activated_at,
      s.created_at
    from public.list_member_subscriptions_detailed() s
    where s.status = 'active'
    order by coalesce(s.activated_at, s.created_at) desc
    limit 1
  ) subscription_row;

  select coalesce(
    jsonb_object_agg(memory_key, memory_value_json),
    '{}'::jsonb
  )
  into memory_json
  from public.ai_user_memories
  where user_id = requester;

  return jsonb_build_object(
    'target_date', coalesce(input_target_date, current_date),
    'profile', coalesce(profile_json, '{}'::jsonb),
    'member_profile', coalesce(member_profile_json, '{}'::jsonb),
    'preferences', coalesce(preferences_json, '{}'::jsonb),
    'readiness', readiness_json,
    'active_plan', active_plan_json,
    'today_day', today_day_json,
    'today_tasks', today_tasks_json,
    'recent_sessions', recent_sessions_json,
    'recent_task_logs', recent_task_logs_json,
    'latest_weight', weight_json,
    'latest_measurement', measurement_json,
    'nutrition', coalesce(nutrition_json, '{}'::jsonb),
    'latest_checkin', checkin_json,
    'active_subscription', subscription_json,
    'memories', memory_json
  );
end;
$$;

grant execute on function public.get_member_ai_coach_context(date) to authenticated;

create or replace function public.apply_member_ai_adjustment(
  input_adjustment_type text,
  input_brief_date date default current_date,
  input_task_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  brief_record public.member_ai_daily_briefs%rowtype;
  plan_record public.workout_plans%rowtype;
  day_record public.workout_plan_days%rowtype;
  task_record public.workout_plan_tasks%rowtype;
  adaptation_record public.member_ai_plan_adaptations%rowtype;
  is_coach_locked boolean := false;
  replacement_title text := '';
  replacement_instructions text := '';
  next_date date;
  before_payload jsonb := '{}'::jsonb;
  after_payload jsonb := '{}'::jsonb;
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can apply AI coach adjustments.';
  end if;

  select *
  into brief_record
  from public.member_ai_daily_briefs
  where member_id = requester
    and brief_date = coalesce(input_brief_date, current_date);

  if not found then
    raise exception 'Daily AI brief not found.';
  end if;

  if brief_record.plan_id is null then
    raise exception 'No active plan is linked to today''s AI brief.';
  end if;

  select *
  into plan_record
  from public.workout_plans
  where id = brief_record.plan_id
    and member_id = requester;

  if not found then
    raise exception 'Linked workout plan not found.';
  end if;

  if brief_record.day_id is not null then
    select *
    into day_record
    from public.workout_plan_days
    where id = brief_record.day_id
      and member_id = requester;
  end if;

  if input_task_id is not null then
    select *
    into task_record
    from public.workout_plan_tasks
    where id = input_task_id
      and member_id = requester;
  elsif brief_record.primary_task_id is not null then
    select *
    into task_record
    from public.workout_plan_tasks
    where id = brief_record.primary_task_id
      and member_id = requester;
  end if;

  is_coach_locked := plan_record.coach_id is not null
    or plan_record.source <> 'ai'
    or plan_record.adaptation_mode = 'coach_locked';

  before_payload := jsonb_build_object(
    'plan_id', plan_record.id,
    'plan_title', plan_record.title,
    'scheduled_date', day_record.scheduled_date,
    'primary_task_id', task_record.id,
    'primary_task_title', task_record.title
  );

  if input_adjustment_type = 'shorten_workout' then
    after_payload := jsonb_build_object(
      'strategy', 'shortened_today',
      'planned_minutes', coalesce((brief_record.recommended_workout_json ->> 'duration_minutes')::integer, task_record.duration_minutes, 30),
      'new_duration_minutes', greatest(
        12,
        round(coalesce((brief_record.recommended_workout_json ->> 'duration_minutes')::numeric, task_record.duration_minutes::numeric, 30) * 0.8)
      ),
      'kept_task_ids', (
        select coalesce(jsonb_agg(id), '[]'::jsonb)
        from (
          select t.id
          from public.workout_plan_tasks t
          where t.day_id = day_record.id
            and t.member_id = requester
            and t.task_type in ('workout', 'cardio', 'mobility')
          order by t.sort_order, t.title
          limit 2
        ) kept
      )
    );
  elsif input_adjustment_type = 'swap_exercise' then
    if task_record.id is null then
      raise exception 'No task is available to swap.';
    end if;

    replacement_title := coalesce(
      nullif(task_record.substitution_options_json -> 0 ->> 'title', ''),
      nullif(task_record.substitution_options_json ->> 0, ''),
      nullif((
        select ex.substitution_options_json -> 0 ->> 'title'
        from public.coach_exercise_library ex
        where ex.id = task_record.exercise_id
      ), ''),
      'Mobility Flow'
    );

    replacement_instructions := case
      when replacement_title = task_record.title then task_record.instructions
      else 'TAIYO swapped this movement based on today''s readiness, available setup, or recovery needs.'
    end;

    update public.workout_plan_tasks
    set title = replacement_title,
        instructions = replacement_instructions,
        updated_at = timezone('utc', now())
    where id = task_record.id
      and member_id = requester;

    after_payload := jsonb_build_object(
      'task_id', task_record.id,
      'new_title', replacement_title,
      'new_instructions', replacement_instructions
    );
  elsif input_adjustment_type = 'move_to_tomorrow' then
    if is_coach_locked then
      raise exception 'Coach-managed plans cannot be moved automatically.';
    end if;

    if day_record.id is null then
      raise exception 'No day is linked to today''s recommendation.';
    end if;

    next_date := day_record.scheduled_date + 1;

    update public.workout_plan_days
    set scheduled_date = next_date,
        updated_at = timezone('utc', now())
    where id = day_record.id
      and member_id = requester;

    update public.workout_plan_tasks
    set scheduled_date = next_date,
        updated_at = timezone('utc', now())
    where day_id = day_record.id
      and member_id = requester;

    after_payload := jsonb_build_object(
      'moved_to_date', next_date
    );
  else
    raise exception 'Unsupported AI coach adjustment.';
  end if;

  insert into public.member_ai_plan_adaptations (
    member_id,
    plan_id,
    day_id,
    task_id,
    adaptation_type,
    status,
    why_short,
    signals_used,
    confidence,
    before_json,
    after_json,
    applied_at
  )
  values (
    requester,
    plan_record.id,
    nullif(day_record.id, null),
    nullif(task_record.id, null),
    input_adjustment_type,
    'applied',
    case input_adjustment_type
      when 'shorten_workout' then 'TAIYO reduced today''s workload to protect consistency.'
      when 'swap_exercise' then 'TAIYO swapped the movement to fit today''s constraints.'
      when 'move_to_tomorrow' then 'TAIYO moved today''s session to tomorrow.'
      else 'TAIYO updated the plan.'
    end,
    case input_adjustment_type
      when 'shorten_workout' then array['available time', 'daily readiness']
      when 'swap_exercise' then array['exercise substitutions', 'daily readiness']
      when 'move_to_tomorrow' then array['schedule flexibility', 'plan ownership']
      else array['daily coach']
    end,
    0.850,
    before_payload,
    after_payload,
    timezone('utc', now())
  )
  returning * into adaptation_record;

  update public.workout_plans
  set last_adapted_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  where id = plan_record.id;

  return jsonb_build_object(
    'adaptation_id', adaptation_record.id,
    'status', adaptation_record.status,
    'adjustment_type', adaptation_record.adaptation_type,
    'why_short', adaptation_record.why_short,
    'signals_used', adaptation_record.signals_used,
    'confidence', adaptation_record.confidence,
    'before', adaptation_record.before_json,
    'after', adaptation_record.after_json
  );
end;
$$;

grant execute on function public.apply_member_ai_adjustment(text, date, uuid) to authenticated;

create or replace function public.start_member_active_workout(
  input_plan_id uuid,
  input_day_id uuid default null,
  input_target_date date default current_date
)
returns public.member_active_workout_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  plan_record public.workout_plans%rowtype;
  day_record public.workout_plan_days%rowtype;
  readiness_record public.member_daily_readiness_logs%rowtype;
  session_record public.member_active_workout_sessions%rowtype;
  tasks_json jsonb := '[]'::jsonb;
  planned_minutes integer := 0;
  source_task uuid;
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can start an active workout session.';
  end if;

  select *
  into plan_record
  from public.workout_plans
  where id = input_plan_id
    and member_id = requester;

  if not found then
    raise exception 'Workout plan not found.';
  end if;

  if input_day_id is not null then
    select *
    into day_record
    from public.workout_plan_days
    where id = input_day_id
      and member_id = requester
      and workout_plan_id = input_plan_id;
  else
    select *
    into day_record
    from public.workout_plan_days
    where member_id = requester
      and workout_plan_id = input_plan_id
      and scheduled_date = coalesce(input_target_date, current_date)
    limit 1;
  end if;

  if not found then
    raise exception 'Workout day not found.';
  end if;

  select *
  into readiness_record
  from public.member_daily_readiness_logs
  where member_id = requester
    and log_date = day_record.scheduled_date;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'task_id', t.id,
        'task_type', t.task_type,
        'title', t.title,
        'instructions', t.instructions,
        'sets', t.sets,
        'reps', t.reps,
        'duration_minutes', t.duration_minutes,
        'scheduled_time', t.scheduled_time,
        'reminder_time', t.reminder_time,
        'rest_seconds', t.rest_seconds,
        'block_label', t.block_label,
        'exercise_id', t.exercise_id,
        'substitution_options_json', t.substitution_options_json,
        'coach_cues_json', t.coach_cues_json,
        'sort_order', t.sort_order
      )
    ),
    '[]'::jsonb
  ),
  coalesce(sum(coalesce(t.duration_minutes, 0)), count(*) * 12),
  (array_agg(t.id order by t.sort_order, t.title))[1]
  into tasks_json, planned_minutes, source_task
  from public.workout_plan_tasks t
  where t.day_id = day_record.id
    and t.member_id = requester
    and t.task_type in ('workout', 'cardio', 'mobility');

  update public.member_active_workout_sessions
  set status = 'abandoned',
      ended_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  where member_id = requester
    and status = 'active';

  insert into public.member_active_workout_sessions (
    member_id,
    plan_id,
    day_id,
    source_task_id,
    status,
    planned_minutes,
    readiness_score,
    why_short,
    signals_used,
    confidence,
    summary_json
  )
  values (
    requester,
    plan_record.id,
    day_record.id,
    source_task,
    'active',
    coalesce(planned_minutes, 0),
    readiness_record.readiness_score,
    'TAIYO started today''s guided session.',
    array['daily coach'],
    0.900,
    jsonb_build_object(
      'plan_title', plan_record.title,
      'day_label', day_record.label,
      'day_focus', day_record.focus,
      'tasks', tasks_json,
      'completed_task_ids', '[]'::jsonb,
      'partial_task_ids', '[]'::jsonb,
      'skipped_task_ids', '[]'::jsonb
    )
  )
  returning * into session_record;

  insert into public.member_active_workout_events (
    session_id,
    member_id,
    event_type,
    event_payload_json
  )
  values (
    session_record.id,
    requester,
    'session_started',
    jsonb_build_object(
      'plan_id', plan_record.id,
      'day_id', day_record.id,
      'planned_minutes', planned_minutes
    )
  );

  return session_record;
end;
$$;

grant execute on function public.start_member_active_workout(uuid, uuid, date) to authenticated;

create or replace function public.record_member_active_workout_event(
  input_session_id uuid,
  input_event_type text,
  input_event_payload jsonb default '{}'::jsonb
)
returns public.member_active_workout_events
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  session_record public.member_active_workout_sessions%rowtype;
  event_record public.member_active_workout_events%rowtype;
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can record workout companion events.';
  end if;

  select *
  into session_record
  from public.member_active_workout_sessions
  where id = input_session_id
    and member_id = requester;

  if not found then
    raise exception 'Active workout session not found.';
  end if;

  insert into public.member_active_workout_events (
    session_id,
    member_id,
    event_type,
    event_payload_json
  )
  values (
    input_session_id,
    requester,
    input_event_type,
    coalesce(input_event_payload, '{}'::jsonb)
  )
  returning * into event_record;

  return event_record;
end;
$$;

grant execute on function public.record_member_active_workout_event(uuid, text, jsonb) to authenticated;

create or replace function public.complete_member_active_workout(
  input_session_id uuid,
  input_difficulty_score integer default null,
  input_summary jsonb default '{}'::jsonb
)
returns public.member_active_workout_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  session_record public.member_active_workout_sessions%rowtype;
  plan_record public.workout_plans%rowtype;
  task_id_text text;
  completion_value numeric := coalesce((input_summary ->> 'completion_rate')::numeric, null);
  active_minutes_value integer := coalesce((input_summary ->> 'active_minutes')::integer, null);
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can complete an active workout session.';
  end if;

  select *
  into session_record
  from public.member_active_workout_sessions
  where id = input_session_id
    and member_id = requester;

  if not found then
    raise exception 'Active workout session not found.';
  end if;

  select *
  into plan_record
  from public.workout_plans
  where id = session_record.plan_id;

  if active_minutes_value is null then
    active_minutes_value := greatest(
      0,
      floor(extract(epoch from (timezone('utc', now()) - session_record.started_at)) / 60)::integer
    );
  end if;

  if completion_value is null then
    completion_value := 100;
  end if;

  update public.member_active_workout_sessions
  set status = case
        when coalesce((input_summary ->> 'was_shortened')::boolean, false) then 'shortened'
        else 'completed'
      end,
      ended_at = timezone('utc', now()),
      active_minutes = active_minutes_value,
      difficulty_score = input_difficulty_score,
      pace_delta_percent = coalesce((input_summary ->> 'pace_delta_percent')::numeric, pace_delta_percent),
      was_shortened = coalesce((input_summary ->> 'was_shortened')::boolean, was_shortened),
      was_swapped = coalesce((input_summary ->> 'was_swapped')::boolean, was_swapped),
      completion_rate = completion_value,
      why_short = coalesce(nullif(input_summary ->> 'why_short', ''), why_short),
      summary_json = coalesce(summary_json, '{}'::jsonb) || coalesce(input_summary, '{}'::jsonb),
      updated_at = timezone('utc', now())
  where id = input_session_id
    and member_id = requester
  returning * into session_record;

  for task_id_text in
    select value
    from jsonb_array_elements_text(
      coalesce(session_record.summary_json -> 'completed_task_ids', '[]'::jsonb)
    )
  loop
    insert into public.workout_task_logs (
      task_id,
      member_id,
      completion_status,
      completion_percent,
      duration_minutes,
      difficulty_score,
      was_substituted,
      logged_at
    )
    values (
      task_id_text::uuid,
      requester,
      'completed',
      100,
      active_minutes_value,
      input_difficulty_score,
      coalesce((input_summary ->> 'was_swapped')::boolean, false),
      timezone('utc', now())
    )
    on conflict (task_id) do update
      set completion_status = excluded.completion_status,
          completion_percent = excluded.completion_percent,
          duration_minutes = excluded.duration_minutes,
          difficulty_score = excluded.difficulty_score,
          was_substituted = excluded.was_substituted,
          logged_at = excluded.logged_at,
          updated_at = timezone('utc', now());
  end loop;

  for task_id_text in
    select value
    from jsonb_array_elements_text(
      coalesce(session_record.summary_json -> 'partial_task_ids', '[]'::jsonb)
    )
  loop
    insert into public.workout_task_logs (
      task_id,
      member_id,
      completion_status,
      completion_percent,
      duration_minutes,
      difficulty_score,
      was_substituted,
      logged_at
    )
    values (
      task_id_text::uuid,
      requester,
      'partial',
      50,
      active_minutes_value,
      input_difficulty_score,
      coalesce((input_summary ->> 'was_swapped')::boolean, false),
      timezone('utc', now())
    )
    on conflict (task_id) do update
      set completion_status = excluded.completion_status,
          completion_percent = excluded.completion_percent,
          duration_minutes = excluded.duration_minutes,
          difficulty_score = excluded.difficulty_score,
          was_substituted = excluded.was_substituted,
          logged_at = excluded.logged_at,
          updated_at = timezone('utc', now());
  end loop;

  for task_id_text in
    select value
    from jsonb_array_elements_text(
      coalesce(session_record.summary_json -> 'skipped_task_ids', '[]'::jsonb)
    )
  loop
    insert into public.workout_task_logs (
      task_id,
      member_id,
      completion_status,
      completion_percent,
      duration_minutes,
      difficulty_score,
      was_substituted,
      logged_at
    )
    values (
      task_id_text::uuid,
      requester,
      'skipped',
      0,
      0,
      input_difficulty_score,
      coalesce((input_summary ->> 'was_swapped')::boolean, false),
      timezone('utc', now())
    )
    on conflict (task_id) do update
      set completion_status = excluded.completion_status,
          completion_percent = excluded.completion_percent,
          duration_minutes = excluded.duration_minutes,
          difficulty_score = excluded.difficulty_score,
          was_substituted = excluded.was_substituted,
          logged_at = excluded.logged_at,
          updated_at = timezone('utc', now());
  end loop;

  insert into public.workout_sessions (
    member_id,
    workout_plan_id,
    coach_id,
    title,
    performed_at,
    duration_minutes,
    note,
    readiness_score,
    difficulty_score,
    pace_delta_percent,
    was_shortened,
    was_swapped,
    completion_rate,
    summary_json
  )
  values (
    requester,
    session_record.plan_id,
    plan_record.coach_id,
    coalesce(session_record.summary_json ->> 'day_label', plan_record.title, 'TAIYO Session'),
    timezone('utc', now()),
    coalesce(session_record.active_minutes, active_minutes_value),
    input_summary ->> 'note',
    session_record.readiness_score,
    input_difficulty_score,
    session_record.pace_delta_percent,
    session_record.was_shortened,
    session_record.was_swapped,
    session_record.completion_rate,
    session_record.summary_json
  );

  insert into public.member_active_workout_events (
    session_id,
    member_id,
    event_type,
    event_payload_json
  )
  values (
    session_record.id,
    requester,
    'session_completed',
    coalesce(input_summary, '{}'::jsonb)
  );

  return session_record;
end;
$$;

grant execute on function public.complete_member_active_workout(uuid, integer, jsonb) to authenticated;

create or replace function public.build_member_ai_weekly_summary(
  input_week_start date default date_trunc('week', current_date)::date
)
returns public.member_ai_weekly_summaries
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  summary_record public.member_ai_weekly_summaries%rowtype;
  active_subscription record;
  total_tasks integer := 0;
  completed_tasks integer := 0;
  missed_or_skipped integer := 0;
  adherence integer := 0;
  meal_days integer := 0;
  hydration_days integer := 0;
  wins text[] := '{}';
  blockers text[] := '{}';
  next_focus text := '';
  summary_text text := '';
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can build AI weekly summaries.';
  end if;

  select
    count(*),
    count(*) filter (where effective_status = 'completed'),
    count(*) filter (where effective_status in ('missed', 'skipped'))
  into total_tasks, completed_tasks, missed_or_skipped
  from public.list_member_plan_agenda(
    null,
    coalesce(input_week_start, date_trunc('week', current_date)::date),
    coalesce(input_week_start, date_trunc('week', current_date)::date) + 6
  );

  if total_tasks > 0 then
    adherence := round((completed_tasks::numeric / total_tasks::numeric) * 100)::integer;
  end if;

  select count(distinct log_date)
  into meal_days
  from public.meal_logs
  where member_id = requester
    and log_date between coalesce(input_week_start, date_trunc('week', current_date)::date)
      and coalesce(input_week_start, date_trunc('week', current_date)::date) + 6;

  select count(distinct log_date)
  into hydration_days
  from public.hydration_logs
  where member_id = requester
    and log_date between coalesce(input_week_start, date_trunc('week', current_date)::date)
      and coalesce(input_week_start, date_trunc('week', current_date)::date) + 6;

  if completed_tasks >= 2 then
    wins := array_append(wins, 'Completed meaningful training sessions');
  end if;
  if meal_days >= 4 then
    wins := array_append(wins, 'Meal logging stayed active');
  end if;
  if hydration_days >= 4 then
    wins := array_append(wins, 'Hydration stayed consistent');
  end if;

  if missed_or_skipped >= 4 then
    blockers := array_append(blockers, 'Missed or skipped several planned tasks');
  end if;
  if meal_days < 3 then
    blockers := array_append(blockers, 'Nutrition adherence was inconsistent');
  end if;
  if hydration_days < 3 then
    blockers := array_append(blockers, 'Hydration habits dropped');
  end if;

  next_focus := case
    when adherence < 50 then 'Restart with a lighter, easier-to-finish week.'
    when hydration_days < 3 then 'Protect hydration and meal rhythm around training.'
    when adherence >= 80 then 'Keep momentum and progress the sessions that feel strongest.'
    else 'Reduce decision fatigue and hit the next planned session on time.'
  end;

  summary_text := format(
    'TAIYO weekly summary: %s%% adherence, %s completed tasks, %s nutrition logging days, %s hydration days. Next focus: %s',
    adherence,
    completed_tasks,
    meal_days,
    hydration_days,
    next_focus
  );

  select *
  into active_subscription
  from public.list_member_subscriptions_detailed() s
  where s.status = 'active'
  order by coalesce(s.activated_at, s.created_at) desc
  limit 1;

  insert into public.member_ai_weekly_summaries (
    member_id,
    coach_id,
    subscription_id,
    week_start,
    adherence_score,
    summary_text,
    wins,
    blockers,
    next_focus,
    workout_summary_json,
    nutrition_summary_json,
    why_short,
    signals_used,
    confidence
  )
  values (
    requester,
    active_subscription.coach_id,
    active_subscription.id,
    coalesce(input_week_start, date_trunc('week', current_date)::date),
    adherence,
    summary_text,
    wins,
    blockers,
    next_focus,
    jsonb_build_object(
      'total_tasks', total_tasks,
      'completed_tasks', completed_tasks,
      'missed_or_skipped', missed_or_skipped
    ),
    jsonb_build_object(
      'meal_days', meal_days,
      'hydration_days', hydration_days
    ),
    'TAIYO summarized the week around adherence and recovery.',
    array['workout adherence', 'nutrition consistency', 'hydration consistency'],
    0.880
  )
  on conflict (member_id, week_start) do update
    set coach_id = excluded.coach_id,
        subscription_id = excluded.subscription_id,
        adherence_score = excluded.adherence_score,
        summary_text = excluded.summary_text,
        wins = excluded.wins,
        blockers = excluded.blockers,
        next_focus = excluded.next_focus,
        workout_summary_json = excluded.workout_summary_json,
        nutrition_summary_json = excluded.nutrition_summary_json,
        why_short = excluded.why_short,
        signals_used = excluded.signals_used,
        confidence = excluded.confidence,
        updated_at = timezone('utc', now())
  returning * into summary_record;

  return summary_record;
end;
$$;

grant execute on function public.build_member_ai_weekly_summary(date) to authenticated;

create or replace function public.share_member_ai_weekly_summary(
  input_week_start date,
  input_subscription_id uuid default null
)
returns public.member_ai_weekly_summaries
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  summary_record public.member_ai_weekly_summaries%rowtype;
  subscription_record record;
  thread_record public.coach_member_threads%rowtype;
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can share AI weekly summaries.';
  end if;

  select *
  into summary_record
  from public.member_ai_weekly_summaries
  where member_id = requester
    and week_start = input_week_start;

  if not found then
    select * into summary_record
    from public.build_member_ai_weekly_summary(input_week_start);
  end if;

  select *
  into subscription_record
  from public.list_member_subscriptions_detailed() s
  where s.id = coalesce(input_subscription_id, summary_record.subscription_id)
     or (input_subscription_id is null and s.status = 'active')
  order by coalesce(s.activated_at, s.created_at) desc
  limit 1;

  if subscription_record.id is null then
    raise exception 'An active coach subscription is required to share this summary.';
  end if;

  select *
  into thread_record
  from public.coach_member_threads
  where subscription_id = subscription_record.id;

  if not found then
    raise exception 'Coach thread not found for this subscription.';
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
    'system',
    'system',
    summary_record.summary_text
  );

  update public.member_ai_weekly_summaries
  set coach_id = subscription_record.coach_id,
      subscription_id = subscription_record.id,
      share_status = 'shared',
      shared_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  where id = summary_record.id
  returning * into summary_record;

  return summary_record;
end;
$$;

grant execute on function public.share_member_ai_weekly_summary(date, uuid) to authenticated;
