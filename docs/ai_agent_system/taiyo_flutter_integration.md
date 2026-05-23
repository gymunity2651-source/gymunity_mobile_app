# TAIYO Flutter Integration

## Overview

The Flutter app integrates with the TAIYO AI system through Supabase Edge Function calls. The app never communicates directly with Azure AI Foundry. All AI operations go through the secure Edge Function middleware.

## Architecture

```
Flutter App (Riverpod Providers + Screens)
    ↓
Repository Layer (calls Supabase Edge Functions & RPCs)
    ↓
Supabase Edge Functions (auth + context + Azure call)
    ↓
Azure AI Foundry (Orchestrator Agent)
    ↓
Structured JSON Response
    ↓
Entity Layer (fromMap / fromTaiyoDailyBriefResponse)
    ↓
Flutter UI Cards & Screens
```

## Key Repositories

### AiCoachRepository

**Path:** `lib/features/ai_coach/domain/repositories/ai_coach_repository.dart`
**Implementation:** `lib/features/ai_coach/data/repositories/ai_coach_repository_impl.dart`

| Method | Purpose | Edge Function / RPC |
| --- | --- | --- |
| `getDailyBrief(date)` | Load cached daily brief | `member_ai_daily_briefs` table |
| `refreshDailyBrief(date)` | Generate fresh daily brief via AI | `taiyo-daily-brief` Edge Function |
| `upsertReadiness(...)` | Log daily readiness signals | `upsert_member_readiness_log` RPC |
| `applyAdjustment(...)` | Apply training adjustment | `apply_member_ai_adjustment` RPC |
| `listNudges()` | Get proactive AI nudges | `member_ai_nudges` table |
| `runAccountabilityScan()` | Trigger accountability check | `ai-coach` Edge Function |
| `maintainMemory()` | Trigger memory maintenance | `ai-coach` Edge Function |
| `getActiveWorkoutSession(id)` | Load active workout | `member_active_workout_sessions` table |
| `startActiveWorkout(...)` | Start an AI-guided workout | `start_member_active_workout` RPC |
| `recordActiveWorkoutEvent(...)` | Log workout events | `record_member_active_workout_event` RPC |
| `completeActiveWorkout(...)` | Complete workout session | `complete_member_active_workout` RPC |
| `getWorkoutPrompt(...)` | Get mid-session AI prompt | `ai-coach` Edge Function |
| `getWeeklySummary(weekStart)` | Load weekly AI summary | `member_ai_weekly_summaries` table |
| `refreshWeeklySummary(weekStart)` | Generate fresh weekly summary | `ai-coach` Edge Function |
| `shareWeeklySummary(weekStart)` | Share summary with coach | `share_member_ai_weekly_summary` RPC |

### ChatRepository

**Path:** `lib/features/ai_chat/domain/repositories/chat_repository.dart`
**Implementation:** `lib/features/ai_chat/data/repositories/chat_repository_impl.dart`

| Method | Purpose | Edge Function / RPC |
| --- | --- | --- |
| `sendMessage(...)` | Send message to TAIYO | `ai-chat` Edge Function |
| `listSessions()` | List chat sessions | `chat_sessions` table |
| `listMessages(sessionId)` | Load conversation history | `chat_messages` table |
| `createSession(...)` | Create new chat session | `chat_sessions` table |
| `deleteSession(...)` | Delete chat session | `chat_sessions` table |

### PlannerRepository

**Path:** `lib/features/planner/domain/repositories/planner_repository.dart`
**Implementation:** `lib/features/planner/data/repositories/planner_repository_impl.dart`

| Method | Purpose | Edge Function / RPC |
| --- | --- | --- |
| `generatePlanDraft(...)` | Generate AI workout plan | `taiyo-workout-planner` Edge Function |
| `activatePlan(...)` | Activate a reviewed plan draft | Supabase RPCs |

## Riverpod Providers

| Provider | Location | Purpose |
| --- | --- | --- |
| `aiCoachRepositoryProvider` | `core/di/providers.dart` | AiCoachRepository instance |
| `chatRepositoryProvider` | `core/di/providers.dart` | ChatRepository instance |
| `plannerRepositoryProvider` | `core/di/providers.dart` | PlannerRepository instance |
| `aiCoachDailyBriefProvider` | `ai_coach/presentation/providers/` | Daily brief state |
| `aiCoachNudgesProvider` | `ai_coach/presentation/providers/` | Proactive nudges state |
| `aiWeeklySummaryProvider` | `ai_coach/presentation/providers/` | Weekly summary state |
| `aiCoachReadinessControllerProvider` | `ai_coach/presentation/providers/` | Readiness form state |
| `aiCoachActionControllerProvider` | `ai_coach/presentation/providers/` | Action buttons state |
| `chatControllerProvider` | `ai_chat/presentation/providers/` | Chat conversation state |

## Key Screens

| Screen | Path | Purpose |
| --- | --- | --- |
| `AiCoachHomeScreen` | `ai_coach/presentation/screens/` | TAIYO daily coaching dashboard |
| `ActiveWorkoutSessionScreen` | `ai_coach/presentation/screens/` | AI-guided active workout |
| `AiChatHomeScreen` | `ai_chat/presentation/screens/` | Chat session list |
| `AiConversationScreen` | `ai_chat/presentation/screens/` | Individual chat conversation |
| `PlannerBuilderScreen` | `planner/presentation/screens/` | AI plan builder questionnaire |
| `AiGeneratedPlanScreen` | `planner/presentation/screens/` | Review and activate AI plan draft |
| `WorkoutPlanScreen` | `planner/presentation/screens/` | Active plan with day-by-day view |

## Entity Mapping

AI responses are mapped to typed Dart entities:

| Entity | Purpose |
| --- | --- |
| `AiDailyBriefEntity` | Daily brief with readiness, workout recommendation, nutrition, signals |
| `AiReadinessLogEntity` | Readiness log result after upsert |
| `AiPlanAdaptationEntity` | Plan adjustment result |
| `AiNudgeEntity` | Proactive nudge with action type and payload |
| `AiWeeklySummaryEntity` | Weekly summary with stats and insights |
| `ActiveWorkoutSessionEntity` | Active workout session state |
| `ChatSessionEntity` | Chat session metadata |
| `ChatMessageEntity` | Individual chat message |

## Error Handling

### Backend Unavailable Detection

The repository includes logic to detect when AI backend tables or Edge Functions are not yet deployed:

- `isMissingAiCoachSchemaError()` — catches PostgreSQL error codes (`42P01`, `42883`, `PGRST202`, `PGRST205`).
- `isAiCoachBackendUnavailableFailure()` — matches error message patterns.

### Legacy Fallback

When the `taiyo-daily-brief` Edge Function is unavailable, `_buildLegacyDailyBrief()` constructs a local daily brief from:

- Active workout plan
- Today's agenda (tasks)
- Nutrition snapshot (meal plan, hydration)
- Locally computed readiness score

This ensures the member always sees useful content, even during backend deployment gaps.

### Error Types

| Error Type | When Used |
| --- | --- |
| `AuthFailure` | No authenticated user, session expired |
| `NetworkFailure` | Edge Function call failed, timeout, rate limit |
| `AppFailure` (generic) | Unexpected errors |

## Security

- Azure API keys are never stored in Flutter code.
- All AI calls go through Supabase Edge Functions.
- Bearer token is sent to Edge Functions for authentication.
- Service role key exists only in Edge Function environment.
- Member data is accessed through RLS-scoped queries.
