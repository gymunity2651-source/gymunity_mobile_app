-- Fix get_coach_client_workspace JSON type mismatch.
-- row_to_json(...) returns json, while the fallback literal is jsonb.
-- Use to_jsonb(...) for visibility so COALESCE returns one consistent type.

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
    'visibility', coalesce((select to_jsonb(vs) from public.coach_member_visibility_settings vs where vs.subscription_id = target_subscription_id and vs.coach_id = requester), '{}'::jsonb)
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
