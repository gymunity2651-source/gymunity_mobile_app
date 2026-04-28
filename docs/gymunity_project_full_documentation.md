# GymUnity Project Full Documentation

Updated on: 2026-04-27
Repository: `my_app`
Product name: `GymUnity`
AI brand: `TAIYO`
Backend: Supabase project `gymunity` (`pooelnnveljiikpdrvqw`)

This document describes the current GymUnity workspace as verified from the
repository on 2026-04-27. It replaces older 2026-04-18 live-parity statements
with a current repo-grounded view because the local project has moved forward
substantially since that earlier audit.

Sensitive values are intentionally omitted. A Supabase access token was pasted
outside the normal secret store during project work; treat it as compromised and
rotate/revoke it before any production deployment.

## Verification Legend

| Marker | Meaning |
| --- | --- |
| `[Repo]` | Verified from files in this working tree. |
| `[Docs]` | Verified from supporting docs in `docs/`. |
| `[Historical Live]` | Historical live statement from older docs, not rechecked in this pass. |
| `[Not Reverified]` | Live Supabase state was not checked during this update. |
| `[Inference]` | Reasonable conclusion from code and migrations. |

## Current Snapshot

- `[Repo]` Flutter application using Supabase as backend.
- `[Repo]` Main user-facing roles are `member`, `coach`, and `seller`.
- `[Repo]` Admin access exists separately through `app_admins`; admin is not a
  public selectable app role.
- `[Repo]` Current feature directories under `lib/features/`:
  - `admin`
  - `ai_chat`
  - `ai_coach`
  - `auth`
  - `coach`
  - `coach_member_insights`
  - `coaches`
  - `member`
  - `monetization`
  - `news`
  - `nutrition`
  - `onboarding`
  - `planner`
  - `seller`
  - `settings`
  - `store`
  - `user`
- `[Repo]` Current source inventory:
  - `229` Dart files under `lib/`
  - `41` Dart test files under `test/`
  - `38` SQL migration files under `supabase/migrations/`
  - `14` Supabase Edge Function directories plus `_shared`
  - `100` unique repo-defined table declarations from migrations
  - `145` unique repo-defined SQL function declarations from migrations
- `[Repo]` There is also a separate `remotion-chart/` project that is not part
  of the Flutter runtime.
- `[Not Reverified]` Live Supabase parity was not checked during this update.
  Older documentation referenced a live check from 2026-04-18 and a later
  linked migration check through `20260425000032`; the local repo now includes
  migrations through `20260427000038`.

## Product Scope

GymUnity is a multi-role fitness platform. The current codebase includes:

- authentication, email/OAuth callback handling, role selection, and onboarding
- member home, progress, active workout sessions, AI workout planning, TAIYO
  chat, TAIYO coach briefs, nutrition, news, store, orders, coaching
  subscriptions, messages, check-ins, and notification surfaces
- coach marketplace, public coach profiles, package publishing, client
  pipeline, client workspace, check-in inbox, calendar, billing, program
  library, onboarding flows, resources, coach profile, and consent-gated
  member insights
- seller dashboard, product management, seller order management, and seller
  profile
- admin dashboard for Paymob coach-payment settlement and payout tracking
- app-store monetization for AI premium entitlements
- account deletion and support/legal settings

## Runtime Architecture

### Startup

`lib/main.dart` stays small:

```text
WidgetsFlutterBinding.ensureInitialized()
  -> LocalRuntimeConfigLoader.primeIfNeeded()
  -> SupabaseInitializer.initialize() when AppConfig is valid
  -> runApp(ProviderScope(child: GymUnityApp()))
```

`GymUnityApp` in `lib/app/app.dart` wires:

- `AppTheme.darkTheme`
- locale from settings preferences
- auth-aware monetization bootstrap
- auth-aware planner reminder bootstrap
- splash as the initial route
- route generation through `AppRoutes.onGenerateRoute`

### Configuration

`lib/core/config/app_config.dart` reads compile-time values first and can be
overridden by `assets/config/local_env.json` through
`LocalRuntimeConfigLoader`.

Required or important environment keys:

- `APP_ENV`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `AUTH_REDIRECT_SCHEME`
- `AUTH_REDIRECT_HOST`
- `PRIVACY_POLICY_URL`
- `TERMS_OF_SERVICE_URL`
- `SUPPORT_URL`
- `SUPPORT_EMAIL`
- `SUPPORT_EMAIL_SUBJECT`
- `REVIEWER_LOGIN_HELP_URL`

Feature flags:

- `ENABLE_COACH_ROLE`
- `ENABLE_SELLER_ROLE`
- `ENABLE_APPLE_SIGN_IN`
- `ENABLE_STORE_PURCHASES`
- `ENABLE_COACH_SUBSCRIPTIONS`
- `ENABLE_COACH_PAYMOB_PAYMENTS`
- `ENABLE_COACH_MANUAL_PAYMENT_PROOFS`
- `ENABLE_AI_PREMIUM`

AI premium product identifiers:

- `APPLE_AI_PREMIUM_MONTHLY_PRODUCT_ID`
- `APPLE_AI_PREMIUM_ANNUAL_PRODUCT_ID`
- `GOOGLE_AI_PREMIUM_SUBSCRIPTION_ID`
- `GOOGLE_AI_PREMIUM_MONTHLY_BASE_PLAN_ID`
- `GOOGLE_AI_PREMIUM_ANNUAL_BASE_PLAN_ID`

Paymob credentials and server-only configuration are Edge Function secrets, not
Flutter dart-defines:

- `PAYMOB_MODE`
- `PAYMOB_API_BASE_URL`
- `PAYMOB_MERCHANT_ID`
- `PAYMOB_TEST_INTEGRATION_IDS`
- `PAYMOB_CURRENCY`
- `PAYMOB_PUBLIC_KEY_TEST`
- `PAYMOB_SECRET_KEY_TEST`
- `PAYMOB_HMAC_SECRET_TEST`
- `PAYMOB_NOTIFICATION_URL`
- `APP_PUBLIC_PAYMENT_REDIRECT_URL`
- `GYMUNITY_PLATFORM_FEE_BPS`
- `GYMUNITY_PAYOUT_HOLD_DAYS`

### Supabase Initialization

`lib/core/supabase/supabase_initializer.dart`:

- validates `AppConfig`
- initializes `Supabase` with `detectSessionInUri: false`
- checks persisted auth tokens against the configured Supabase project ref
- signs out locally when a persisted session belongs to another project

`AuthDeepLinkBootstrap`, `PlatformAuthCallbackIngress`, and
`AuthCallbackUtils` handle callback ingress through Android native channels,
`app_links`, and normalized callback route names such as `/?code=...`.

## Dependency Injection

Global providers live in `lib/core/di/providers.dart`.

| Provider | Purpose |
| --- | --- |
| `supabaseClientProvider` | exposes initialized Supabase client |
| `authCallbackIngressProvider` | exposes native/app-links callback ingress |
| `authRepositoryProvider` | auth repository |
| `userRepositoryProvider` | profile, role, preferences, account status |
| `adminRepositoryProvider` | admin dashboard and Paymob settlement RPCs/functions |
| `storeRepositoryProvider` | storefront, cart, checkout, orders |
| `coachRepositoryProvider` | coach marketplace/workspace/client tools |
| `coachPaymentRepositoryProvider` | Paymob checkout and payment order status |
| `memberRepositoryProvider` | member home, progress, subscriptions, messages |
| `plannerRepositoryProvider` | AI workout plan drafts, activation, reminders |
| `sellerRepositoryProvider` | seller profile, products, orders |
| `billingRepositoryProvider` | local app-store purchase APIs |
| `entitlementRepositoryProvider` | backend premium entitlement sync |
| `chatRepositoryProvider` | TAIYO chat and planner chat |
| `aiCoachRepositoryProvider` | TAIYO coach daily brief, readiness, active workout, weekly summary |
| `newsRepositoryProvider` | personalized news |
| `nutritionRepositoryProvider` | nutrition profile, targets, meal plans, logs |
| `coachMemberInsightsRepositoryProvider` | consent-gated coach/member insights |

## Navigation

Routing is in `lib/app/routes.dart` using `MaterialPageRoute` and a manual
`onGenerateRoute` switch. It does not use `go_router`.

### Auth and Onboarding

| Route | Screen |
| --- | --- |
| `/` | `SplashScreen` |
| `/welcome` | `WelcomeScreen` |
| `/login` | `LoginScreen` |
| `/register` | `RegisterScreen` |
| `/forgot-password` | `ForgotPasswordScreen` |
| `/reset-password` | `ResetPasswordScreen` |
| `/otp` | `OtpScreen` |
| `/auth-callback` | `AuthCallbackScreen` |
| `/role-selection` | `RoleSelectionScreen` |
| `/member-onboarding` | `MemberOnboardingScreen` |
| `/coach-onboarding` | `CoachOnboardingScreen` |
| `/seller-onboarding` | `SellerOnboardingScreen` |

### Member, AI, Nutrition, and News

| Route | Screen |
| --- | --- |
| `/member-home` | `MemberHomeScreen` |
| `/member-profile` | `MemberProfileScreen` |
| `/edit-profile` | `EditProfileScreen` |
| `/progress` | `ProgressScreen` |
| `/workout-plan` | `WorkoutPlanScreen` |
| `/workout-details` | `WorkoutDayDetailsScreen` |
| `/ai-chat-home` | `AiChatHomeScreen` |
| `/ai-conversation` | `AiConversationScreen` |
| `/ai-planner-builder` | `PlannerBuilderScreen` |
| `/ai-generated-plan` | `AiGeneratedPlanScreen` |
| `/active-workout-session` | `ActiveWorkoutSessionScreen` |
| `/ai-premium` | `AiPremiumPaywallScreen` |
| `/subscription-management` | `SubscriptionManagementScreen` |
| `/nutrition` | `NutritionHomeScreen` |
| `/nutrition-setup` | `NutritionSetupScreen` |
| `/nutrition-meal-plan` | `MealPlanScreen` |
| `/nutrition-preferences` | `NutritionPreferencesScreen` |
| `/nutrition-insights` | `NutritionInsightsScreen` |
| `/news-feed` | `NewsFeedScreen` |
| `/news-article-details` | `NewsArticleDetailsScreen` |

