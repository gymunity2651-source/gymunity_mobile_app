-- Scheduled news ingestion infrastructure
-- Date: 2026-03-16

create extension if not exists pg_cron;
create extension if not exists pg_net;

create schema if not exists private;
revoke all on schema private from public;

create table if not exists private.news_scheduler_config (
  config_key text primary key,
  config_value text not null,
  updated_at timestamptz not null default timezone('utc', now())
);

create or replace function private.upsert_news_scheduler_config(
  p_key text,
  p_value text
)
returns void
language plpgsql
security definer
set search_path = private, public
as $$
begin
  if p_key is null or btrim(p_key) = '' then
    raise exception 'Scheduler config key is required.';
  end if;

  if p_value is null or btrim(p_value) = '' then
    raise exception 'Scheduler config value is required.';
  end if;

  insert into private.news_scheduler_config (
    config_key,
    config_value,
    updated_at
  )
  values (
    btrim(p_key),
    btrim(p_value),
    timezone('utc', now())
  )
  on conflict (config_key) do update set
    config_value = excluded.config_value,
    updated_at = excluded.updated_at;
end;
$$;

create or replace function private.unschedule_news_sync()
returns void
language plpgsql
security definer
set search_path = private, cron, public
as $$
declare
  existing_job_id bigint;
begin
  select jobid
  into existing_job_id
  from cron.job
  where jobname = 'sync-news-feeds-every-4-hours'
  limit 1;

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;
end;
$$;

create or replace function private.schedule_news_sync(
  p_project_url text,
  p_sync_secret text,
  p_cron text default '17 */4 * * *'
)
returns bigint
language plpgsql
security definer
set search_path = private, public, cron, net
as $$
declare
  normalized_url text;
  created_job_id bigint;
begin
  normalized_url := regexp_replace(coalesce(btrim(p_project_url), ''), '/+$', '');

  if normalized_url = '' or normalized_url !~ '^https://[A-Za-z0-9.-]+$' then
    raise exception 'Project URL must be a valid https origin.';
  end if;

  if p_sync_secret is null or length(btrim(p_sync_secret)) < 16 then
    raise exception 'Sync secret must be present and sufficiently long.';
  end if;

  if p_cron is null or btrim(p_cron) = '' then
    raise exception 'Cron expression is required.';
  end if;

  perform private.upsert_news_scheduler_config(
    'project_url',
    normalized_url
  );

  perform private.upsert_news_scheduler_config(
    'sync_secret',
    btrim(p_sync_secret)
  );

  perform private.unschedule_news_sync();

  select cron.schedule(
    'sync-news-feeds-every-4-hours',
    p_cron,
    $job$
    select
      net.http_post(
        url := (
          select config_value
          from private.news_scheduler_config
          where config_key = 'project_url'
        ) || '/functions/v1/sync-news-feeds',
        headers := jsonb_build_object(
          'Content-Type',
          'application/json',
          'x-news-sync-secret',
          (
            select config_value
            from private.news_scheduler_config
            where config_key = 'sync_secret'
          )
        ),
        body := jsonb_build_object('trigger', 'pg_cron')
      ) as request_id;
    $job$
  )
  into created_job_id;

  return created_job_id;
end;
$$;

revoke all on table private.news_scheduler_config from public;
revoke all on function private.upsert_news_scheduler_config(text, text) from public;
revoke all on function private.unschedule_news_sync() from public;
revoke all on function private.schedule_news_sync(text, text, text) from public;

comment on function private.schedule_news_sync(text, text, text) is
  'Configures the recurring sync-news-feeds cron job after NEWS_SYNC_SECRET is set in Edge Function secrets.';
