create or replace function public.list_coach_directory(
  specialty_filter text default null,
  limit_count integer default 20
)
returns table (
  user_id uuid,
  full_name text,
  specialties text[],
  hourly_rate numeric,
  rating_avg numeric,
  rating_count integer,
  is_verified boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    cp.user_id,
    coalesce(p.full_name, 'Coach') as full_name,
    cp.specialties,
    cp.hourly_rate,
    cp.rating_avg,
    cp.rating_count,
    cp.is_verified
  from public.coach_profiles cp
  join public.profiles p on p.user_id = cp.user_id
  where (
    specialty_filter is null
    or specialty_filter = ''
    or specialty_filter = 'All'
    or exists (
      select 1
      from unnest(cp.specialties) specialty
      where lower(specialty) = lower(specialty_filter)
    )
  )
  order by cp.rating_avg desc, cp.rating_count desc, cp.created_at desc
  limit greatest(limit_count, 1);
$$;

grant execute
on function public.list_coach_directory(text, integer)
to authenticated;