### Store and Seller

| Route | Screen |
| --- | --- |
| `/store-home` | `StoreHomeScreen` |
| `/product-list` | `StoreCatalogScreen` |
| `/product-details` | `ProductDetailsScreen` |
| `/favorites` | `FavoritesScreen` |
| `/cart` | `CartScreen` |
| `/checkout` | `CheckoutScreen` |
| `/orders` | `MyOrdersScreen` |
| `/seller-dashboard` | `SellerDashboardScreen` |
| `/product-management` | `SellerProductManagementScreen` |
| `/add-product` | `SellerProductEditorScreen` |
| `/edit-product` | `SellerProductEditorScreen` |
| `/seller-orders` | `SellerOrdersScreen` |
| `/seller-profile` | `SellerProfileScreen` |

### Coach, Coaching Relationship, and Admin

| Route | Screen |
| --- | --- |
| `/coaches` | `CoachesScreen` |
| `/coach-details` | `CoachDetailsScreen` |
| `/subscription-packages` | `SubscriptionPackagesScreen` |
| `/my-subscriptions` | `MySubscriptionsScreen` |
| `/member-checkins` | `MemberCheckinsScreen` |
| `/member-messages` | `MemberMessagesScreen` |
| `/member-thread` | `MemberThreadScreen` |
| `/coach-dashboard` | `CoachDashboardScreen` |
| `/clients` | `CoachClientPipelineScreen` |
| `/coach-client-workspace` | `CoachClientWorkspaceScreen` |
| `/coach-checkins` | `CoachCheckinInboxScreen` |
| `/coach-calendar` | `CoachCalendarScreen` |
| `/coach-billing` | `CoachBillingScreen` |
| `/coach-program-library` | `CoachProgramLibraryScreen` |
| `/coach-onboarding-flows` | `CoachOnboardingFlowsScreen` |
| `/coach-resources` | `CoachResourcesScreen` |
| `/packages` | `CoachPackagesScreen` |
| `/add-package` | `CoachPackageEditorScreen` |
| `/coach-profile` | `CoachProfileScreen` |
| `/coach-member-insights` | `CoachMemberInsightsScreen` |
| `/member-coach-visibility` | `MemberCoachVisibilitySettingsScreen` |
| `/admin-dashboard` | `AdminAccessGate` -> `AdminDashboardScreen` |

### Settings

| Route | Screen |
| --- | --- |
| `/notifications` | `NotificationsScreen` |
| `/settings` | `SettingsScreen` |
| `/delete-account` | `DeleteAccountScreen` |
| `/help-support` | `HelpSupportScreen` |
| `/privacy-policy` | `PrivacyPolicyScreen` |
| `/terms` | `TermsScreen` |

## Feature Systems

### Auth and Role Resolution

`AppBootstrapController` drives startup:

```text
SplashScreen
  -> validate AppConfig
  -> initialize Supabase
  -> start auth callback ingress
  -> load current user
  -> check account status
  -> AuthRouteResolver
  -> welcome / role-selection / onboarding / dashboard
```

Role-to-dashboard mapping:

- `member` -> `/member-home`
- `coach` -> `/coach-dashboard`
- `seller` -> `/seller-dashboard`

Admin access is separate. `/admin-dashboard` checks `app_admins` and admin RPC
permissions instead of `profiles.role`.

### Member Operating System

Member features include:

- profile and progress metrics
- home summary cards and daily streak
- AI workout plan builder and active plan review
- active workout session tracking
- TAIYO chat and AI coach surfaces
- nutrition setup, targets, generated meal plans, planned meals, meal logs,
  hydration, and insights
- coach discovery and coaching subscriptions
- member coaching messages and weekly check-ins
- visibility settings for coach insight sharing
- store cart, checkout, favorites, and order history
- news feed, saved articles, dismissals, and interaction tracking

### TAIYO Chat and Planner

`ai_chat` covers chat sessions/messages and AI planner chat.

Backend anchors:

- `chat_sessions`
- `chat_messages`
- `ai_user_memories`
- `ai_session_state`
- `ai_plan_drafts`
- `activate_ai_workout_plan(...)`
- `workout_plans`
- `workout_plan_days`
- `workout_plan_tasks`
- `workout_task_logs`
- `ai-chat` Edge Function

Planner activation is server-side through SQL RPCs rather than client-side row
fan-out.

### TAIYO Coach

`ai_coach` adds a higher-level member coaching layer:

- readiness logs
- daily brief
- AI nudges
- plan adaptations
- active workout sessions and events
- weekly summaries
- weekly summary sharing
- fallback brief generation when the latest backend is missing

Backend anchors include:

- `member_daily_readiness_logs`
- `member_ai_daily_briefs`
- `member_ai_nudges`
- `member_ai_plan_adaptations`
- `member_active_workout_sessions`
- `member_active_workout_events`
- `member_ai_weekly_summaries`
- `get_member_ai_coach_context(...)`
- `upsert_member_readiness_log(...)`
- `apply_member_ai_adjustment(...)`
- `start_member_active_workout(...)`
- `record_member_active_workout_event(...)`
- `complete_member_active_workout(...)`
- `share_member_ai_weekly_summary(...)`
- `build_member_ai_weekly_summary(...)`
- `ai-coach` Edge Function

### Coach Marketplace and Relationship Core

The coach/client relationship is anchored by `subscriptions`.

Happy path:

```text
coach publishes package
  -> member opens coach/package
  -> member starts checkout
  -> payment creates subscription/payment order
  -> verified payment activates subscription
  -> ensure_coach_member_thread
  -> messages/check-ins/client workspace unlock
```

Important tables:

- `coach_profiles`
- `coach_packages`
- `coach_availability_slots`
- `coach_reviews`
- `subscriptions`
- `coach_checkout_requests`
- `coach_payment_receipts`
- `coach_payment_audit_events`
- `coach_member_threads`
- `coach_messages`
- `weekly_checkins`
- `progress_photos`

Important RPCs:

- `list_coach_directory(...)`
- `list_coach_directory_v2(...)`
- `get_coach_public_profile(...)`
- `list_coach_public_packages(...)`
- `list_coach_public_reviews(...)`
- `request_coach_subscription(...)`
- `create_coach_checkout(...)`
- `confirm_coach_payment(...)`
- `verify_coach_payment(...)`
- `fail_coach_payment(...)`
- `ensure_coach_member_thread(...)`
- `send_coaching_message(...)`
- `submit_weekly_checkin(...)`
- `submit_coach_checkin_feedback(...)`
- `list_member_subscriptions_detailed()`
- `list_member_subscriptions_live()`

Current hardening notes:

- `[Repo]` Migration `20260426000033_coach_relationship_core_hardening.sql`
  adds active-only checks for ordinary messages, weekly check-ins, and coach
  check-in feedback.
- `[Repo]` Ordinary coach/member messages go through
  `send_coaching_message(...)`, which infers sender role server-side.
- `[Repo]` Direct authenticated insert into `coach_messages` was replaced by
  the RPC path in the hardened relationship flow.
- `[Docs]` Paused relationships are intended to be read-only for messages and
  check-ins.

### Coach Workspace

Coach workspace features include:

- dashboard summary
- action items
- client pipeline
- per-client workspace
- private coach notes and CRM records
- thread read markers
- program templates and exercise library
- habit assignment
- resources and resource assignment
- onboarding flow templates
- session types and calendar bookings
- billing/payment queue

Important tables:

- `coach_client_records`
- `coach_client_notes`
- `coach_automation_events`
- `coach_thread_reads`
- `coach_program_templates`
- `coach_exercise_library`
- `member_habit_assignments`
- `member_habit_logs`
- `coach_resources`
- `coach_resource_assignments`
- `coach_onboarding_templates`
- `coach_onboarding_applications`
- `coach_session_types`
- `coach_bookings`

Important RPCs:

- `coach_workspace_summary()`
- `list_coach_action_items()`
- `dismiss_coach_action_item(...)`
- `list_coach_client_pipeline(...)`
- `get_coach_client_workspace(...)`
- `upsert_coach_client_record(...)`
- `add_coach_client_note(...)`
- `mark_coach_thread_read(...)`
- `list_coach_program_templates(...)`
- `save_coach_program_template(...)`
- `assign_program_template_to_client(...)`
- `list_coach_exercises(...)`
- `save_coach_exercise(...)`
- `assign_client_habits(...)`
- `list_coach_onboarding_templates(...)`
- `save_coach_onboarding_template(...)`
- `apply_coach_onboarding_flow(...)`
- `list_coach_session_types(...)`
- `save_coach_session_type(...)`
- `list_coach_bookable_slots(...)`
- `create_coach_booking(...)`
- `list_coach_bookings(...)`
- `update_coach_booking_status(...)`
- `list_coach_resources(...)`
- `save_coach_resource(...)`
- `assign_resource_to_client(...)`

Known product gaps from the latest discovery:

- `[Docs]` Member-facing resource consumption screen was not found.
- `[Docs]` Member-facing booking/session screen was not found.
- `[Docs]` Coach-assigned habits have backend and coach assignment support, but
  a complete member habit tracking UI was not found.

### Paymob Coach Payments

Paymob support is test-mode only in the current repo.

Primary functions:

- `create-coach-paymob-checkout`
- `paymob-transaction-callback`
- `paymob-payment-response`
- `sync-paymob-payment-status`
- `admin-payment-settings`

Payment tables:

- `coach_payment_orders`
- `coach_payment_transactions`
- `coach_payout_accounts`
- `coach_payouts`
- `coach_payout_items`
- `admin_audit_events`
- `app_admins`

Paymob flow:

