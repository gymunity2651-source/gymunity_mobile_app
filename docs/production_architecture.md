# GymUnity Production Architecture

## Implemented foundations
- Clean architecture scaffolding across `auth`, `user`, `store`, `coach`, and `ai_chat`.
- Riverpod global DI in `lib/core/di/providers.dart`.
- Supabase bootstrapping in `lib/core/supabase/supabase_initializer.dart`.
- Route-safe auth resolution through `AuthRouteResolver`.
- Auth flow wiring for register/login/OTP/forgot password without route name changes.
- Role + onboarding persistence hooks integrated into role selection and onboarding screens.
- Store/coaches/chat screens connected to repository-backed providers with fallback demo data.

## Supabase assets
- Migration: `supabase/migrations/20260307000001_init_gymunity.sql`
- Edge Function: `supabase/functions/ai-chat/index.ts`

## Env configuration
Use `.env.example` as template and provide:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- Groq secrets live in Supabase Edge Function secrets: `GROQ_API_KEY` and optional `GROQ_MODEL`.

GymUnity runtime config is sourced from `--dart-define`, not direct `.env` reads inside Flutter. Local scripts convert `.env` into the correct define set.

## Next operational steps
1. Apply the SQL bundle in `supabase/sql/phase1_dashboard_setup.sql` through Supabase Dashboard SQL Editor.
2. Keep Email auth enabled with confirm-email turned on.
3. Use the helper scripts in `scripts/` for local run/build flows after editing `.env`.
4. Deploy `ai-chat` later when phase 2 secrets are available.

