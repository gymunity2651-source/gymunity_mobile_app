alter table public.member_profiles
  add column if not exists daily_streak_count integer not null default 0,
  add column if not exists daily_streak_last_active_on date,
  add column if not exists daily_streak_last_active_at timestamptz,
  add column if not exists daily_streak_last_activity_source text;

create or replace function public.touch_member_daily_streak(
  input_activity_date date,
  input_activity_source text default 'app_open',
  input_activity_at timestamptz default timezone('utc', now())
)
returns table (
  current_streak_count integer,
  last_activity_date date,
  last_activity_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  activity_source_value text := coalesce(
    nullif(trim(input_activity_source), ''),
    'app_open'
  );
  activity_at_value timestamptz := coalesce(
    input_activity_at,
    timezone('utc', now())
  );
  profile_row public.member_profiles%rowtype;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if coalesce(public.current_role(), '') <> 'member' then
    raise exception 'Only members can update the daily streak.';
  end if;

  if input_activity_date is null then
    raise exception 'input_activity_date is required';
  end if;

  loop
    select *
    into profile_row
    from public.member_profiles
    where user_id = requester
    for update;

    if found then
      if profile_row.daily_streak_last_active_on is null then
        update public.member_profiles
        set daily_streak_count = greatest(profile_row.daily_streak_count, 1),
            daily_streak_last_active_on = input_activity_date,
            daily_streak_last_active_at = activity_at_value,
            daily_streak_last_activity_source = activity_source_value
        where user_id = requester
        returning * into profile_row;
      elsif input_activity_date > profile_row.daily_streak_last_active_on then
        update public.member_profiles
        set daily_streak_count = profile_row.daily_streak_count + 1,
            daily_streak_last_active_on = input_activity_date,
            daily_streak_last_active_at = activity_at_value,
            daily_streak_last_activity_source = activity_source_value
        where user_id = requester
        returning * into profile_row;
      end if;

      exit;
    end if;

    begin
      insert into public.member_profiles (
        user_id,
        daily_streak_count,
        daily_streak_last_active_on,
        daily_streak_last_active_at,
        daily_streak_last_activity_source
      )
      values (
        requester,
        1,
        input_activity_date,
        activity_at_value,
        activity_source_value
      )
      returning * into profile_row;

      exit;
    exception
      when unique_violation then
        null;
    end;
  end loop;

  return query
  select
    coalesce(profile_row.daily_streak_count, 0)::integer,
    profile_row.daily_streak_last_active_on,
    profile_row.daily_streak_last_active_at;
end;
$$;

revoke all on function public.touch_member_daily_streak(date, text, timestamptz) from public;
revoke all on function public.touch_member_daily_streak(date, text, timestamptz) from anon;
grant execute on function public.touch_member_daily_streak(date, text, timestamptz) to authenticated;