```text
member starts Paymob checkout
  -> create-coach-paymob-checkout
  -> subscription status checkout_pending
  -> coach_payment_orders row created
  -> Paymob hosted checkout
  -> paymob-transaction-callback verifies HMAC
  -> process_coach_paymob_callback_as_service
  -> process_coach_paymob_callback
  -> payment order paid/failed
  -> paid order activates subscription
  -> thread created
  -> pending coach payout item created
```

Important constraints:

- `[Docs]` Test mode only.
- `[Docs]` Online Card is the MVP payment method.
- `[Docs]` GymUnity receives funds first.
- `[Docs]` No automatic coach payout.
- `[Docs]` No Paymob split payments.
- `[Docs]` No live payments yet.
- `[Docs]` Refund and dispute automation are not implemented.
- `[Repo]` Flutter hides legacy approve/fail actions for Paymob-backed rows.
- `[Repo]` `ENABLE_COACH_PAYMOB_PAYMENTS=true` selects the Paymob path.
- `[Repo]` `ENABLE_COACH_MANUAL_PAYMENT_PROOFS=false` hides the legacy proof
  flow for the Paymob MVP.

### Admin Settlement

Admin is implemented as a restricted route and backend permission model.

Admin roles:

- `super_admin`
- `finance_admin`
- `support_admin`

Admin dashboard capabilities:

- view dashboard KPIs and alerts
- list Paymob payment orders
- inspect payment order details
- list subscriptions and thread state
- list coach balances
- list payout batches/items
- mark payout ready, processing, paid, failed, held, released, or cancelled
- add payment notes
- mark payment needs review
- cancel unpaid checkout
- reconcile payment order
- repair missing subscription thread
- view audit events
- view safe Paymob settings snapshot through Edge Function

Important RPCs:

- `current_admin()`
- `admin_dashboard_summary()`
- `admin_list_payment_orders(...)`
- `admin_get_payment_order_details(...)`
- `admin_list_payouts(...)`
- `admin_get_payout_details(...)`
- `admin_list_coach_balances(...)`
- `admin_get_coach_settlement_details(...)`
- `admin_list_subscriptions(...)`
- `admin_mark_payout_ready(...)`
- `admin_mark_payout_processing(...)`
- `admin_mark_payout_paid(...)`
- `admin_mark_payout_failed(...)`
- `admin_hold_payout(...)`
- `admin_release_payout(...)`
- `admin_cancel_payout(...)`
- `admin_add_payment_note(...)`
- `admin_mark_payment_needs_review(...)`
- `admin_cancel_unpaid_checkout(...)`
- `admin_reconcile_payment_order(...)`
- `admin_ensure_subscription_thread(...)`
- `admin_list_audit_events(...)`
- `admin_verify_coach_payout_account(...)`

### Privacy-First Coach/Member Insights

The insight system is member-controlled. Coaches only receive consented
aggregate data for active subscriptions they own.

Tables:

- `coach_member_visibility_settings`
- `coach_member_visibility_audit`
- `member_product_recommendations`

RPCs:

- `upsert_coach_member_visibility(...)`
- `get_member_visibility_settings(...)`
- `get_coach_member_insight(...)`
- `list_coach_member_insight_summaries()`
- `list_visibility_audit(...)`

Visibility categories include progress metrics, nutrition summary, AI summary,
store activity, and product recommendation context. Defaults are off at the
database layer.

### Nutrition

Nutrition includes:

- setup questionnaire
- nutrition profile
- calorie and macro target calculation
- generated meal plans
- planned meals
- quick meal logging
- hydration logging
- check-ins
- insights

Tables:

- `nutrition_profiles`
- `nutrition_targets`
- `nutrition_meal_templates`
- `member_meal_plans`
- `member_meal_plan_days`
- `member_planned_meals`
- `meal_logs`
- `hydration_logs`
- `nutrition_checkins`

### Store and Orders

Store features include product browsing, favorites, cart, checkout preview, and
member order history. Seller features include profile, product management, and
seller order management.

Tables:

- `products`
- `product_favorites`
- `store_carts`
- `store_cart_items`
- `shipping_addresses`
- `orders`
- `order_items`
- `order_status_history`
- `store_checkout_requests`

Important RPCs:

- `create_store_order(...)`
- `update_store_order_status(...)`
- `list_member_orders_detailed()`
- `list_seller_orders_detailed()`
- `seller_dashboard_summary()`

### News

News includes RSS ingestion, classification, personalization, tracking,
bookmarks, and dismissals.

Tables:

- `news_sources`
- `news_articles`
- `news_article_topics`
- `user_news_interests`
- `news_article_interactions`
- `news_article_bookmarks`
- `private.news_scheduler_config`

Functions and RPCs:

- `sync-news-feeds` Edge Function
- `list_personalized_news(...)`
- `track_news_interaction(...)`
- `save_news_article(...)`
- `dismiss_news_article(...)`
- `list_news_article_topics(...)`
- `list_saved_news_articles()`
- scheduler helpers under `private`

### Monetization

AI premium monetization uses app-store purchase listeners and backend
entitlements.

Tables:

- `billing_products`
- `billing_customers`
- `store_transactions`
- `subscription_entitlements`
- `billing_sync_events`

Edge Functions:

- `billing-verify-apple`
- `billing-verify-google`
- `billing-refresh-entitlement`
- `billing-apple-notifications`
- `billing-google-rtdn`

### Account Deletion

Account deletion uses:

- `delete-account` Edge Function
- `soft_delete_account(...)`
- `prepare_account_for_hard_delete(...)`

The app checks deleted-like account states during bootstrap and logs out locally.

## Supabase Schema Overview

### Migrations

The migration chain currently runs from:

- `20260307000001_init_gymunity.sql`
- through `20260427000038_paymob_callback_service_role_wrapper.sql`

The most recent high-impact migrations are:

- `20260421000018_coach_workspace_crm.sql`
- `20260421000019_coach_program_delivery.sql`
- `20260421000020_coach_onboarding_resources.sql`
- `20260421000021_coach_calendar_booking.sql`
- `20260421000022_coach_billing_verification.sql`
- `20260421000023_coach_public_profile_conversion.sql`
- `20260421000024_taiyo_member_os.sql`
- `20260422000025_member_daily_streak.sql`
- `20260426000033_coach_relationship_core_hardening.sql`
- `20260426000034_coach_paymob_test_payments.sql`
- `20260426000035_admin_coach_payment_settlement_dashboard.sql`
- `20260426000036_paymob_test_mode_configuration_hardening.sql`
- `20260426000037_fix_admin_dashboard_summary_and_mobile_nav.sql`
- `20260427000038_paymob_callback_service_role_wrapper.sql`

### Edge Functions

Repo-defined Edge Function directories:

- `admin-payment-settings`
- `ai-chat`
- `ai-coach`
- `billing-apple-notifications`
- `billing-google-rtdn`
- `billing-refresh-entitlement`
- `billing-verify-apple`
- `billing-verify-google`
- `create-coach-paymob-checkout`
- `delete-account`
- `paymob-payment-response`
- `paymob-transaction-callback`
- `sync-news-feeds`
- `sync-paymob-payment-status`
- `_shared`

### Storage Buckets

Repo-defined storage buckets and intended access:

| Bucket | Public | Purpose |
| --- | --- | --- |
| `avatars` | no | user/profile avatars with owner-style access |
| `product-images` | yes | seller product images |
| `coach-resources` | no | coach-created resources assigned to clients |
| `coach-payment-receipts` | no | legacy manual payment proof uploads |

`progress_photos` stores file paths, but no separate dedicated
`progress-photos` bucket is defined in the current migration set. Treat progress
photo upload/storage parity as a risk until product storage policy is finalized.

## Testing

`test/` currently contains `41` Dart test files.

Coverage areas include:

- auth route resolution and auth callback parsing
- auth token project-ref matching
- onboarding behavior
- member home shell/content summaries
- member repository behavior
- AI chat and AI coach screens/providers/repositories
- planner question factory, planner UI, reminders, generated plan review,
  workout plan/day details, and active workout session
- news model, card, and feed behavior
- coach repository and coach workspace widgets
- coach/member insight and visibility entities
- Paymob coach payment entities
- admin dashboard
- delete account screen
- welcome/widget smoke tests

Known lighter areas:

- full Paymob Edge Function execution and webhook E2E
- SQL/RLS test automation around admin settlement
- member-facing consumption of coach resources/bookings/habits
- live Supabase parity tests
- production app-store billing E2E

Supporting SQL/manual artifacts:

- `supabase/sql/coach_relationship_core_audit.sql`
- `supabase/sql/coach_relationship_core_smoke_test.sql`
- `supabase/sql/paymob_coach_payments_smoke_test.sql`
- `docs/paymob_test_mode_setup.md`
- `docs/paymob_coach_payments_test_mode.md`
- `docs/admin_coach_payment_settlement.md`
- `docs/coach_client_relationship_full_discovery.txt`

## Repo vs Live Parity

Current local repo is ahead of the last documented live checks.

Known facts:

- `[Historical Live]` An older 2026-04-18 audit saw only a smaller set of live
  functions and tables.
- `[Docs]` A 2026-04-26 parity audit stated the linked remote migration list
  was visible through `20260425000032` before the new hardening migration.
- `[Repo]` The local repo now includes migrations through
  `20260427000038`.
- `[Not Reverified]` This update did not run Supabase CLI/API checks against
  the linked project.

Therefore, treat these as not live-confirmed until a fresh deployment/parity
audit is run:

- migration `20260426000033` relationship hardening
- migration `20260426000034` Paymob test payments
- migration `20260426000035` admin settlement dashboard
- migration `20260426000036` Paymob configuration hardening
- migration `20260426000037` admin dashboard/mobile-nav fix
- migration `20260427000038` service-role wrapper for Paymob callback
- Paymob Edge Functions
- admin Edge Function
- any live function secret configuration

## Main Risks and Next Actions

1. Rotate the pasted Supabase access token before deployment.
2. Run a fresh live Supabase parity audit for migrations, functions, buckets,
   secrets, and RLS before enabling Paymob broadly.
