-- Personalized health/news recommendation system
-- Date: 2026-03-16

create table if not exists public.news_sources (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  base_url text not null,
  feed_url text,
  api_endpoint text,
  source_type text not null check (source_type in ('rss', 'api', 'manual')),
  language text not null default 'english',
  country text,
  category text,
  is_active boolean not null default true,
  trust_score numeric(5,2) not null default 80 check (
    trust_score >= 0 and trust_score <= 100
  ),
  source_weight numeric(5,2) not null default 1 check (
    source_weight > 0 and source_weight <= 5
  ),
  last_synced_at timestamptz,
  last_error_at timestamptz,
  last_error_message text,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (
    feed_url is not null
    or api_endpoint is not null
    or source_type = 'manual'
  )
);

create table if not exists public.news_articles (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.news_sources(id) on delete restrict,
  canonical_url text not null,
  external_id text,
  title text not null,
  summary text not null default '',
  content text,
  author_name text,
  image_url text,
  published_at timestamptz not null,
  fetched_at timestamptz not null default timezone('utc', now()),
  language text not null default 'english',
  category text,
  tags jsonb not null default '[]'::jsonb,
  target_roles jsonb not null default '[]'::jsonb,
  target_goals jsonb not null default '[]'::jsonb,
  target_levels jsonb not null default '[]'::jsonb,
  trust_score numeric(5,2) not null default 70 check (
    trust_score >= 0 and trust_score <= 100
  ),
  evidence_level text check (
    evidence_level is null
    or evidence_level in (
      'expert_reviewed',
      'source_reported',
      'educational',
      'unknown'
    )
  ),
  safety_level text not null default 'general' check (
    safety_level in ('general', 'caution', 'restricted')
  ),
  quality_score numeric(5,2) not null default 50 check (
    quality_score >= 0 and quality_score <= 100
  ),
  dedupe_hash text,
  is_active boolean not null default true,
  is_featured boolean not null default false,
  ingestion_notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (canonical_url),
  check (jsonb_typeof(tags) = 'array'),
  check (jsonb_typeof(target_roles) = 'array'),
  check (jsonb_typeof(target_goals) = 'array'),
  check (jsonb_typeof(target_levels) = 'array')
);

create table if not exists public.news_article_topics (
  article_id uuid not null references public.news_articles(id) on delete cascade,
  topic_code text not null,
  score numeric(5,3) not null check (score > 0 and score <= 1),
  created_at timestamptz not null default timezone('utc', now()),
  primary key (article_id, topic_code)
);

create table if not exists public.user_news_interests (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  topic_code text not null,
  score numeric(5,3) not null check (score >= -1 and score <= 1),
  source text not null check (
    source in (
      'onboarding',
      'explicit_preference',
      'inferred_from_behavior',
      'inferred_from_ai_memory',
      'inferred_from_activity'
    )
  ),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, topic_code, source)
);

create table if not exists public.news_article_interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  article_id uuid not null references public.news_articles(id) on delete cascade,
  interaction_type text not null check (
    interaction_type in (
      'impression',
      'click',
      'open',
      'save',
      'dismiss',
      'share',
      'mark_not_interested'
    )
  ),
  created_at timestamptz not null default timezone('utc', now()),
  metadata jsonb not null default '{}'::jsonb,
  check (jsonb_typeof(metadata) = 'object')
);

create table if not exists public.news_article_bookmarks (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  article_id uuid not null references public.news_articles(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, article_id)
);

create index if not exists idx_news_sources_active_synced
  on public.news_sources(is_active, last_synced_at desc);

create unique index if not exists idx_news_articles_source_external
  on public.news_articles(source_id, external_id)
  where external_id is not null;

create unique index if not exists idx_news_articles_dedupe_hash
  on public.news_articles(dedupe_hash)
  where dedupe_hash is not null;

create index if not exists idx_news_articles_published
  on public.news_articles(published_at desc);

create index if not exists idx_news_articles_source_published
  on public.news_articles(source_id, published_at desc);

create index if not exists idx_news_articles_active_published
  on public.news_articles(is_active, published_at desc);

create index if not exists idx_news_articles_active_feed
  on public.news_articles(published_at desc)
  where is_active = true and safety_level <> 'restricted';

