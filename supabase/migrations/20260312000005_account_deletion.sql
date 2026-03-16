alter table public.users
  add column if not exists deleted_at timestamptz,
  add column if not exists deletion_reason text;

alter table public.profiles
  add column if not exists deleted_at timestamptz;

create or replace function public.soft_delete_account(
  target_user_id uuid,
  deleted_email text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_deleted_email text := nullif(trim(deleted_email), '');
  deleted_timestamp timestamptz := timezone('utc', now());
  result jsonb;
begin
  if target_user_id is null then
    raise exception 'target_user_id is required';
  end if;

  if normalized_deleted_email is null then
    normalized_deleted_email :=
      'deleted+' || replace(target_user_id::text, '-', '') || '@deleted.gymunity.invalid';
  end if;

  update public.users
  set
    email = normalized_deleted_email,
    is_active = false,
    deleted_at = deleted_timestamp,
    deletion_reason = 'user_requested'
  where id = target_user_id;

  update public.profiles
  set
    full_name = 'Deleted GymUnity account',
    avatar_path = null,
    phone = null,
    country = null,
    onboarding_completed = false,
    deleted_at = deleted_timestamp,
    updated_at = deleted_timestamp
  where user_id = target_user_id;

  update public.coach_profiles
  set
    bio = 'Deleted account',
    specialties = '{}'::text[],
    years_experience = 0,
    hourly_rate = 0,
    is_verified = false,
    updated_at = deleted_timestamp
  where user_id = target_user_id;

  update public.products
  set
    is_active = false,
    updated_at = deleted_timestamp
  where seller_id = target_user_id;

  update public.subscriptions
  set
    status = case
      when status = 'active' then 'cancelled'
      else status
    end,
    updated_at = deleted_timestamp
  where member_id = target_user_id or coach_id = target_user_id;

  update public.workout_plans
  set
    status = case
      when status = 'active' then 'archived'
      else status
    end
  where member_id = target_user_id or coach_id = target_user_id;

  delete from public.notifications where user_id = target_user_id;
  delete from public.device_tokens where user_id = target_user_id;
  delete from public.chat_sessions where user_id = target_user_id;

  result := jsonb_build_object(
    'deleted_at', deleted_timestamp,
    'user_id', target_user_id
  );

  return result;
end;
$$;

revoke all on function public.soft_delete_account(uuid, text) from public;
revoke all on function public.soft_delete_account(uuid, text) from anon;
revoke all on function public.soft_delete_account(uuid, text) from authenticated;
