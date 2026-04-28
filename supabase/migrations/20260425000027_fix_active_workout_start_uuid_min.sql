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
    order by scheduled_date, day_index, created_at
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
      order by t.sort_order, t.title
    ),
    '[]'::jsonb
  ),
  coalesce(sum(coalesce(t.duration_minutes, 0)), count(*) * 12)::integer,
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