create index if not exists idx_news_articles_safety_published
  on public.news_articles(safety_level, published_at desc);

create index if not exists idx_news_articles_category_published
  on public.news_articles(category, published_at desc);

create index if not exists idx_news_articles_language_published
  on public.news_articles(language, published_at desc);

create index if not exists idx_news_articles_target_roles
  on public.news_articles using gin(target_roles jsonb_path_ops);

create index if not exists idx_news_articles_target_goals
  on public.news_articles using gin(target_goals jsonb_path_ops);

create index if not exists idx_news_articles_target_levels
  on public.news_articles using gin(target_levels jsonb_path_ops);

create index if not exists idx_news_article_topics_article
  on public.news_article_topics(article_id);

create index if not exists idx_news_article_topics_topic
  on public.news_article_topics(topic_code, score desc);

create index if not exists idx_user_news_interests_user_updated
  on public.user_news_interests(user_id, updated_at desc);

create index if not exists idx_news_article_interactions_user_created
  on public.news_article_interactions(user_id, created_at desc);

create index if not exists idx_news_article_interactions_lookup
  on public.news_article_interactions(
    user_id,
    article_id,
    interaction_type,
    created_at desc
  );

create index if not exists idx_news_article_bookmarks_user_created
  on public.news_article_bookmarks(user_id, created_at desc);

drop trigger if exists touch_news_sources_updated_at on public.news_sources;
create trigger touch_news_sources_updated_at
before update on public.news_sources
for each row execute function public.touch_updated_at();

drop trigger if exists touch_news_articles_updated_at on public.news_articles;
create trigger touch_news_articles_updated_at
before update on public.news_articles
for each row execute function public.touch_updated_at();

drop trigger if exists touch_user_news_interests_updated_at on public.user_news_interests;
create trigger touch_user_news_interests_updated_at
before update on public.user_news_interests
for each row execute function public.touch_updated_at();

insert into public.news_sources (
  id,
  name,
  base_url,
  feed_url,
  source_type,
  language,
  country,
  category,
  is_active,
  trust_score,
  source_weight,
  notes
)
values
  (
    '4be51e3b-91be-4c6c-a9cb-09fd9cdd2380',
    'NIH News Releases',
    'https://www.nih.gov',
    'https://www.nih.gov/news-releases/feed.xml',
    'rss',
    'english',
    'US',
    'research_news',
    true,
    92,
    1.00,
    'Official National Institutes of Health news releases.'
  ),
  (
    'd69771c2-9c13-4a65-a67d-4742219cbb94',
    'NIH News in Health',
    'https://newsinhealth.nih.gov',
    'https://newsinhealth.nih.gov/rss',
    'rss',
    'english',
    'US',
    'health_education',
    true,
    88,
    1.05,
    'Official NIH consumer health education articles.'
  ),
  (
    'b838cb56-852a-4b1b-9878-263f4e433433',
    'WHO News (English)',
    'https://www.who.int',
    'https://www.who.int/rss-feeds/news-english.xml',
    'rss',
    'english',
    'INT',
    'public_health',
    true,
    90,
    1.10,
    'Official World Health Organization English news feed.'
  )
on conflict (id) do update set
  name = excluded.name,
  base_url = excluded.base_url,
  feed_url = excluded.feed_url,
  source_type = excluded.source_type,
  language = excluded.language,
  country = excluded.country,
  category = excluded.category,
  is_active = excluded.is_active,
  trust_score = excluded.trust_score,
  source_weight = excluded.source_weight,
  notes = excluded.notes;

alter table public.news_sources enable row level security;
alter table public.news_articles enable row level security;
alter table public.news_article_topics enable row level security;
alter table public.user_news_interests enable row level security;
alter table public.news_article_interactions enable row level security;
alter table public.news_article_bookmarks enable row level security;

drop policy if exists news_sources_read_active on public.news_sources;
create policy news_sources_read_active
on public.news_sources for select
to authenticated
using (is_active = true);

drop policy if exists news_articles_read_safe_active on public.news_articles;
create policy news_articles_read_safe_active
on public.news_articles for select
to authenticated
using (
  is_active = true
  and safety_level <> 'restricted'
  and exists (
    select 1
    from public.news_sources source_row
    where source_row.id = news_articles.source_id
      and source_row.is_active = true
  )
);

