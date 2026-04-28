-- Coach Relationship Core transaction smoke test.
--
-- Run only on a disposable local database or a staging clone. This script creates
-- test users and rolls everything back at the end.

begin;

do $$
declare
  coach_user uuid := gen_random_uuid();
  member_user uuid := gen_random_uuid();
  other_user uuid := gen_random_uuid();
  package_id uuid;
  smoke_subscription_id uuid;
  duplicate_rejected boolean := false;
  first_receipt_id uuid;
  second_receipt_id uuid;
  thread_id uuid;
  second_thread_id uuid;
  message_id uuid;
  checkin_id uuid;
  checkin_count integer;
  feedback_message_count integer;
  visibility_row public.coach_member_visibility_settings%rowtype;
begin
  insert into auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  values
    (coach_user, 'coach-core-smoke@example.test', '', timezone('utc', now()), timezone('utc', now()), timezone('utc', now())),
    (member_user, 'member-core-smoke@example.test', '', timezone('utc', now()), timezone('utc', now()), timezone('utc', now())),
    (other_user, 'other-core-smoke@example.test', '', timezone('utc', now()), timezone('utc', now()), timezone('utc', now()));

  insert into public.users (id, email)
  values
    (coach_user, 'coach-core-smoke@example.test'),
    (member_user, 'member-core-smoke@example.test'),
    (other_user, 'other-core-smoke@example.test');

  insert into public.profiles (user_id, role_id, full_name, onboarding_completed)
  values
    (coach_user, 2, 'Smoke Coach', true),
    (member_user, 1, 'Smoke Member', true),
    (other_user, 1, 'Other Member', true);

  insert into public.coach_profiles (user_id, bio, specialties, years_experience, hourly_rate)
  values (coach_user, 'Smoke coach bio', array['Strength'], 5, 500);

  insert into public.coach_packages (
    coach_id,
    title,
    description,
    billing_cycle,
    price,
    is_active,
    visibility_status,
    payment_rails
  )
  values (
    coach_user,
    'Smoke Coaching',
    'Smoke test offer',
    'monthly',
    1000,
    true,
    'published',
    array['instapay', 'card', 'wallet']
  )
  returning id into package_id;

  perform set_config('request.jwt.claim.sub', member_user::text, true);
  select id
  into smoke_subscription_id
  from public.create_coach_checkout(
    package_id,
    'instapay',
    'Smoke checkout',
    jsonb_build_object('goal', 'strength')
  )
  limit 1;

  begin
    perform *
    from public.create_coach_checkout(package_id, 'instapay', null, '{}'::jsonb);
  exception when others then
    duplicate_rejected := true;
  end;
  if not duplicate_rejected then
    raise exception 'Duplicate checkout was not rejected.';
  end if;

  select id
  into first_receipt_id
  from public.submit_coach_payment_receipt(smoke_subscription_id, 'ref-only', null, null);
  if first_receipt_id is null then
    raise exception 'Reference-only receipt was not created.';
  end if;

  select id
  into second_receipt_id
  from public.submit_coach_payment_receipt(
    smoke_subscription_id,
    'ref-with-file',
    member_user::text || '/' || smoke_subscription_id::text || '/receipt.png',
    null
  );
  if second_receipt_id is null then
    raise exception 'Receipt-with-file was not created.';
  end if;

  perform set_config('request.jwt.claim.sub', coach_user::text, true);
  perform public.verify_coach_payment(second_receipt_id, 'Smoke approved.');

  if not exists (
    select 1 from public.subscriptions
    where id = smoke_subscription_id and status = 'active' and checkout_status = 'paid'
  ) then
    raise exception 'Subscription was not activated.';
  end if;

  thread_id := public.ensure_coach_member_thread(smoke_subscription_id);
  second_thread_id := public.ensure_coach_member_thread(smoke_subscription_id);
  if thread_id is distinct from second_thread_id then
    raise exception 'Thread creation is not idempotent.';
  end if;

  perform set_config('request.jwt.claim.sub', member_user::text, true);
  select id into message_id from public.send_coaching_message(thread_id, 'Member hello.');
  if message_id is null then
    raise exception 'Member message was not inserted.';
  end if;

  perform set_config('request.jwt.claim.sub', coach_user::text, true);
  select id into message_id from public.send_coaching_message(thread_id, 'Coach hello.');
  if message_id is null then
    raise exception 'Coach message was not inserted.';
  end if;

  perform set_config('request.jwt.claim.sub', member_user::text, true);
  select id
  into checkin_id
  from public.submit_weekly_checkin(
    smoke_subscription_id,
    current_date,
    82.5,
    90,
    150,
    7,
    8,
    'Win',
    'Blocker',
    'Question',
    '[]'::jsonb
  )
  limit 1;

  perform *
  from public.submit_weekly_checkin(
    smoke_subscription_id,
    current_date,
    81.5,
    89,
    60,
    null,
    null,
    'Updated win',
    null,
    null,
    '[]'::jsonb
  );

  select count(*)
  into checkin_count
  from public.weekly_checkins
  where subscription_id = smoke_subscription_id;
  if checkin_count <> 1 then
    raise exception 'Same-week check-in duplicated.';
  end if;

  perform set_config('request.jwt.claim.sub', coach_user::text, true);
  perform public.submit_coach_checkin_feedback(checkin_id, thread_id, 'Good work.');

  select count(*)
  into feedback_message_count
  from public.coach_messages cm
  where cm.thread_id = thread_id
    and message_type = 'checkin_feedback';
  if feedback_message_count <> 1 then
    raise exception 'Coach feedback message was not inserted.';
  end if;

  perform set_config('request.jwt.claim.sub', member_user::text, true);
  select *
  into visibility_row
  from public.upsert_coach_member_visibility(
    smoke_subscription_id,
    coach_user,
    false,
    false,
    false,
    false,
    false,
    false
  );
  if visibility_row.share_ai_plan_summary
     or visibility_row.share_workout_adherence
     or visibility_row.share_progress_metrics
     or visibility_row.share_nutrition_summary
     or visibility_row.share_product_recommendations
     or visibility_row.share_relevant_purchases then
    raise exception 'Privacy defaults were not false.';
  end if;

  update public.subscriptions
  set status = 'paused'
  where id = smoke_subscription_id;

  begin
    perform public.send_coaching_message(thread_id, 'Paused write should fail.');
    raise exception 'Paused message was allowed.';
  exception
    when raise_exception then
      raise;
    when others then
      null;
  end;

  begin
    perform public.submit_weekly_checkin(smoke_subscription_id, current_date + 7, null, null, 80, null, null, null, null, null, '[]'::jsonb);
    raise exception 'Paused check-in was allowed.';
  exception
    when raise_exception then
      raise;
    when others then
      null;
  end;
end $$;

rollback;