3. Deploy and verify Paymob test-mode functions in the documented order.
4. Run an end-to-end Paymob test payment and confirm:
   - `coach_payment_orders.status = paid`
   - `subscriptions.status = active`
   - `subscriptions.checkout_status = paid`
   - exactly one `coach_member_threads` row exists
   - one `coach_payout_items` row exists
   - member and coach can send messages
   - admin dashboard shows payment/payout state
5. Decide whether coach-assigned programs, habits, resources, and bookings are
   allowed before payment activation; enforce the decision consistently.
6. Add or hide member-facing destinations for coach resources, session bookings,
   and coach-assigned habit tracking.
7. Define paused subscription behavior across messages, check-ins, bookings,
   resources, programs, and insights.
8. Define refund/dispute/live-mode Paymob behavior before using real payments.
9. Decide and implement progress photo storage bucket/policy before relying on
   photo uploads.
10. Add deeper SQL/Edge Function tests for Paymob callback idempotency, invalid
    HMAC, amount mismatch, duplicate webhook, paid-without-thread repair, and
    admin payout state transitions.

## Mental Model

GymUnity is now best understood as four connected systems:

1. Member OS: fitness plan, active workouts, TAIYO, nutrition, news, store, and
   personal progress.
2. Coaching marketplace and relationship layer: discovery, paid subscription,
   active thread, check-ins, privacy controls, and client workspace.
3. Coach business tools: packages, clients, programs, resources, calendar,
   onboarding flows, billing queue, and payouts.
4. Operations/admin: Paymob test-mode payment verification, manual settlement,
   audit events, and live-readiness controls.

The local repository is functionally much broader than the older technical
reference. The most important operational truth is that backend deployment
parity must be verified before treating the Paymob, admin, and latest coaching
relationship changes as live-ready.

## Detailed Engineering Inventory

This section is intentionally more granular than the summary above. It is meant
to answer "where is the code, what owns what, and what depends on what" without
requiring a new search through the project.

### Flutter and Package Stack

`pubspec.yaml` declares:

| Area | Packages |
| --- | --- |
| Flutter runtime | `flutter`, `flutter_localizations`, `cupertino_icons` |
| Backend/client | `supabase_flutter` |
| State management | `flutter_riverpod` |
| Deep links | `app_links` |
| External URLs | `url_launcher` |
| Media and uploads | `image_picker`, `file_picker`, `image` |
| UI/chart helpers | `google_fonts`, `smooth_page_indicator`, `fl_chart`, `animations` |
| Store billing | `in_app_purchase`, `in_app_purchase_android`, `in_app_purchase_storekit` |
| Notifications/timezone | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| Serialization annotations | `freezed_annotation`, `json_annotation` |
| Dev/codegen | `flutter_test`, `flutter_lints`, `flutter_launcher_icons`, `build_runner`, `freezed`, `json_serializable` |

Declared assets:

- `assets/images/`
- `assets/config/`
- `backgrounds/`

### Source Counts by Area

Feature file counts:

| Feature | Dart files |
| --- | ---: |
| `admin` | 5 |
| `ai_chat` | 10 |
| `ai_coach` | 6 |
| `auth` | 21 |
| `coach` | 25 |
| `coach_member_insights` | 8 |
| `coaches` | 4 |
| `member` | 16 |
| `monetization` | 9 |
| `news` | 11 |
| `nutrition` | 17 |
| `onboarding` | 4 |
| `planner` | 15 |
| `seller` | 9 |
| `settings` | 5 |
| `store` | 18 |
| `user` | 11 |

Core file counts:

| Core area | Dart files | Responsibility |
| --- | ---: | --- |
| `config` | 2 | app config and local runtime config loader |
| `constants` | 6 | app strings, colors, sizing, auth, branding |
| `di` | 1 | global Riverpod dependency graph |
| `error` | 1 | typed failure model |
| `result` | 2 | `Result` and `Paged` wrappers |
| `routing` | 1 | auth-aware initial route resolver |
| `services` | 1 | external link opener |
| `supabase` | 5 | initialization, callback ingress, callback utils, token project-ref guard |
| `theme` | 4 | root theme, page transitions, motion, atelier palette |
| `utils` | 1 | historical record normalization |
| `widgets` | 8 | shared buttons, fields, backgrounds, placeholders, social buttons |

## Feature Module Details

### `admin`

Purpose:

- expose a restricted operational dashboard for Paymob test-mode coach payments
- support manual payout settlement by GymUnity admins
- keep raw Paymob payload visibility limited to super admins

Key files:

- `lib/features/admin/domain/entities/admin_entities.dart`
- `lib/features/admin/domain/repositories/admin_repository.dart`
- `lib/features/admin/data/repositories/admin_repository_impl.dart`
- `lib/features/admin/presentation/providers/admin_providers.dart`
- `lib/features/admin/presentation/screens/admin_dashboard_screen.dart`

Entities:

- `AdminUserEntity`
- `AdminDashboardSummaryEntity`
- `AdminPaymentOrderEntity`
- `AdminPaymentTransactionEntity`
- `AdminPayoutEntity`
- `AdminPayoutItemEntity`
- `AdminCoachBalanceEntity`
- `AdminSubscriptionEntity`
- `AdminAuditEventEntity`
- `AdminSettingsEntity`

Repository contract:

- `getCurrentAdmin()`
- `getDashboardSummary()`
- `listPaymentOrders(status, search)`
- `getPaymentOrderDetails(paymentOrderId)`
- `listPayouts(status, search)`
- `getPayoutDetails(payoutId)`
- `listCoachBalances(search)`
- `listSubscriptions(status, search)`
- `listAuditEvents(action, targetType, limit)`
- `getSettings()`
- `markPayoutReady(payoutId, note)`
- `holdPayout(payoutId, reason)`
- `releasePayout(payoutId, note)`
- `markPayoutProcessing(payoutId, note)`
- `markPayoutPaid(payoutId, externalReference, transferMethod, note)`
- `markPayoutFailed(payoutId, reason)`
- `cancelPayout(payoutId, reason)`
- `reconcilePaymentOrder(paymentOrderId)`
- `markPaymentNeedsReview(paymentOrderId, reason)`
- `cancelUnpaidCheckout(paymentOrderId, reason)`
- `ensureSubscriptionThread(subscriptionId)`
- `verifyCoachPayoutAccount(coachId, method, accountLastFour, note)`

UI structure:

- access gate checks auth session and `currentAdminProvider`
- dashboard shell has mobile navigation
- sections: overview, payments, payouts, coaches, subscriptions, audit, settings
- detail sheets exist for payment order and payout details

Backend dependencies:

- admin RPCs from migration `20260426000035_admin_coach_payment_settlement_dashboard.sql`
- `admin-payment-settings` Edge Function for safe settings visibility
- `app_admins`, `admin_audit_events`, `coach_payment_orders`,
  `coach_payment_transactions`, `coach_payouts`, `coach_payout_items`,
  `coach_payout_accounts`

### `auth`

Purpose:

- registration, login, OAuth, OTP, password reset, account deletion entry, and
  startup bootstrap

Key files:

- `auth_remote_data_source.dart`
- `auth_repository_impl.dart`
- `auth_controller.dart`
- `google_oauth_controller.dart`
- `app_bootstrap_controller.dart`
- auth screens under `presentation/screens`
- auth helper widgets under `presentation/widgets`

Repository contract:

- `register(email, password, fullName)`
- `login(email, password)`
- `signInWithOAuth(provider)`
- `sendOtp(email, mode)`
- `requestPasswordReset(email)`
- `updatePassword(newPassword)`
- `getCurrentAuthProvider()`
- `deleteAccount(currentPassword)`
- `verifyOtp(email, token, mode)`
- `watchSession()`
- `logout()`

Important runtime details:

- OAuth callbacks are normalized before routing.
- Password recovery uses the same callback infrastructure as OAuth.
- Account deletion calls the `delete-account` Edge Function.
- Splash is the only startup gate; dashboards are not selected directly at app
  launch.

### `user`

Purpose:

- bridge Supabase auth user to app user/profile data
- own role, onboarding completion, account status, profile avatar, shared
  profile details

Entities:

- `UserEntity`
- `ProfileEntity`
- `ProfileModel`
- `AppRole`
- `AccountStatus`

Repository contract:

- `getCurrentUser()`
- `getAccountStatus(userId)`
- `getProfile()`
- `ensureUserAndProfile(userId, email, fullName)`
- `saveRole(role)`
- `completeOnboarding()`
- `updateProfileDetails(fullName, phone, country, avatarPath)`
- `uploadAvatar(bytes, fileExtension)`

Important backend anchors:

- `users`
- `profiles`
- `roles`
- `avatars` storage bucket

### `member`

Purpose:

- member dashboard, profile, preferences, progress tracking, subscriptions,
  coaching threads, weekly check-ins, orders, daily streak, and home summary

Entities:

- `MemberProfileEntity`
- `UserPreferencesEntity`
- `WeightEntryEntity`
- `BodyMeasurementEntity`
- `WorkoutSessionEntity`
- `WeeklyCheckinEntity`
- `CoachingThreadEntity`
- `CoachingMessageEntity`
- `CoachingEngagementEntity`
- `MemberHomeSummaryEntity`
- `MemberDailyStreakEntity`

Repository contract:

- `getMemberProfile()`
- `upsertMemberProfile(...)`
- `getPreferences()`
- `upsertPreferences(preferences)`
- `listWeightEntries()`
- `saveWeightEntry(...)`
- `deleteWeightEntry(entryId)`
- `listBodyMeasurements()`
- `saveBodyMeasurement(...)`
- `deleteBodyMeasurement(entryId)`
- `listWorkoutPlans()`
- `listWorkoutSessions()`
- `saveWorkoutSession(...)`
- `deleteWorkoutSession(sessionId)`
- `listSubscriptions()`
- `confirmCoachPayment(subscriptionId, paymentReference)`
- `uploadCoachPaymentReceipt(...)`
- `submitCoachPaymentReceipt(...)`
- `pauseSubscription(subscriptionId, reason)`
- `listCoachingThreads()`
- `listCoachingMessages(threadId)`
- `sendCoachingMessage(threadId, content)`
- `listWeeklyCheckins(subscriptionId)`
- `submitWeeklyCheckin(...)`
- `listOrders()`
- `recordDailyActivity(activityDate, source)`
- `getHomeSummary()`

