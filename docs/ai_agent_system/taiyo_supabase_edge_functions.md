# TAIYO Supabase Edge Functions

## Overview

TAIYO uses Supabase Edge Functions (Deno-based) as the secure middleware between the Flutter client and Azure AI Foundry. Every Edge Function follows the same architectural pattern:

1. **Authenticate** the request (Bearer JWT or TAIYO Action Secret + Context Token).
2. **Authorize** the user's role (member, coach, seller, admin).
3. **Load context** from Supabase using RLS-safe queries.
4. **Call Azure AI Foundry** with the context and a specialized prompt.
5. **Normalize** the AI response into a strict JSON schema.
6. **Persist** the result if applicable (daily briefs, plan drafts, etc.).
7. **Return** the structured response to the caller.

## Shared Modules

| Module | Path | Purpose |
| --- | --- | --- |
| `cors.ts` | `_shared/cors.ts` | CORS headers and JSON response helper |
| `foundry.ts` | `_shared/foundry.ts` | Azure AI Foundry integration (Agents API: threads, runs, messages) |
| `taiyo_action_auth.ts` | `_shared/taiyo_action_auth.ts` | Dual auth: user JWT and Foundry Action Secret with HMAC context tokens |

## Edge Functions

### 1. `taiyo-member-context`

- **Purpose:** Build the member's daily context from Supabase data.
- **Auth:** Bearer JWT (member role) or TAIYO Action Secret.
- **Context Sources:** `get_member_ai_coach_context` RPC, `ai_user_memories`.
- **AI Call:** Optional — can return raw context without AI processing.
- **Output:** Structured member context JSON.

### 2. `taiyo-daily-brief`

- **Purpose:** Generate a personalized daily coaching brief for the member.
- **Auth:** Bearer JWT (member role).
- **Context Sources:** `get_member_ai_coach_context` RPC, active plan, today's tasks, nutrition summary.
- **AI Call:** Calls TAIYO Orchestrator with `daily_member_brief` request type.
- **Persistence:** Upserts result into `member_ai_daily_briefs`.
- **Engine:** `engine.ts` — builds `MemberDailyContext`, normalizes AI output, manages safety flags.
- **Tests:** `index_test.ts`

### 3. `taiyo-nutrition-context`

- **Purpose:** Provide nutrition data or AI-generated nutrition guidance.
- **Auth:** Bearer JWT (member role) or TAIYO Action Secret.
- **Context Sources:** `nutrition_profiles`, `nutrition_targets`, `member_meal_plans`, meal logs, hydration logs, nutrition check-ins.
- **AI Call:** Only for `nutrition_guidance` request type. Raw context returned for `nutrition_context`.
- **Tests:** `index_test.ts`

### 4. `taiyo-workout-planner`

- **Purpose:** Generate or adapt workout plan drafts.
- **Auth:** Bearer JWT (member role).
- **Context Sources:** `get_member_ai_coach_context`, `ai_user_memories`, `ai_plan_drafts`, `member_daily_readiness_logs`, `member_active_workout_sessions`.
- **AI Call:** Calls TAIYO Orchestrator with `workout_plan_draft` request type.
- **Persistence:** Saves drafts to `ai_plan_drafts`, updates `chat_sessions` with planner status.
- **Safety:** Blocks plan drafting when high-risk safety flags are present.
- **Engine:** `engine.ts` — planner context builder, normalization, persistence payloads.

### 5. `taiyo-coach-client-brief`

- **Purpose:** Generate AI-powered client insights for coaches.
- **Auth:** Bearer JWT (coach role).
- **Context Sources:** Client profile, subscription, check-ins, workout adherence, nutrition summary, visibility settings.
- **AI Call:** Calls TAIYO Orchestrator with coach-specific prompt.
- **Privacy:** Respects `coach_member_visibility_settings`. Hidden data is excluded and noted.
- **Engine:** `engine.ts` — client context builder, risk classification, message drafting.
- **Tests:** `index_test.ts`

### 6. `taiyo-store-recommendations`