drop policy if exists news_article_topics_read_safe_articles on public.news_article_topics;
create policy news_article_topics_read_safe_articles
on public.news_article_topics for select
to authenticated
using (
  exists (
    select 1
    from public.news_articles article_row
    join public.news_sources source_row on source_row.id = article_row.source_id
    where article_row.id = news_article_topics.article_id
      and article_row.is_active = true
      and article_row.safety_level <> 'restricted'
      and source_row.is_active = true
  )
);

drop policy if exists user_news_interests_read_own on public.user_news_interests;
create policy user_news_interests_read_own
on public.user_news_interests for select
to authenticated
using (user_id = auth.uid());

drop policy if exists news_article_interactions_read_own on public.news_article_interactions;
create policy news_article_interactions_read_own
on public.news_article_interactions for select
to authenticated
using (user_id = auth.uid());

drop policy if exists news_article_interactions_insert_own on public.news_article_interactions;
create policy news_article_interactions_insert_own
on public.news_article_interactions for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists news_article_bookmarks_read_own on public.news_article_bookmarks;
create policy news_article_bookmarks_read_own
on public.news_article_bookmarks for select
to authenticated
using (user_id = auth.uid());

drop policy if exists news_article_bookmarks_manage_own on public.news_article_bookmarks;
create policy news_article_bookmarks_manage_own
on public.news_article_bookmarks for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create or replace function public.news_safe_jsonb_array(input jsonb)
returns jsonb
language sql
immutable
as $$
  select case
    when jsonb_typeof(input) = 'array' then input
    else '[]'::jsonb
  end
$$;

create or replace function public.news_target_matches(targets jsonb, desired text)
returns boolean
language sql
immutable
as $$
  select
    desired is null
    or jsonb_array_length(public.news_safe_jsonb_array(targets)) = 0
    or public.news_safe_jsonb_array(targets) @> to_jsonb(array['all']::text[])
    or public.news_safe_jsonb_array(targets) @> to_jsonb(array[lower(desired)]::text[])
$$;

create or replace function public.normalize_news_goal(input_goal text)
returns text
language sql
immutable
as $$
  select case trim(lower(coalesce(input_goal, '')))
    when '' then null
    when 'build_muscle' then 'muscle_gain'
    when 'muscle_gain' then 'muscle_gain'
    when 'lose_weight' then 'fat_loss'
    when 'fat_loss' then 'fat_loss'
    when 'endurance' then 'endurance'
    when 'mobility' then 'mobility'
    when 'recovery' then 'recovery'
    when 'functional' then 'general_fitness'
    when 'sports' then 'sports_performance'
    when 'general_fitness' then 'general_fitness'
    else replace(trim(lower(input_goal)), ' ', '_')
  end
$$;

create or replace function public.normalize_news_level(input_level text)
returns text
language sql
immutable
as $$
  select case trim(lower(coalesce(input_level, '')))
    when '' then null
    when 'beginner' then 'beginner'
    when 'intermediate' then 'intermediate'
    when 'advanced' then 'advanced'
    when 'athlete' then 'advanced'
    when 'all' then 'all'
    else replace(trim(lower(input_level)), ' ', '_')
  end
$$;