Important screens:

- `MemberHomeScreen`
- `MemberHomeContent`
- `MemberProfileScreen`
- `EditProfileScreen`
- `ProgressScreen`
- `MySubscriptionsScreen`
- `MemberMessagesScreen`
- `MemberThreadScreen`
- `MemberCheckinsScreen`

Important backend anchors:

- `member_profiles`
- `user_preferences`
- `member_weight_entries`
- `member_body_measurements`
- `workout_sessions`
- `subscriptions`
- `coach_member_threads`
- `coach_messages`
- `weekly_checkins`
- `progress_photos`
- `member_daily_readiness_logs`
- `member_active_workout_sessions`
- `member_active_workout_events`
- `orders`
- `notifications`

### `coach` and `coaches`

`coaches` is member-side discovery. `coach` is logged-in coach operations.

Marketplace capabilities:

- list coaches with filters
- search locally after remote list
- view coach details
- list packages and reviews
- start subscription checkout

Coach operations:

- upsert profile
- manage packages and availability
- dashboard summary
- client list and client pipeline
- full client workspace
- coaching messages
- check-in inbox and feedback
- program templates and exercises
- habit assignment
- onboarding templates
- calendar/session types/bookings
- billing queue and payment audit
- resource upload and assignment
- workout plan creation for members
- reviews and subscription state transitions

Important entities:

- `CoachEntity`
- `CoachPackageEntity`
- `CoachAvailabilitySlotEntity`
- `CoachDashboardSummaryEntity`
- `CoachClientEntity`
- `SubscriptionEntity`
- `CoachSubscriptionIntakeEntity`
- `CoachReviewEntity`
- `CoachWorkspaceEntity`
- `CoachActionItemEntity`
- `CoachClientPipelineEntry`
- `CoachClientWorkspaceEntity`
- `CoachClientNoteEntity`
- `CoachThreadEntity`
- `CoachMessageEntity`
- `WeeklyCheckinEntity`
- `CoachProgramTemplateEntity`
- `CoachExerciseEntity`
- `CoachHabitAssignmentEntity`
- `CoachOnboardingTemplateEntity`
- `CoachSessionTypeEntity`
- `CoachBookingEntity`
- `CoachPaymentReceiptEntity`
- `CoachPaymentAuditEntity`
- `CoachResourceEntity`
- `CoachResourceAssignmentEntity`
- `CoachPaymobCheckoutSession`
- `CoachPaymentOrderEntity`

Important screens:

- `CoachesScreen`
- `CoachDetailsScreen`
- `SubscriptionPackagesScreen`
- `CoachDashboardScreen`
- `CoachClientPipelineScreen`
- `CoachClientWorkspaceScreen`
- `CoachCheckinInboxScreen`
- `CoachCalendarScreen`
- `CoachBillingScreen`
- `CoachProgramLibraryScreen`
- `CoachOnboardingFlowsScreen`
- `CoachResourcesScreen`
- `CoachPackagesScreen`
- `CoachPackageEditorScreen`
- `CoachProfileScreen`
- `CoachWorkspaceShell`

Coach repository contract highlights:

- coach listing and details: `listCoaches`, `getCoachDetails`
- profile/package/availability: `upsertCoachProfile`, `listCoachPackages`,
  `saveCoachPackage`, `deleteCoachPackage`, `listAvailability`,
  `saveAvailabilitySlot`, `deleteAvailabilitySlot`
- dashboards and clients: `getDashboardSummary`, `listClients`,
  `getWorkspaceSummary`, `listActionItems`, `dismissAutomationEvent`,
  `listClientPipeline`, `getClientWorkspace`, `saveClientRecord`,
  `addClientNote`
- messaging/check-ins: `listCoachThreads`, `listCoachMessages`,
  `sendCoachMessage`, `markThreadRead`, `listCheckinInbox`,
  `submitCheckinFeedback`
- programs/habits/onboarding: `listProgramTemplates`, `saveProgramTemplate`,
  `assignProgramTemplate`, `listExercises`, `saveExercise`, `assignHabits`,
  `listOnboardingTemplates`, `saveOnboardingTemplate`,
  `applyOnboardingTemplate`
- calendar/resources/billing: `listSessionTypes`, `saveSessionType`,
  `listBookings`, `createBooking`, `updateBookingStatus`,
  `listPaymentQueue`, `verifyPayment`, `failPayment`, `listPaymentAuditTrail`,
  `uploadCoachResource`, `listCoachResources`, `saveCoachResource`,
  `assignResourceToClient`
- workout/subscription/reviews: `createWorkoutPlan`, `listWorkoutPlans`,
  `updateWorkoutPlanStatus`, `listSubscriptions`,
  `listSubscriptionRequests`, `requestSubscription`,
  `updateSubscriptionStatus`, `activateSubscriptionWithStarterPlan`,
  `listCoachReviews`, `submitCoachReview`

Payment repository:

- `createPaymobCheckout(coachId, packageId, intake)`
- `getPaymentOrder(paymentOrderId)`

### `coach_member_insights`

Purpose:

- provide member-controlled privacy settings
- expose coach-facing aggregate insight only for consented categories
- store an audit trail of consent changes

Entities:

- `MemberInsightEntity`
- `InsightSummaryEntity`
- `VisibilitySettingsEntity`
- `VisibilityAuditEntity`

Repository contract:

- `getMemberInsight(coachId, memberId, subscriptionId)`
- `listClientInsightSummaries()`
- `getVisibilitySettings(coachId, subscriptionId)`
- `upsertVisibilitySettings(...)`
- `listVisibilityAudit(subscriptionId, coachId)`

Important screens:

- `CoachMemberInsightsScreen`
- `MemberCoachVisibilitySettingsScreen`

### `ai_chat`

Purpose:

- general TAIYO conversation
- planner-aware chat sessions
- AI planner turn parsing
- assistant message streaming via Supabase realtime/polling pattern

Entities:

- `ChatSessionEntity`
- `ChatSessionType`
- `ChatMessageEntity`
- `PlannerTurnResult`

Repository contract:

- `listSessions()`
- `createSession(title, type)`
- `watchMessages(sessionId)`
- `sendMessage(sessionId, content, sessionType, plannerContext)`
- `regeneratePlan(sessionId, draftId)`

Important behavior:

- user message is written before function invocation
- `ai-chat` Edge Function creates assistant responses
- planner sessions can create/update `ai_plan_drafts`
- chat surfaces are gated by AI premium when `ENABLE_AI_PREMIUM=true`

### `ai_coach`

Purpose:

- adaptive daily coaching layer above plans, nutrition, and readiness
- active workout companion
- accountability scans and memory maintenance

Repository contract:

- `getDailyBrief(date)`
- `refreshDailyBrief(date)`
- `upsertReadiness(...)`
- `applyAdjustment(adjustmentType, briefDate, taskId)`
- `listNudges()`
- `runAccountabilityScan()`
- `maintainMemory()`
- `getActiveWorkoutSession(sessionId)`
- `startActiveWorkout(planId, dayId, targetDate)`
- `recordActiveWorkoutEvent(sessionId, eventType, payload)`
- `completeActiveWorkout(sessionId, difficultyScore, summary)`
- `getWorkoutPrompt(sessionId, promptKind)`
- `getWeeklySummary(weekStart)`
- `refreshWeeklySummary(weekStart)`
- `shareWeeklySummary(weekStart)`

Fallback behavior:

- If latest `ai_coach` schema/function is missing, the repository can build a
  legacy daily brief from active plan agenda and nutrition data.
- Missing-schema detection looks for tables/RPCs/functions such as
  `member_ai_daily_briefs`, `member_ai_nudges`, `member_active_workout_sessions`,
  `get_member_ai_coach_context`, and `ai-coach`.

### `planner`

Purpose:

- guided AI workout plan intake
- draft review
- activation into normalized workout plan rows
- agenda display
- task status updates
- local reminder bootstrap and reminder syncing

Entities:

- `PlannerDraftEntity`
- `PlanActivationResultEntity`
- `PlanDetailEntity`
- `PlanDayEntity`
- `PlanTaskEntity`
- `PlannerBuilderState`
- `PlannerBuilderQuestion`
- `PlannerBuilderAnswer`

Repository contract:

- `getLatestDraft(sessionId)`
- `getDraft(draftId)`
- `activateDraft(draftId, reminderTime)`
- `listTodayAgenda()`
- `listPlanAgenda(planId, dateFrom, dateTo)`
- `getPlanDetail(planId)`
- `updateTaskStatus(taskId, status, completedAt, notes)`
- `updateReminderTime(planId, reminderTime)`
- `syncReminders(timeZone, limit)`

Important backend anchors:

- `ai_plan_drafts`
- `workout_plans`
- `workout_plan_days`
- `workout_plan_tasks`
- `workout_task_logs`
- `activate_ai_workout_plan(...)`
- `upsert_workout_task_log(...)`
- `list_member_plan_agenda(...)`
- `sync_member_task_notifications(...)`
- `update_ai_plan_reminder_time(...)`

### `nutrition`

Purpose:

- create member nutrition profile
- calculate calorie and macro targets
- generate meal plans
- track planned meals, quick meals, hydration, and check-ins
- provide adaptive nutrition insights

Domain services:

- `CalorieEngine`
- `MacroEngine`
- `MealPlanGenerator`
- `NutritionAdaptationEngine`
- `NutritionSetupQuestionFactory`

Repository contract:

