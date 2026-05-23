do $$
declare
  fn text;
begin
  fn := pg_get_functiondef(
    'public.submit_weekly_checkin(uuid,date,numeric,numeric,integer,integer,integer,text,text,text,jsonb,integer,integer,text,integer,integer,text,integer,integer,text,text,jsonb)'::regprocedure
  );

  fn := replace(
    fn,
    'from public.subscriptions' || chr(10) ||
    '  where id = target_subscription_id' || chr(10) ||
    '    and member_id = requester' || chr(10) ||
    '    and status = ''active''',
    'from public.subscriptions s' || chr(10) ||
    '  where s.id = target_subscription_id' || chr(10) ||
    '    and s.member_id = requester' || chr(10) ||
    '    and s.status = ''active'''
  );

  if position('from public.subscriptions s' in fn) = 0
     or position('where s.id = target_subscription_id' in fn) = 0 then
    raise exception 'Could not qualify submit_weekly_checkin subscription lookup';
  end if;

  execute fn;
end $$;

do $$
declare
  fn text;
begin
  fn := pg_get_functiondef(
    'public.admin_verify_coach_payout_account(uuid,boolean,text)'::regprocedure
  );

  fn := replace(
    fn,
    'on conflict (coach_id) do update',
    'on conflict on constraint coach_payout_accounts_coach_id_key do update'
  );

  if position('on conflict on constraint coach_payout_accounts_coach_id_key do update' in fn) = 0 then
    raise exception 'Could not qualify admin_verify_coach_payout_account conflict target';
  end if;

  execute fn;
end $$;