create or replace function public.upsert_user_news_interest(
  p_user_id uuid,
  p_topic_code text,
  p_score numeric,
  p_source text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null
     or nullif(trim(coalesce(p_topic_code, '')), '') is null
     or nullif(trim(coalesce(p_source, '')), '') is null then
    return;
  end if;

  insert into public.user_news_interests (
    user_id,
    topic_code,
    score,
    source,
    created_at,
    updated_at
  )
  values (
    p_user_id,
    lower(trim(p_topic_code)),
    greatest(-1::numeric, least(1::numeric, coalesce(p_score, 0))),
    lower(trim(p_source)),
    timezone('utc', now()),
    timezone('utc', now())
  )
  on conflict (user_id, topic_code, source) do update
  set score = excluded.score,
      updated_at = excluded.updated_at;
end;
$$;

create or replace function public.bump_user_news_interest(
  p_user_id uuid,
  p_topic_code text,
  p_delta numeric,
  p_source text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null
     or nullif(trim(coalesce(p_topic_code, '')), '') is null
     or nullif(trim(coalesce(p_source, '')), '') is null
     or coalesce(p_delta, 0) = 0 then
    return;
  end if;

  insert into public.user_news_interests (
    user_id,
    topic_code,
    score,
    source,
    created_at,
    updated_at
  )
  values (
    p_user_id,
    lower(trim(p_topic_code)),
    greatest(-1::numeric, least(1::numeric, coalesce(p_delta, 0))),
    lower(trim(p_source)),
    timezone('utc', now()),
    timezone('utc', now())
  )
  on conflict (user_id, topic_code, source) do update
  set score = greatest(
        -1::numeric,
        least(1::numeric, public.user_news_interests.score + excluded.score)
      ),
      updated_at = excluded.updated_at;
end;
$$;

create or replace function public.sync_member_news_interests(p_user_id uuid default auth.uid())
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := coalesce(p_user_id, auth.uid());
  role_code text;
  goal_code text;
  level_code text;
  sessions_last_30d integer := 0;
  days_since_last_workout integer;
  memory_text text := '';
begin
  if requester is null then
    return;
  end if;

  select
    r.code,
    public.normalize_news_goal(mp.goal),
    public.normalize_news_level(mp.experience_level)
  into role_code, goal_code, level_code
  from public.profiles profile_row
  left join public.roles r on r.id = profile_row.role_id
  left join public.member_profiles mp on mp.user_id = profile_row.user_id
  where profile_row.user_id = requester;

  delete from public.user_news_interests
  where user_id = requester
    and source in (
      'onboarding',
      'inferred_from_activity',
      'inferred_from_ai_memory'
    );

  if coalesce(role_code, '') <> 'member' then
    return;
  end if;

  case goal_code
    when 'muscle_gain' then
      perform public.upsert_user_news_interest(requester, 'muscle_gain', 0.95, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'strength_training', 0.75, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'nutrition_basics', 0.45, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'recovery', 0.35, 'onboarding');
    when 'fat_loss' then
      perform public.upsert_user_news_interest(requester, 'fat_loss', 0.95, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'nutrition_basics', 0.75, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'workout_consistency', 0.60, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'general_wellness', 0.35, 'onboarding');
    when 'endurance' then
      perform public.upsert_user_news_interest(requester, 'endurance', 0.95, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'heart_health', 0.60, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'hydration', 0.45, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'recovery', 0.40, 'onboarding');
    when 'mobility' then
      perform public.upsert_user_news_interest(requester, 'mobility', 0.95, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'recovery', 0.70, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'injury_prevention', 0.65, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'general_wellness', 0.30, 'onboarding');
    when 'sports_performance' then
      perform public.upsert_user_news_interest(requester, 'endurance', 0.60, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'strength_training', 0.60, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'recovery', 0.50, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'injury_prevention', 0.45, 'onboarding');
    when 'general_fitness' then
      perform public.upsert_user_news_interest(requester, 'general_wellness', 0.70, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'strength_training', 0.45, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'mobility', 0.40, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'workout_consistency', 0.50, 'onboarding');
  end case;

  case level_code
    when 'beginner' then
      perform public.upsert_user_news_interest(requester, 'beginner_training', 0.85, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'injury_prevention', 0.50, 'onboarding');
    when 'intermediate' then
      perform public.upsert_user_news_interest(requester, 'workout_consistency', 0.30, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'recovery', 0.25, 'onboarding');
    when 'advanced' then
      perform public.upsert_user_news_interest(requester, 'recovery', 0.45, 'onboarding');
      perform public.upsert_user_news_interest(requester, 'hydration', 0.30, 'onboarding');
  end case;

  select count(*)
  into sessions_last_30d
  from public.workout_sessions
  where member_id = requester
    and performed_at >= timezone('utc', now()) - interval '30 days';

  select (current_date - max(performed_at::date))::integer
  into days_since_last_workout
  from public.workout_sessions
  where member_id = requester;

  if coalesce(sessions_last_30d, 0) = 0 then
    perform public.upsert_user_news_interest(requester, 'workout_consistency', 0.75, 'inferred_from_activity');
    perform public.upsert_user_news_interest(requester, 'beginner_training', 0.35, 'inferred_from_activity');
  elsif sessions_last_30d between 1 and 5 then
    perform public.upsert_user_news_interest(requester, 'workout_consistency', 0.45, 'inferred_from_activity');
    perform public.upsert_user_news_interest(requester, 'recovery', 0.25, 'inferred_from_activity');
  else
    perform public.upsert_user_news_interest(requester, 'recovery', 0.55, 'inferred_from_activity');
    perform public.upsert_user_news_interest(requester, 'hydration', 0.40, 'inferred_from_activity');
    perform public.upsert_user_news_interest(requester, 'sleep', 0.35, 'inferred_from_activity');
  end if;

  if coalesce(days_since_last_workout, 0) >= 10 then
    perform public.upsert_user_news_interest(requester, 'workout_consistency', 0.65, 'inferred_from_activity');
  end if;

  select lower(
           coalesce(
             string_agg(memory_key || ' ' || coalesce(memory_value_json::text, ''), ' ' order by updated_at desc),
             ''
           )
         )
  into memory_text
  from public.ai_user_memories
  where user_id = requester;

  if memory_text like '%sleep%' then
    perform public.upsert_user_news_interest(requester, 'sleep', 0.50, 'inferred_from_ai_memory');
  end if;

  if memory_text like '%hydrat%' then
    perform public.upsert_user_news_interest(requester, 'hydration', 0.45, 'inferred_from_ai_memory');
  end if;

  if memory_text like '%recover%' then
    perform public.upsert_user_news_interest(requester, 'recovery', 0.55, 'inferred_from_ai_memory');
  end if;

  if memory_text like '%injur%'
     or memory_text like '%pain%'
     or memory_text like '%knee%'
     or memory_text like '%back%' then
    perform public.upsert_user_news_interest(requester, 'injury_prevention', 0.60, 'inferred_from_ai_memory');
    perform public.upsert_user_news_interest(requester, 'mobility', 0.40, 'inferred_from_ai_memory');
  end if;

  if memory_text like '%nutrition%'
     or memory_text like '%protein%'
     or memory_text like '%meal%' then
    perform public.upsert_user_news_interest(requester, 'nutrition_basics', 0.55, 'inferred_from_ai_memory');
  end if;
end;
$$;

create or replace function public.track_news_interaction(
  p_article_id uuid,
  p_interaction_type text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  interaction_id uuid;
  topic_row record;
  applied_delta numeric := 0;
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  if lower(trim(coalesce(p_interaction_type, ''))) not in (
    'impression',
    'click',
    'open',
    'save',
    'dismiss',
    'share',
    'mark_not_interested'
  ) then
    raise exception 'Unsupported interaction type.';
  end if;

  if p_metadata is null or jsonb_typeof(p_metadata) <> 'object' then
    raise exception 'Interaction metadata must be a JSON object.';
  end if;

  if not exists (
    select 1
    from public.news_articles article_row
    join public.news_sources source_row on source_row.id = article_row.source_id
    where article_row.id = p_article_id
      and article_row.is_active = true
      and article_row.safety_level <> 'restricted'
      and source_row.is_active = true
  ) then
    raise exception 'Article not found.';
  end if;

  insert into public.news_article_interactions (
    user_id,
    article_id,
    interaction_type,
    metadata
  )
  values (
    requester,
    p_article_id,
    lower(trim(p_interaction_type)),
    p_metadata
  )
  returning id into interaction_id;

  applied_delta := case lower(trim(p_interaction_type))
    when 'save' then 0.18
    when 'share' then 0.15
    when 'open' then 0.12
    when 'click' then 0.10
    when 'impression' then 0.02
    when 'dismiss' then -0.15
    when 'mark_not_interested' then -0.30
    else 0
  end;

  if applied_delta <> 0 then
    for topic_row in
      select topic_code, score
      from public.news_article_topics
      where article_id = p_article_id
    loop
      perform public.bump_user_news_interest(
        requester,
        topic_row.topic_code,
        applied_delta * greatest(topic_row.score, 0.15),
        'inferred_from_behavior'
      );
    end loop;
  end if;

  return interaction_id;
end;
$$;

create or replace function public.save_news_article(p_article_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  if exists (
    select 1
    from public.news_article_bookmarks
    where user_id = requester
      and article_id = p_article_id
  ) then
    return false;
  end if;

  insert into public.news_article_bookmarks (user_id, article_id)
  values (requester, p_article_id);

  perform public.track_news_interaction(
    p_article_id,
    'save',
    '{"origin":"bookmark"}'::jsonb
  );

  return true;
end;
$$;

create or replace function public.dismiss_news_article(p_article_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.track_news_interaction(
    p_article_id,
    'dismiss',
    '{"origin":"feed"}'::jsonb
  );
  return true;
end;
$$;

create or replace function public.list_news_article_topics(p_article_id uuid)
returns table (
  topic_code text,
  score numeric
)
language sql
security definer
set search_path = public
as $$
  select
    topic_code,
    score
  from public.news_article_topics
  where article_id = p_article_id
  order by score desc, topic_code asc
$$;

create or replace function public.list_saved_news_articles()
returns table (
  article_id uuid,
  source_id uuid,
  source_name text,
  source_base_url text,
  canonical_url text,
  title text,
  summary text,
  image_url text,
  published_at timestamptz,
  language text,
  category text,
  safety_level text,
  evidence_level text,
  trust_score numeric,
  quality_score numeric,
  topic_codes text[],
  is_saved boolean,
  saved_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    article_row.id as article_id,
    article_row.source_id,
    source_row.name as source_name,
    source_row.base_url as source_base_url,
    article_row.canonical_url,
    article_row.title,
    article_row.summary,
    article_row.image_url,
    article_row.published_at,
    article_row.language,
    article_row.category,
    article_row.safety_level,
    article_row.evidence_level,
    article_row.trust_score,
    article_row.quality_score,
    coalesce(topic_rollup.topic_codes, '{}'::text[]) as topic_codes,
    true as is_saved,
    bookmark_row.created_at as saved_at
  from public.news_article_bookmarks bookmark_row
  join public.news_articles article_row on article_row.id = bookmark_row.article_id
  join public.news_sources source_row on source_row.id = article_row.source_id
  left join (
    select
      article_id,
      array_agg(topic_code order by score desc, topic_code asc) as topic_codes
    from public.news_article_topics
    group by article_id
  ) topic_rollup on topic_rollup.article_id = article_row.id
  where bookmark_row.user_id = auth.uid()
    and article_row.is_active = true
    and article_row.safety_level <> 'restricted'
    and source_row.is_active = true
  order by bookmark_row.created_at desc
$$;

create or replace function public.list_personalized_news(
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  article_id uuid,
  source_id uuid,
  source_name text,
  source_base_url text,
  canonical_url text,
  title text,
  summary text,
  image_url text,
  published_at timestamptz,
  language text,
  category text,
  safety_level text,
  evidence_level text,
  trust_score numeric,
  quality_score numeric,
  topic_codes text[],
  relevance_reason text,
  relevance_tags text[],
  ranking_score numeric,
  is_saved boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  role_code text := 'member';
  goal_code text;
  level_code text;
  preferred_language text := 'english';
begin
  if requester is null then
    raise exception 'Not authenticated.';
  end if;

  select
    coalesce(role_row.code, 'member'),
    public.normalize_news_goal(member_row.goal),
    public.normalize_news_level(member_row.experience_level),
    coalesce(preferences_row.language, 'english')
  into role_code, goal_code, level_code, preferred_language
  from public.profiles profile_row
  left join public.roles role_row on role_row.id = profile_row.role_id
  left join public.member_profiles member_row on member_row.user_id = profile_row.user_id
  left join public.user_preferences preferences_row on preferences_row.user_id = profile_row.user_id
  where profile_row.user_id = requester;

  perform public.sync_member_news_interests(requester);

  return query
  with aggregated_interests as (
    select
      topic_code,
      max(score) as score
    from public.user_news_interests
    where user_id = requester
    group by topic_code
  ),
  interaction_topic_rollup as (
    select
      topic_row.topic_code,
      count(*) filter (
        where interaction_row.interaction_type in ('open', 'click', 'save', 'share')
      )::numeric as positive_events,
      count(*) filter (
        where interaction_row.interaction_type in ('dismiss', 'mark_not_interested')
      )::numeric as negative_events
    from public.news_article_interactions interaction_row
    join public.news_article_topics topic_row on topic_row.article_id = interaction_row.article_id
    where interaction_row.user_id = requester
      and interaction_row.created_at >= timezone('utc', now()) - interval '120 days'
    group by topic_row.topic_code
  ),
  article_topics as (
    select
      topic_row.article_id,
      array_agg(topic_row.topic_code order by topic_row.score desc, topic_row.topic_code asc) as topic_codes,
      coalesce(sum(topic_row.score * greatest(coalesce(interest_row.score, 0), 0)), 0) as interest_alignment,
      coalesce(sum(topic_row.score * coalesce(interaction_row.positive_events, 0)), 0) as positive_alignment,
      coalesce(sum(topic_row.score * coalesce(interaction_row.negative_events, 0)), 0) as negative_alignment
    from public.news_article_topics topic_row
    left join aggregated_interests interest_row on interest_row.topic_code = topic_row.topic_code
    left join interaction_topic_rollup interaction_row on interaction_row.topic_code = topic_row.topic_code
    group by topic_row.article_id
  ),
  article_user_state as (
    select
      interaction_row.article_id,
      bool_or(interaction_row.interaction_type = 'dismiss') as dismissed,
      bool_or(interaction_row.interaction_type = 'mark_not_interested') as marked_not_interested,
      max(interaction_row.created_at) filter (
        where interaction_row.interaction_type in ('open', 'click')
      ) as last_opened_at
    from public.news_article_interactions interaction_row
    where interaction_row.user_id = requester
    group by interaction_row.article_id
  ),
  candidate_articles as (
    select
      article_row.id as article_id,
      article_row.source_id,
      source_row.name as source_name,
      source_row.base_url as source_base_url,
      article_row.canonical_url,
      article_row.title,
      article_row.summary,
      article_row.image_url,
      article_row.published_at,
      article_row.language,
      article_row.category,
      article_row.safety_level,
      article_row.evidence_level,
      article_row.trust_score,
      article_row.quality_score,
      article_row.target_goals,
      article_row.target_levels,
      coalesce(topic_rollup.topic_codes, '{}'::text[]) as topic_codes,
      coalesce(topic_rollup.interest_alignment, 0) as interest_alignment,
      coalesce(topic_rollup.positive_alignment, 0) as positive_alignment,
      coalesce(topic_rollup.negative_alignment, 0) as negative_alignment,
      coalesce(article_state.dismissed, false) as dismissed,
      coalesce(article_state.marked_not_interested, false) as marked_not_interested,
      article_state.last_opened_at,
      exists (
        select 1
        from public.news_article_bookmarks bookmark_row
        where bookmark_row.user_id = requester
          and bookmark_row.article_id = article_row.id
      ) as is_saved,
      (
        case
          when public.news_target_matches(article_row.target_roles, role_code) then 20
          else -1000
        end
        + case
            when goal_code is not null
                 and public.news_target_matches(article_row.target_goals, goal_code) then 18
            when goal_code is null then 4
            when jsonb_array_length(public.news_safe_jsonb_array(article_row.target_goals)) = 0 then 6
            else 0
          end
        + case
            when level_code is not null
                 and public.news_target_matches(article_row.target_levels, level_code) then 10
            when jsonb_array_length(public.news_safe_jsonb_array(article_row.target_levels)) = 0 then 4
            else 0
          end
        + least(coalesce(article_row.trust_score, source_row.trust_score), 100) * 0.18
        + least(coalesce(article_row.quality_score, 0), 100) * 0.12
        + greatest(
            0::numeric,
            21::numeric - extract(epoch from (timezone('utc', now()) - article_row.published_at)) / 86400
          ) * 1.10
        + least(coalesce(topic_rollup.interest_alignment, 0), 4) * 25
        + least(coalesce(topic_rollup.positive_alignment, 0), 4) * 4
        - least(coalesce(topic_rollup.negative_alignment, 0), 4) * 6
        + case
            when lower(coalesce(article_row.language, 'english')) = lower(preferred_language) then 6
            when lower(coalesce(article_row.language, 'english')) = 'english' then 3
            else 0
          end
        + case when article_row.is_featured then 4 else 0 end
        - case
            when article_state.last_opened_at is not null
                 and article_state.last_opened_at >= timezone('utc', now()) - interval '14 days' then 10
            else 0
          end
      )::numeric(10,3) as ranking_score
    from public.news_articles article_row
    join public.news_sources source_row on source_row.id = article_row.source_id
    left join article_topics topic_rollup on topic_rollup.article_id = article_row.id
    left join article_user_state article_state on article_state.article_id = article_row.id
    where article_row.is_active = true
      and article_row.safety_level <> 'restricted'
      and source_row.is_active = true
      and public.news_target_matches(article_row.target_roles, role_code)
      and coalesce(article_row.trust_score, source_row.trust_score) >= 55
      and coalesce(article_row.quality_score, 0) >= 35
  )
  select
    candidate_row.article_id,
    candidate_row.source_id,
    candidate_row.source_name,
    candidate_row.source_base_url,
    candidate_row.canonical_url,
    candidate_row.title,
    candidate_row.summary,
    candidate_row.image_url,
    candidate_row.published_at,
    candidate_row.language,
    candidate_row.category,
    candidate_row.safety_level,
    candidate_row.evidence_level,
    candidate_row.trust_score,
    candidate_row.quality_score,
    candidate_row.topic_codes,
    coalesce(
      (
        array_remove(
          array[
            case
              when goal_code is not null
                   and public.news_target_matches(candidate_row.target_goals, goal_code) then 'Matches your goal'
            end,
            case when candidate_row.interest_alignment > 0.25 then 'Aligned with your interests' end,
            case when candidate_row.positive_alignment > 0 then 'Based on what you open' end,
            case when candidate_row.quality_score >= 75 then 'Trusted, high-quality source' end,
            case
              when candidate_row.published_at >= timezone('utc', now()) - interval '7 days' then 'Fresh this week'
            end,
            case
              when level_code is not null
                   and public.news_target_matches(candidate_row.target_levels, level_code) then 'Fits your training level'
            end
          ],
          null
        )
      )[1],
      'Recommended for you'
    ) as relevance_reason,
    coalesce(
      array_remove(
        array[
          case
            when goal_code is not null
                 and public.news_target_matches(candidate_row.target_goals, goal_code) then 'goal match'
          end,
          case when candidate_row.interest_alignment > 0.25 then 'interest match' end,
          case when candidate_row.positive_alignment > 0 then 'similar to past reads' end,
          case when candidate_row.quality_score >= 75 then 'trusted source' end,
          case
            when candidate_row.published_at >= timezone('utc', now()) - interval '7 days' then 'recent'
          end,
          case
            when level_code is not null
                 and public.news_target_matches(candidate_row.target_levels, level_code) then 'level fit'
          end
        ],
        null
      ),
      '{}'::text[]
    ) as relevance_tags,
    candidate_row.ranking_score,
    candidate_row.is_saved
  from candidate_articles candidate_row
  where candidate_row.marked_not_interested = false
    and candidate_row.dismissed = false
  order by candidate_row.ranking_score desc, candidate_row.published_at desc
  limit greatest(coalesce(p_limit, 20), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke all on function public.news_safe_jsonb_array(jsonb) from public;
revoke all on function public.news_target_matches(jsonb, text) from public;
revoke all on function public.normalize_news_goal(text) from public;
revoke all on function public.normalize_news_level(text) from public;
revoke all on function public.upsert_user_news_interest(uuid, text, numeric, text) from public;
revoke all on function public.bump_user_news_interest(uuid, text, numeric, text) from public;
revoke all on function public.sync_member_news_interests(uuid) from public;

revoke all on function public.track_news_interaction(uuid, text, jsonb) from public;
grant execute on function public.track_news_interaction(uuid, text, jsonb) to authenticated;

revoke all on function public.save_news_article(uuid) from public;
grant execute on function public.save_news_article(uuid) to authenticated;

revoke all on function public.dismiss_news_article(uuid) from public;
grant execute on function public.dismiss_news_article(uuid) to authenticated;

revoke all on function public.list_news_article_topics(uuid) from public;
grant execute on function public.list_news_article_topics(uuid) to authenticated;

revoke all on function public.list_saved_news_articles() from public;
grant execute on function public.list_saved_news_articles() to authenticated;

revoke all on function public.list_personalized_news(integer, integer) from public;
grant execute on function public.list_personalized_news(integer, integer) to authenticated;