- `getProfile()`
- `upsertProfile(profile)`
- `getActiveTarget()`
- `saveTarget(target)`
- `listMealTemplates()`
- `getActiveMealPlan()`
- `saveGeneratedMealPlan(profile, target, generatedPlan)`
- `getDaySummary(date)`
- `completePlannedMeal(plannedMealId)`
- `uncompletePlannedMeal(plannedMealId)`
- `quickAddMeal(date, name, mealType, calories, protein, carbs, fat)`
- `addHydration(date, amountMl)`
- `swapPlannedMeal(plannedMealId, templateId)`
- `listCheckins()`
- `saveCheckin(date, adherenceScore, notes)`

### `store`

Purpose:

- buyer-side product listing, product details, favorites, cart, shipping
  addresses, checkout, and orders

Entities:

- `ProductEntity`
- `CartEntity`
- `CartItemEntity`
- `ShippingAddressEntity`
- `OrderEntity`
- `OrderItemEntity`
- `OrderStatusHistoryEntry`

Repository contract:

- `listProducts(category, searchQuery, page, pageSize)`
- `getProductById(productId)`
- `getCart()`
- `addToCart(productId, quantity)`
- `updateCartQuantity(productId, quantity)`
- `removeCartItem(productId)`
- `clearInvalidCartItems()`
- `getFavoriteIds()`
- `getFavoriteProducts()`
- `toggleFavorite(product)`
- `listShippingAddresses()`
- `saveShippingAddress(address)`
- `deleteShippingAddress(addressId)`
- `setDefaultShippingAddress(addressId)`
- `placeOrderFromCart(shippingAddressId, notes)`
- `listMyOrders()`
- `getMyOrderDetails(orderId)`

### `seller`

Purpose:

- seller onboarding/profile
- seller dashboard
- product CRUD and image upload
- seller order queue and order details/status transitions

Entities:

- `SellerProfileEntity`
- `SellerDashboardSummaryEntity`

Repository contract:

- `getSellerProfile()`
- `upsertSellerProfile(...)`
- `getDashboardSummary()`
- `listOwnProducts()`
- `saveProduct(...)`
- `uploadProductImage(bytes, fileName, contentType, productId)`
- `deleteOrArchiveProduct(productId)`
- `listOrders()`
- `getOrderDetails(orderId)`
- `updateOrderStatus(orderId, status, note)`

### `news`

Purpose:

- personalized fitness/news feed
- details page
- save/remove saved article
- dismiss article
- track view/click/save/dismiss interactions

Entities:

- `NewsArticleEntity`
- `NewsArticleModel`

Repository contract:

- `listPersonalizedNews(page, pageSize)`
- `getArticleById(articleId)`
- `trackInteraction(articleId, interactionType, dwellSeconds)`
- `saveArticle(articleId)`
- `removeSavedArticle(articleId)`
- `dismissArticle(articleId)`

### `monetization`

Purpose:

- AI premium product catalog
- purchase and restore flows
- app-store purchase stream handling
- backend entitlement refresh and purchase sync
- premium gate decision for TAIYO surfaces

Entities:

- `MonetizationConfig`
- `BillingProduct`
- `BillingCatalog`
- `CurrentSubscriptionSummary`
- `BillingInteractionEvent`
- `AiPremiumGateDecision`

Repository contracts:

- `BillingRepository.loadAiPremiumCatalog(config)`
- `BillingRepository.purchaseAiPremium(product, applicationUserName)`
- `BillingRepository.restorePurchases(applicationUserName)`
- `BillingRepository.queryExistingPurchases()`
- `BillingRepository.completePurchase(purchaseDetails)`
- `EntitlementRepository.ensureBillingCustomerToken()`
- `EntitlementRepository.getCurrentSubscription()`
- `EntitlementRepository.refreshCurrentSubscription()`
- `EntitlementRepository.syncPurchase(purchase)`

### `settings`

Purpose:

- settings preferences
- notification center
- support/legal pages
- delete-account screen

Key state:

- `MeasurementUnit`
- `AppLanguage`
- `NotificationCategory`
- `NotificationFilter`
- `SettingsPreferences`
- `AppNotificationItem`
- `SettingsPreferencesController`
- `NotificationsController`

## Complete Repo Table Inventory

The current migration set declares these tables.

### Identity, Roles, Preferences, and Notifications

- `public.roles`
- `public.users`
- `public.profiles`
- `public.user_preferences`
- `public.device_tokens`
- `public.notifications`
- `public.app_admins`
- `public.admin_audit_events`

### Member, Progress, Planner, and Active Workout

- `public.member_profiles`
- `public.member_weight_entries`
- `public.member_body_measurements`
- `public.workout_sessions`
- `public.workout_plans`
- `public.workout_plan_days`
- `public.workout_plan_tasks`
- `public.workout_task_logs`
- `public.ai_plan_drafts`
- `public.member_daily_readiness_logs`
- `public.member_ai_daily_briefs`
- `public.member_ai_nudges`
- `public.member_ai_plan_adaptations`
- `public.member_ai_weekly_summaries`
- `public.member_active_workout_sessions`
- `public.member_active_workout_events`

### AI Chat and Memory

- `public.chat_sessions`
- `public.chat_messages`
- `public.ai_user_memories`
- `public.ai_session_state`

### Coach Marketplace and Relationship

- `public.coach_profiles`
- `public.coach_packages`
- `public.coach_availability_slots`
- `public.coach_reviews`
- `public.subscriptions`
- `public.coach_checkout_requests`
- `public.coach_payment_receipts`
- `public.coach_payment_audit_events`
- `public.coach_member_threads`
- `public.coach_messages`
- `public.weekly_checkins`
- `public.progress_photos`
- `public.coach_verifications`
- `public.coach_payouts`
- `public.coach_referrals`

### Coach Workspace, Programs, Resources, and Calendar

- `public.coach_client_records`
- `public.coach_client_notes`
- `public.coach_automation_events`
- `public.coach_thread_reads`
- `public.coach_program_templates`
- `public.coach_exercise_library`
- `public.coach_habit_templates`
- `public.member_habit_assignments`
- `public.member_habit_logs`
- `public.coach_resources`
- `public.coach_resource_assignments`
- `public.coach_onboarding_templates`
- `public.coach_onboarding_applications`
- `public.coach_session_types`
- `public.coach_bookings`
- `public.coach_challenges`
- `public.coach_group_programs`
- `public.coach_group_memberships`
- `public.coach_group_posts`

### Coach Paymob and Settlement

- `public.coach_payment_orders`
- `public.coach_payment_transactions`
- `public.coach_payout_accounts`
- `public.coach_payout_items`

### Privacy and Insights

- `public.coach_member_visibility_settings`
- `public.coach_member_visibility_audit`
- `public.member_product_recommendations`

### Nutrition

- `public.nutrition_profiles`
- `public.nutrition_targets`
- `public.nutrition_meal_templates`
- `public.member_meal_plans`
- `public.member_meal_plan_days`
- `public.member_planned_meals`
- `public.meal_logs`
- `public.hydration_logs`
- `public.nutrition_checkins`

### Store, Seller, Orders, and Billing

- `public.seller_profiles`
- `public.products`
- `public.product_favorites`
- `public.store_carts`
- `public.store_cart_items`
- `public.shipping_addresses`
- `public.store_checkout_requests`
- `public.orders`
- `public.order_items`
- `public.order_status_history`
- `public.billing_products`
- `public.billing_customers`
- `public.store_transactions`
- `public.subscription_entitlements`
- `public.billing_sync_events`

### News

- `public.news_sources`
- `public.news_articles`
- `public.news_article_topics`
- `public.user_news_interests`
- `public.news_article_interactions`
- `public.news_article_bookmarks`
- `private.news_scheduler_config`

## Complete SQL Function Inventory

### Account, Roles, and Shared Helpers

- `public.current_role`
- `public.current_user_id`
- `public.touch_updated_at`
- `public.soft_delete_account`
- `public.prepare_account_for_hard_delete`
- `public.ensure_billing_customer`
- `public.is_admin`
- `public.assert_admin`

### Member Planner, Active Workout, and TAIYO Coach

- `public.activate_ai_workout_plan`
- `public.upsert_workout_task_log`
- `public.list_member_plan_agenda`
- `public.sync_member_task_notifications`
- `public.update_ai_plan_reminder_time`
- `public.get_member_ai_coach_context`
- `public.upsert_member_readiness_log`
- `public.apply_member_ai_adjustment`
- `public.start_member_active_workout`
- `public.record_member_active_workout_event`
- `public.complete_member_active_workout`
- `public.share_member_ai_weekly_summary`
- `public.build_member_ai_weekly_summary`
- `public.touch_member_daily_streak`

### Coach Marketplace and Relationship

- `public.list_coach_directory`
- `public.list_coach_directory_v2`
- `public.get_coach_public_profile`
- `public.list_coach_public_packages`
- `public.list_coach_public_reviews`
- `public.refresh_coach_rating_aggregate`
- `public.handle_coach_review_aggregate`
- `public.list_coach_clients`
- `public.list_coach_subscription_requests`
- `public.request_coach_subscription`
- `public.create_coach_checkout`
- `public.confirm_coach_payment`
- `public.activate_coach_subscription_with_starter_plan`
- `public.update_coach_subscription_status`
- `public.pause_coach_subscription`
- `public.switch_coach_request`
- `public.ensure_coach_member_thread`
- `public.sync_coach_thread_after_message`
- `public.send_coaching_message`
- `public.submit_weekly_checkin`
- `public.submit_coach_checkin_feedback`
- `public.submit_coach_review`
- `public.list_member_subscriptions_detailed`
- `public.list_member_subscriptions_live`

### Coach Workspace and Delivery

- `public.derive_coach_pipeline_stage`
- `public.coach_dashboard_summary`
- `public.coach_workspace_summary`
- `public.list_coach_action_items`
- `public.dismiss_coach_action_item`
- `public.list_coach_client_pipeline`
- `public.get_coach_client_workspace`
- `public.upsert_coach_client_record`
- `public.add_coach_client_note`
- `public.mark_coach_thread_read`
- `public.list_coach_program_templates`
- `public.save_coach_program_template`
- `public.assign_program_template_to_client`
- `public.list_coach_exercises`
- `public.save_coach_exercise`
- `public.assign_client_habits`
- `public.list_coach_onboarding_templates`
- `public.save_coach_onboarding_template`
- `public.apply_coach_onboarding_flow`
- `public.list_coach_resources`
- `public.save_coach_resource`
- `public.assign_resource_to_client`
- `public.list_coach_session_types`
- `public.seed_default_coach_session_types`
- `public.save_coach_session_type`
- `public.list_coach_bookable_slots`
- `public.list_coach_bookings`
- `public.create_coach_booking`
- `public.update_coach_booking_status`

