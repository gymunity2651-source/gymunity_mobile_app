-- AI personalization memory and session state
-- Date: 2026-03-15

create table if not exists public.ai_user_memories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  memory_key text not null,
  memory_value_json jsonb not null default '{}'::jsonb,
  confidence numeric(4,3) not null default 0.800 check (
    confidence >= 0 and confidence <= 1
  ),
  source_session_id uuid references public.chat_sessions(id) on delete set null,
  source_message_id uuid references public.chat_messages(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id, memory_key)
);

create table if not exists public.ai_session_state (
  session_id uuid primary key references public.chat_sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  summary text not null default '',
  open_loops text[] not null default '{}',
  last_intent text,
  last_conversation_mode text,
  last_user_message_id uuid references public.chat_messages(id) on delete set null,
  last_assistant_message_id uuid references public.chat_messages(id) on delete set null,
  last_turn_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_ai_user_memories_user_updated
  on public.ai_user_memories(user_id, updated_at desc);

create index if not exists idx_ai_session_state_user_updated
  on public.ai_session_state(user_id, updated_at desc);

alter table public.ai_user_memories enable row level security;
alter table public.ai_session_state enable row level security;

drop policy if exists ai_user_memories_read_own on public.ai_user_memories;
create policy ai_user_memories_read_own
on public.ai_user_memories for select
to authenticated
using (user_id = auth.uid());

drop policy if exists ai_user_memories_manage_own on public.ai_user_memories;
create policy ai_user_memories_manage_own
on public.ai_user_memories for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists ai_session_state_read_own on public.ai_session_state;
create policy ai_session_state_read_own
on public.ai_session_state for select
to authenticated
using (user_id = auth.uid());

drop policy if exists ai_session_state_manage_own on public.ai_session_state;
create policy ai_session_state_manage_own
on public.ai_session_state for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop trigger if exists touch_ai_user_memories_updated_at on public.ai_user_memories;
create trigger touch_ai_user_memories_updated_at
before update on public.ai_user_memories
for each row execute function public.touch_updated_at();

drop trigger if exists touch_ai_session_state_updated_at on public.ai_session_state;
create trigger touch_ai_session_state_updated_at
before update on public.ai_session_state
for each row execute function public.touch_updated_at();