- **Purpose:** Generate product recommendations based on fitness context.
- **Auth:** Bearer JWT (member role) or TAIYO Action Secret.
- **Context Sources:** Active products, member goal, nutrition gaps, purchase history, favorites, cart items.
- **AI Call:** Calls TAIYO Orchestrator with store recommendation prompt.
- **Tests:** `index_test.ts`

### 7. `taiyo-admin-ops-brief`

- **Purpose:** Generate operational summaries and risk assessments for admins.
- **Auth:** Bearer JWT (admin role).
- **Context Sources:** Payment orders, Paymob transactions, payout items, audit events, subscription state.
- **AI Call:** Calls TAIYO Orchestrator with admin ops prompt.
- **Engine:** `engine.ts` — admin context builder, risk pattern detection.
- **Tests:** `index_test.ts`

### 8. `taiyo-seller-copilot`

- **Purpose:** Generate product and order insights for sellers.
- **Auth:** Bearer JWT (seller role).
- **Context Sources:** Seller profile, product catalog, order queue, order history, revenue data.
- **AI Call:** Calls TAIYO Orchestrator with seller copilot prompt.
- **Engine:** `engine.ts` — seller context builder, product performance analysis.
- **Tests:** `index_test.ts`

### 9. `ai-chat`

- **Purpose:** Full conversational AI chat with message history and memory.
- **Auth:** Bearer JWT (member role).
- **Context Sources:** Chat sessions, messages, AI user memories, member context.
- **AI Call:** Calls TAIYO Orchestrator with full conversation context.
- **Persistence:** Saves messages to `chat_messages`, manages `chat_sessions`.
- **Engine:** `engine.ts` — message formatting, memory extraction.
- **Tests:** `engine_test.ts`

### 10. `ai-coach`

- **Purpose:** Background AI coaching operations (accountability scan, memory maintenance, weekly summaries, active workout management).
- **Auth:** Bearer JWT (member role).
- **Modes:** `run_accountability_scan`, `maintain_memory`, `refresh_weekly_summary`, `workout_prompt`.
- **Engine:** `engine.ts` — mode routing, accountability logic, memory management.
- **Tests:** `engine_test.ts`

## Authentication Patterns

### Pattern 1: User JWT (Direct Flutter Call)

```
Flutter → Edge Function
  ├── Extract Bearer token from Authorization header
  ├── Verify token via supabase.auth.getUser()
  ├── Load user role from profiles + roles
  └── Execute function with RLS-scoped queries
```

### Pattern 2: TAIYO Action Secret (Azure AI Foundry Tool Call)

```
Azure Foundry → Edge Function
  ├── Verify x-taiyo-action-secret matches TAIYO_ACTION_SECRET
  ├── Verify x-taiyo-context-token (HMAC-SHA256 signed)
  ├── Extract user identity from context token claims (sub, role, scope, exp)
  └── Execute function with service-level queries (user already verified)
```

## Environment Variables

| Variable | Required | Purpose |
| --- | --- | --- |
| `SUPABASE_URL` | Yes | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | Service role key for admin operations |
| `AZURE_FOUNDRY_PROJECT_ENDPOINT` | Yes | Azure AI Foundry project endpoint |
| `AZURE_FOUNDRY_ORCHESTRATOR_AGENT_ID` | Yes | Orchestrator agent ID |
| `AZURE_TENANT_ID` | Conditional | Azure Entra tenant (if using service principal) |
| `AZURE_CLIENT_ID` | Conditional | Azure Entra client (if using service principal) |
| `AZURE_CLIENT_SECRET` | Conditional | Azure Entra secret (if using service principal) |
| `AZURE_FOUNDRY_AGENT_TOKEN` | Conditional | Static bearer token (alternative to Entra) |
| `TAIYO_ACTION_SECRET` | Yes | Shared secret for Azure tool authentication |
| `TAIYO_CONTEXT_TOKEN_SECRET` | Yes (≥24 chars) | HMAC key for context token signing |

## Deployment

```bash
# Deploy a single function
supabase functions deploy taiyo-daily-brief

# Deploy all functions
supabase functions deploy

# Set secrets
supabase secrets set AZURE_FOUNDRY_PROJECT_ENDPOINT=... AZURE_FOUNDRY_ORCHESTRATOR_AGENT_ID=...
```