### Coach Payment, Paymob, and Payouts

- `public.submit_coach_payment_receipt`
- `public.verify_coach_payment`
- `public.fail_coach_payment`
- `public.list_coach_payment_audit`
- `public.list_coach_payment_queue`
- `public.coach_billing_state`
- `public.is_subscription_member`
- `public.is_subscription_coach`
- `public.get_coach_payment_order_status`
- `public.create_pending_coach_payout_for_payment`
- `public.process_coach_paymob_callback`
- `public.process_coach_paymob_callback_as_service`
- `public.admin_record_coach_payout_paid`

### Admin Settlement

- `public.current_admin`
- `public.admin_role_permissions`
- `public.admin_has_permission`
- `public.admin_assert_permission`
- `public.admin_insert_audit`
- `public.admin_create_audit_event`
- `public.admin_dashboard_summary`
- `public.admin_payment_order_json`
- `public.admin_payout_json`
- `public.admin_list_payment_orders`
- `public.admin_get_payment_order_details`
- `public.admin_list_payouts`
- `public.admin_get_payout_details`
- `public.admin_list_coach_balances`
- `public.admin_get_coach_settlement_details`
- `public.admin_list_subscriptions`
- `public.admin_list_audit_events`
- `public.admin_update_payout_status`
- `public.admin_mark_payout_ready`
- `public.admin_mark_payout_processing`
- `public.admin_mark_payout_paid`
- `public.admin_mark_payout_failed`
- `public.admin_hold_payout`
- `public.admin_release_payout`
- `public.admin_cancel_payout`
- `public.admin_add_payment_note`
- `public.admin_mark_payment_needs_review`
- `public.admin_cancel_unpaid_checkout`
- `public.admin_reconcile_payment_order`
- `public.admin_ensure_subscription_thread`
- `public.admin_verify_coach_payout_account`

### Store, Seller, and Orders

- `public.create_store_order`
- `public.update_store_order_status`
- `public.list_member_orders_detailed`
- `public.list_seller_orders_detailed`
- `public.seller_dashboard_summary`

### News and Scheduler

- `public.news_safe_jsonb_array`
- `public.news_target_matches`
- `public.normalize_news_goal`
- `public.normalize_news_level`
- `public.upsert_user_news_interest`
- `public.bump_user_news_interest`
- `public.sync_member_news_interests`
- `public.track_news_interaction`
- `public.save_news_article`
- `public.dismiss_news_article`
- `public.list_news_article_topics`
- `public.list_saved_news_articles`
- `public.list_personalized_news`
- `private.upsert_news_scheduler_config`
- `private.schedule_news_sync`
- `private.unschedule_news_sync`

### Privacy and Insights

- `public.upsert_coach_member_visibility`
- `public.get_member_visibility_settings`
- `public.get_coach_member_insight`
- `public.list_coach_member_insight_summaries`
- `public.list_visibility_audit`

## Migration Timeline With Intent

| Migration | Intent |
| --- | --- |
| `20260307000001_init_gymunity.sql` | base roles, users, profiles, coach profiles, products, orders, subscriptions, chat, workout plans, initial RLS |
| `20260307000002_storage.sql` | `avatars` and `product-images` buckets and policies |
| `20260307000003_notifications.sql` | `device_tokens`, `notifications`, notification RLS |
| `20260311000004_coach_directory_rpc.sql` | early coach directory RPC |
| `20260312000005_account_deletion.sql` | soft-delete account support |
| `20260312000006_core_role_flows.sql` | member/seller profiles, preferences, measurements, packages, availability, sessions, order items/history, reviews, dashboards |
| `20260312000007_store_orders_hardening.sql` | stronger store checkout/order functions and seller order details |
| `20260312000008_monetization_billing.sql` | billing products, customers, transactions, entitlements, sync events |
| `20260313000009_ai_member_planner.sql` | AI plan drafts, workout plan days/tasks/logs, activation and reminders |
| `20260315000010_ai_personalization_memory.sql` | AI memory/session personalization |
| `20260316000011_hard_delete_account.sql` | hard-delete preparation and cleanup helpers |
| `20260316000012_personalized_news.sql` | news sources/articles/topics/interests/interactions/bookmarks and feed RPCs |
| `20260316000013_news_sync_scheduler.sql` | private news scheduler config and scheduler helpers |
| `20260317000014_coach_offers_marketplace.sql` | richer coach/package marketplace fields |
| `20260318000015_egypt_coaching_marketplace_v1.sql` | Egypt-focused coach subscription, checkout, messaging, check-in, payout, referral primitives |
| `20260418000016_nutrition_system.sql` | nutrition profile, targets, templates, meal plans, logs, hydration, check-ins |
| `20260418000017_coach_member_insights.sql` | consent-gated insight sharing and audit trail |
| `20260421000018_coach_workspace_crm.sql` | coach CRM, notes, action items, client pipeline, workspace summary |
| `20260421000019_coach_program_delivery.sql` | coach program templates, exercise library, program assignment, habits |
| `20260421000020_coach_onboarding_resources.sql` | coach resources, resource assignments, onboarding templates |
| `20260421000021_coach_calendar_booking.sql` | coach session types and bookings |
| `20260421000022_coach_billing_verification.sql` | legacy manual payment receipt bucket/table/RPCs |
| `20260421000023_coach_public_profile_conversion.sql` | public coach profile conversion helpers |
| `20260421000024_taiyo_member_os.sql` | AI coach/member OS tables and RPCs |
| `20260422000025_member_daily_streak.sql` | member daily streak tracking |
| `20260425000026_fix_ai_coach_context_subscription_thread.sql` | AI coach context fix around subscription/thread data |
| `20260425000027_fix_active_workout_start_uuid_min.sql` | active workout start UUID/min fix |
| `20260425000028_harden_coach_member_feedback.sql` | coach feedback hardening |
| `20260425000029_publish_complete_coach_offers.sql` | publish complete draft coach offers |
| `20260425000030_publish_remaining_complete_draft_coach_offers.sql` | publish remaining complete draft offers |
| `20260425000031_fix_coach_checkout_ambiguous_id.sql` | coach checkout ambiguous ID fix |
| `20260425000032_fix_client_workspace_visibility_jsonb.sql` | client workspace visibility JSONB fix |
| `20260426000033_coach_relationship_core_hardening.sql` | active-only relationship writes and `send_coaching_message` |
| `20260426000034_coach_paymob_test_payments.sql` | Paymob test payment orders, transactions, payouts, callback processing |
| `20260426000035_admin_coach_payment_settlement_dashboard.sql` | admin dashboard, payout operations, audit and settlement RPCs |
| `20260426000036_paymob_test_mode_configuration_hardening.sql` | Paymob test-mode configuration hardening |
| `20260426000037_fix_admin_dashboard_summary_and_mobile_nav.sql` | admin dashboard summary and mobile navigation fixes |
| `20260427000038_paymob_callback_service_role_wrapper.sql` | service-role wrapper for Paymob callback processing |

## Edge Function Details

| Function | JWT config in repo | Purpose |
| --- | --- | --- |
| `ai-chat` | default from function deployment unless configured elsewhere | TAIYO chat/planner generation |
| `ai-coach` | `verify_jwt = false` in `supabase/config.toml`; function validates auth manually | daily brief, nudges, memory, weekly summary, active workout prompts |
| `delete-account` | default unless configured elsewhere | authenticated account deletion |
| `sync-news-feeds` | default unless configured elsewhere | RSS ingestion and classification |
| `billing-verify-apple` | default unless configured elsewhere | App Store receipt verification |
| `billing-verify-google` | default unless configured elsewhere | Google Play purchase verification |
| `billing-refresh-entitlement` | default unless configured elsewhere | current entitlement refresh |
| `billing-apple-notifications` | default unless configured elsewhere | Apple server notifications |
| `billing-google-rtdn` | default unless configured elsewhere | Google real-time developer notifications |
| `create-coach-paymob-checkout` | default unless configured elsewhere | create Paymob intention and local payment order |
| `paymob-transaction-callback` | `verify_jwt = false`; HMAC verification is the trust boundary | Paymob processed webhook/callback |
| `paymob-payment-response` | `verify_jwt = false`; user-facing redirect response | Paymob browser redirect endpoint |
| `sync-paymob-payment-status` | default unless configured elsewhere | payment status sync/reconciliation helper |
| `admin-payment-settings` | default unless configured elsewhere | safe admin view of payment settings status |

Shared function code:

- `_shared/cors.ts`
- `_shared/billing.ts`
- `_shared/paymob.ts`
- `_shared/paymob_test.ts`

## Storage Detail

### `avatars`

- private bucket
- intended path is user-owned
- used by profile avatar upload and signed URL display

### `product-images`

- public bucket
- seller-owned writes
- public read
- used by seller product editor and product cards/details

### `coach-resources`

- private bucket
- introduced by coach onboarding/resources migrations
- used for coach resource upload and assignment
- members should only read assigned resources

### `coach-payment-receipts`

- private bucket
- legacy manual payment proof upload path
- used when manual proof feature flag is enabled
- should not be used as the main Paymob MVP path

## Local Supabase Configuration

From `supabase/config.toml`:

- local project id: `my_app`
- local API enabled on port `54321`
- local DB port `54322`
- local Studio port `54323`
- local inbucket port `54324`
- local analytics port `54327`
- local Postgres major version `17`
- local storage enabled with `50MiB` file size limit
- auth enabled
- local site URL: `http://127.0.0.1:3000`
- email confirmations disabled for local auth
- refresh token rotation enabled
- local Edge Runtime enabled with Deno 2

