-- Filter coach workspace check-in payloads by member visibility settings.
-- The workspace RPC must not return raw weekly_checkins rows to coaches.

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
  visibility_row public.coach_member_visibility_settings%rowtype;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  select *
  into visibility_row
  from public.coach_member_visibility_settings vs
  where vs.subscription_id = target_subscription_id
    and vs.coach_id = requester
  limit 1;

  select jsonb_build_object(
    'client', row_to_json(client_row),
    'notes', coalesce((select jsonb_agg(row_to_json(n) order by n.is_pinned desc, n.created_at desc) from public.coach_client_notes n where n.subscription_id = target_subscription_id and n.coach_id = requester), '[]'::jsonb),
    'threads', coalesce((select jsonb_agg(row_to_json(t) order by t.updated_at desc) from public.coach_member_threads t where t.subscription_id = target_subscription_id and t.coach_id = requester), '[]'::jsonb),
    'checkins', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', wc.id,
          'subscription_id', wc.subscription_id,
          'member_id', wc.member_id,
          'coach_id', wc.coach_id,
          'thread_id', wc.thread_id,
          'week_start', wc.week_start,
          'adherence_score',
            case when coalesce(visibility_row.share_workout_adherence, false)
              then wc.adherence_score else null end,
          'workouts_completed',
            case when coalesce(visibility_row.share_workout_adherence, false)
              then wc.workouts_completed else null end,
          'missed_workouts',
            case when coalesce(visibility_row.share_workout_adherence, false)
              then wc.missed_workouts else null end,
          'missed_workouts_reason',
            case when coalesce(visibility_row.share_workout_adherence, false)
              then wc.missed_workouts_reason else null end,
          'habit_adherence_score',
            case when coalesce(visibility_row.share_workout_adherence, false)
              then wc.habit_adherence_score else null end,
          'weight_kg',
            case when coalesce(visibility_row.share_progress_metrics, false)
              then wc.weight_kg else null end,
          'waist_cm',
            case when coalesce(visibility_row.share_progress_metrics, false)
              then wc.waist_cm else null end,
          'energy_score',
            case when coalesce(visibility_row.share_progress_metrics, false)
              then wc.energy_score else null end,
          'sleep_score',
            case when coalesce(visibility_row.share_progress_metrics, false)
              then wc.sleep_score else null end,
          'soreness_score',
            case when coalesce(visibility_row.share_progress_metrics, false)
              then wc.soreness_score else null end,
          'fatigue_score',
            case when coalesce(visibility_row.share_progress_metrics, false)
              then wc.fatigue_score else null end,
          'pain_warning',
            case when coalesce(visibility_row.share_progress_metrics, false)
              then wc.pain_warning else null end,
          'nutrition_adherence_score',
            case when coalesce(visibility_row.share_nutrition_summary, false)
              then wc.nutrition_adherence_score else null end,
          'biggest_obstacle',
            case when coalesce(visibility_row.share_ai_plan_summary, false)
              then wc.biggest_obstacle else null end,
          'support_needed',
            case when coalesce(visibility_row.share_ai_plan_summary, false)
              then wc.support_needed else null end,
          'wins',
            case when coalesce(visibility_row.share_ai_plan_summary, false)
              then wc.wins else null end,
          'blockers',
            case when coalesce(visibility_row.share_ai_plan_summary, false)
              then wc.blockers else null end,
          'questions',
            case when coalesce(visibility_row.share_ai_plan_summary, false)
              then wc.questions else null end,
          'checkin_metadata_json', '{}'::jsonb,
          'progress_photos',
            case when coalesce(visibility_row.share_progress_metrics, false)
              then coalesce((
                select jsonb_agg(
                  jsonb_build_object(
                    'id', pp.id,
                    'storage_path', pp.storage_path,
                    'angle', pp.angle,
                    'created_at', pp.created_at
                  )
                  order by pp.created_at desc
                )
                from public.progress_photos pp
                where pp.checkin_id = wc.id
                  and pp.member_id = wc.member_id
              ), '[]'::jsonb)
              else '[]'::jsonb
            end,
          'coach_reply', wc.coach_reply,
          'coach_feedback_json', wc.coach_feedback_json,
          'coach_feedback_at', wc.coach_feedback_at,
          'next_checkin_date', wc.next_checkin_date,
          'created_at', wc.created_at,
          'updated_at', wc.updated_at
        )
        order by wc.week_start desc
      )
      from public.weekly_checkins wc
      where wc.subscription_id = target_subscription_id
        and wc.coach_id = requester
    ), '[]'::jsonb),
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
    'visibility',
      case when visibility_row.id is null
        then '{}'::jsonb
        else to_jsonb(visibility_row)
      end
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

grant execute on function public.get_coach_client_workspace(uuid) to authenticated;
