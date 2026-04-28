-- Fix TAIYO Coach context subscription lookup.
-- get_member_ai_coach_context was selecting thread_id from the legacy
-- list_member_subscriptions_detailed() RPC, which does not expose that column
-- on live projects. The newer list_member_subscriptions_live() RPC does.

do $$
declare
  function_sql text;
begin
  select pg_get_functiondef('public.get_member_ai_coach_context(date)'::regprocedure)
  into function_sql;

  if function_sql is null then
    raise exception 'public.get_member_ai_coach_context(date) does not exist.';
  end if;

  function_sql := replace(
    function_sql,
    'from public.list_member_subscriptions_detailed() s',
    'from public.list_member_subscriptions_live() s'
  );

  execute function_sql;
end;
$$;

grant execute on function public.get_member_ai_coach_context(date) to authenticated;