Explicit local function JWT overrides:

- `ai-coach`: `verify_jwt = false`
- `paymob-transaction-callback`: `verify_jwt = false`
- `paymob-payment-response`: `verify_jwt = false`

## Asset Inventory

Images in `assets/images/`:

- `ai_chat_home.png`
- `ai_conversation.png`
- `coaches_card_bg.png`
- `coaches_icon.png`
- `coach_dashboard.png`
- `discover_coaches.png`
- `fitness_store_home.png`
- `login_screen.png`
- `logo.png`
- `logo_app_icon.png`
- `logo_app_icon_foreground.png`
- `member_home.png`
- `onboarding_goals.png`
- `plan_card_bg.png`
- `role_selection.png`
- `seller_dashboard.png`
- `splash_screen.png`
- `streak_icon.png`
- `weight_card_bg.png`
- `welcome_screen.png`

Images in `backgrounds/`:

- `Fitness landscape.png`
- `High-tech gym setup.png`
- `Onboarding - Shop & Train (v2).png`
- `Onboarding - Your Fitness Unified.png`

## Test Inventory

Current Dart test files:

- `test/active_workout_session_screen_test.dart`
- `test/admin_dashboard_test.dart`
- `test/ai_chat_home_screen_test.dart`
- `test/ai_chat_personalization_test.dart`
- `test/ai_coach_home_screen_test.dart`
- `test/ai_generated_plan_screen_test.dart`
- `test/auth_callback_utils_test.dart`
- `test/auth_flow_screen_test.dart`
- `test/auth_route_resolver_test.dart`
- `test/auth_token_project_ref_test.dart`
- `test/chat_controller_test.dart`
- `test/coach_member_insights_entity_test.dart`
- `test/coach_repository_impl_test.dart`
- `test/coach_workspace_widgets_test.dart`
- `test/delete_account_screen_test.dart`
- `test/features/ai_coach/data/repositories/ai_coach_repository_impl_test.dart`
- `test/features/ai_coach/presentation/providers/ai_coach_providers_test.dart`
- `test/historical_record_utils_test.dart`
- `test/manual_live_planner_repository_test.dart`
- `test/member_home_content_summary_test.dart`
- `test/member_home_shell_test.dart`
- `test/member_repository_impl_test.dart`
- `test/member_shell_phone_smoke_test.dart`
- `test/news_article_model_test.dart`
- `test/news_card_test.dart`
- `test/news_feed_screen_test.dart`
- `test/onboarding_behavior_test.dart`
- `test/paymob_coach_payment_entities_test.dart`
- `test/planner_builder_question_factory_test.dart`
- `test/planner_builder_screen_test.dart`
- `test/planner_notification_ids_test.dart`
- `test/planner_reminder_bootstrap_service_test.dart`
- `test/planner_summary_provider_test.dart`
- `test/role_selection_test.dart`
- `test/routes_and_features_test.dart`
- `test/test_doubles.dart`
- `test/visibility_settings_entity_test.dart`
- `test/welcome_screen_test.dart`
- `test/widget_test.dart`
- `test/workout_day_details_screen_test.dart`
- `test/workout_plan_screen_test.dart`

Recommended local test command from README/scripts:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\flutter_test_dev.ps1
```

## Operational Flow Details

### Registration to Dashboard

```text
public screen
  -> register/login/OAuth
  -> Supabase Auth session
  -> ensure users/profiles rows
  -> role selection if no role
  -> role-specific onboarding
  -> profiles.onboarding_completed = true
  -> role dashboard
```

Failure states:

- invalid config: splash terminal config error
- backend initialization error: splash backend error
- deleted account: forced logout and deleted terminal state
- missing profile: role selection recovery

### Member Starts AI Plan

```text
member opens AI/planner
  -> planner builder reads profile, preferences, memories, plans, progress
  -> question factory asks missing high-signal questions
  -> chat session of type planner
  -> ai-chat Edge Function
  -> ai_plan_drafts row
  -> review screen
  -> activate_ai_workout_plan
  -> workout plan/day/task rows
  -> reminder sync
```

### Member Starts Active Workout

```text
workout plan/day route
  -> ActiveWorkoutSessionScreen
  -> start_member_active_workout
  -> member_active_workout_sessions row
  -> record_member_active_workout_event for task actions
  -> complete_member_active_workout
  -> summary JSON and completion metrics
```

### Member Uses TAIYO Coach

```text
AI Coach home
  -> get/refresh daily brief
  -> optionally upsert readiness
  -> list nudges
  -> apply adjustment or open active workout
  -> refresh weekly summary
  -> optionally share weekly summary
```

### Member Buys Coaching With Paymob

```text
SubscriptionPackagesScreen
  -> CoachPaymentRepository.createPaymobCheckout
  -> create-coach-paymob-checkout Edge Function
  -> validate member role/package
  -> create subscription checkout_pending
  -> create coach_payment_orders row
  -> create Paymob intention
  -> return checkout URL/public key/client secret
  -> external hosted Paymob checkout
  -> callback to paymob-transaction-callback
  -> verify HMAC
  -> process callback as service
  -> update order/subscription
  -> ensure thread
  -> create payout item
```

### Coach Handles Active Client

```text
Coach dashboard
  -> list action items and workspace summary
  -> open client pipeline
  -> get client workspace
  -> send messages through send_coaching_message
  -> review check-ins
  -> submit feedback
  -> assign program/resources/habits
  -> book sessions
  -> track billing state
```

### Admin Settles Coach Payout

```text
AdminAccessGate
  -> current_admin
  -> admin dashboard summary
  -> list paid payment orders
  -> list payout items
  -> admin transfers money outside app
  -> admin_mark_payout_paid with external reference
  -> admin_audit_events row
  -> coach notification
```

### Store Checkout

```text
Store catalog/product
  -> cart mutation
  -> shipping address
  -> create_store_order
  -> orders/order_items/order_status_history
  -> seller order queue
  -> update_store_order_status
```

### News Ingestion and Feed

```text
sync-news-feeds
  -> read active news_sources
  -> fetch/classify RSS
  -> upsert news_articles and topics
  -> member opens feed
  -> list_personalized_news
  -> track/save/dismiss interactions
```

## Product and Engineering Gaps

The current repo is broad, but the following are still important gaps or risks:

1. Live deployment parity is unknown for the latest migrations and Paymob/admin
   functions.
2. Paymob is documented as test mode only.
3. Refund, dispute, and live-mode payment policy are not implemented.
4. Automatic coach payout is not implemented.
5. Member-facing resource, booking/session, and coach-assigned habit
   destination screens are not complete or not found in current discovery.
6. Progress photo table exists, but a dedicated progress photo storage bucket
   is not defined.
7. Some coach assignment RPCs need a product decision on whether pending/paused
   subscriptions can receive programs, habits, resources, or bookings.
8. Paused subscription behavior must be made consistent across messages,
   check-ins, bookings, resources, insights, and billing.
9. Edge Function tests exist for several functions, but local Deno execution was
   not verified in this documentation update.
10. Production app-store billing requires deployed billing functions and secrets.
11. Any access token pasted in chat must be revoked/rotated.

## Deployment Readiness Checklist

Before treating the app as production-ready:

1. Revoke/rotate pasted Supabase personal access tokens.
2. Run `flutter test` through project helper scripts.
3. Run SQL smoke/audit scripts against a safe local database.
4. Run Deno tests for Edge Functions.
5. Verify Supabase linked migration list matches local migrations through
   `20260427000038`.
6. Deploy required Edge Functions.
7. Set Edge Function secrets for AI, billing, news, and Paymob.
8. Verify storage buckets and policies exist live.
9. Verify auth redirect URLs for mobile and recovery flows.
10. Run member onboarding, coach onboarding, seller onboarding smoke tests.
11. Run Paymob test payment end-to-end.
12. Verify active subscription creates exactly one thread.
13. Verify message/check-in writes are active-only.
14. Verify admin dashboard permissions for super, finance, support, and
    non-admin users.
15. Verify seller order status changes and member order visibility.
16. Verify account deletion in a non-production test account.
17. Keep `ENABLE_COACH_MANUAL_PAYMENT_PROOFS=false` for Paymob MVP unless the
    legacy manual path is explicitly being tested.
18. Keep `ENABLE_AI_PREMIUM=false` until billing deployment is verified.

## Documentation Map

Current docs in this repo:

- `docs/gymunity_project_full_documentation.md`: this canonical project map
- `docs/coach_client_relationship_full_discovery.txt`: exhaustive coach/client
  relationship and Paymob discovery
- `docs/coach_relationship_backend_parity_audit.md`: relationship backend
  parity and hardening audit
- `docs/paymob_test_mode_setup.md`: Paymob test-mode setup checklist
- `docs/paymob_coach_payments_test_mode.md`: Paymob coach payment test-mode
  operation and QA checklist
- `docs/admin_coach_payment_settlement.md`: admin payout settlement guide
- `docs/coach_onboarding_inputs.md`: coach onboarding inputs/reference
- `docs/store_orders/store_and_orders_audit.md`: store/order audit

## Final Detailed System Summary

GymUnity has evolved from a role-based fitness app into a larger operating
system around three commercial loops:

1. Member self-service loop:
   member signs up, completes profile, gets AI/nutrition/workout guidance,
   tracks progress, reads news, buys products, and optionally upgrades AI.

2. Coaching marketplace loop:
   coach publishes profile/packages, member pays for coaching, a subscription
   becomes active, thread/check-ins/workspace unlock, and privacy controls
   govern what the coach can see.

3. GymUnity operations loop:
   Paymob collects member payment into GymUnity, backend verifies callback,
   payout ledger is created, admin manually settles the coach outside the app,
   and audit events preserve the operational history.

The codebase has local implementations for these loops, but the highest-risk
boundary is backend parity. The repo describes a much richer backend than the
last historical live checks. A fresh Supabase migration/function/storage/secret
audit is required before relying on the latest Paymob, admin, AI coach, and
coach workspace systems in production.
