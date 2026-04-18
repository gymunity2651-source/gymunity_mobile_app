# GymUnity Project Documentation

Generated on: 2026-04-18  
Project folder: `my_app`  
Product name: `GymUnity`  
Project type: Flutter fitness platform backed by Supabase.

This document explains the project in practical terms: what the app does, how the codebase is organized, how startup/configuration works, how Supabase is connected, which backend objects exist, which features are implemented, and which gaps currently need attention.

Security note: a Supabase personal access token was used temporarily to inspect the linked live Supabase project through the Supabase Management API. The token was not saved in this file or in the project.

---

## 1. Product Overview

GymUnity is a multi-role fitness app. It supports:

- `Member`: tracks profile, weight, body measurements, workout plans, subscriptions, store orders, news, and TAIYO AI.
- `Coach`: manages coach profile, coaching packages, availability, clients, subscriptions, and workout plans.
- `Seller`: manages a store profile, product catalog, product images, inventory, and orders.

The app also includes:

- TAIYO AI Chat.
- AI workout plan generation and activation.
- Personalized fitness/news feed.
- Store/catalog/cart/favorites/checkout/orders.
- AI Premium monetization through in-app purchases.
- Local workout task reminders.
- Supabase Auth, Postgres, RLS, Storage, and Edge Functions.

---

## 2. Technology Stack

### Flutter / Dart

- Dart SDK: `^3.11.1`
- State management: `flutter_riverpod`
- Supabase client: `supabase_flutter`
- Deep links / OAuth callbacks: `app_links`
- UI helpers: `google_fonts`, `animations`, `smooth_page_indicator`, `fl_chart`
- Local notifications: `flutter_local_notifications`, `timezone`, `flutter_timezone`
- Store billing: `in_app_purchase`, `in_app_purchase_android`, `in_app_purchase_storekit`
- Image handling: `image_picker`, `image`
- Codegen packages are present: `freezed`, `json_serializable`, `build_runner`, but most current entities are handwritten.

### Supabase

- Supabase Auth
- PostgreSQL database
- Row Level Security
- Storage buckets
- Edge Functions written in Deno/TypeScript

### Extra Folder

There is a separate Remotion project:

```text
remotion-chart/
```

It appears separate from the Flutter runtime and is likely used for video/chart generation.

---

## 3. App Startup

Entry point:

```text
lib/main.dart
```

Startup sequence:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `LocalRuntimeConfigLoader.primeIfNeeded()`
3. If `AppConfig` is valid, `SupabaseInitializer.initialize()` runs.
4. The app starts as `ProviderScope(child: GymUnityApp())`.

Important files:

```text
lib/main.dart
lib/app/app.dart
lib/app/routes.dart
lib/core/config/app_config.dart
lib/core/config/local_runtime_config_loader.dart
lib/core/supabase/supabase_initializer.dart
```

`GymUnityApp`:

- Builds the root `MaterialApp`.
- Uses `AppTheme.darkTheme`.
- Supports English and Arabic locales.
- Starts at `AppRoutes.splash`.
- Bootstraps monetization and planner reminders after the first frame.
- Refreshes entitlements and planner reminders when the app resumes.

---

## 4. Runtime Configuration

The Flutter app does not read `.env` directly at runtime. It reads values from compile-time `--dart-define` entries through:

```text
lib/core/config/app_config.dart
```

Supported keys include:

```text
APP_ENV
SUPABASE_URL
SUPABASE_ANON_KEY
AUTH_REDIRECT_SCHEME
AUTH_REDIRECT_HOST
PRIVACY_POLICY_URL
TERMS_OF_SERVICE_URL
SUPPORT_URL
SUPPORT_EMAIL
SUPPORT_EMAIL_SUBJECT
REVIEWER_LOGIN_HELP_URL
ENABLE_COACH_ROLE
ENABLE_SELLER_ROLE
ENABLE_APPLE_SIGN_IN
ENABLE_STORE_PURCHASES
ENABLE_COACH_SUBSCRIPTIONS
ENABLE_AI_PREMIUM
APPLE_AI_PREMIUM_MONTHLY_PRODUCT_ID
APPLE_AI_PREMIUM_ANNUAL_PRODUCT_ID
GOOGLE_AI_PREMIUM_SUBSCRIPTION_ID
GOOGLE_AI_PREMIUM_MONTHLY_BASE_PLAN_ID
GOOGLE_AI_PREMIUM_ANNUAL_BASE_PLAN_ID
```

Local helper scripts read `.env`, sync local runtime config, and pass values into Flutter:

```text
scripts/flutter_with_env.ps1
scripts/flutter_run_dev.ps1
scripts/flutter_test_dev.ps1
scripts/flutter_build_apk_dev.ps1
scripts/flutter_build_appbundle_dev.ps1
scripts/sync_local_runtime_config.ps1
```

Recommended local commands:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\flutter_run_dev.ps1 -DeviceId emulator-5554
powershell -ExecutionPolicy Bypass -File .\scripts\flutter_test_dev.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\flutter_build_apk_dev.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\flutter_build_appbundle_dev.ps1
```

Important: raw `flutter run` does not automatically read `.env`, so the app may open in a configuration error state if required `--dart-define` values are missing.

---

## 5. Linked Supabase Project

The linked live Supabase project was verified.

Non-sensitive project details:

```text
Project ref: pooelnnveljiikpdrvqw
Project name: gymunity
Region: eu-west-2
Status: ACTIVE_HEALTHY
Created at: 2026-03-08T03:15:06.982769Z
```

The project ref is derived from the configured `SUPABASE_URL`.

---

## 6. Supabase Migration Status

Applied on the live Supabase database:

```text
20260307000001_init_gymunity.sql
20260307000002_storage.sql
20260307000003_notifications.sql
20260311000004_coach_directory_rpc.sql
20260312000005_account_deletion.sql
20260312000006_core_role_flows.sql
20260312000007_store_orders_hardening.sql
20260312000008_monetization_billing.sql
20260313000009_ai_member_planner.sql
20260315000010_ai_personalization_memory.sql
20260316000011_hard_delete_account.sql
20260316000012_personalized_news.sql
20260316000013_news_sync_scheduler.sql
```

Present locally but not applied to the live database:

```text
supabase/migrations/20260317000014_coach_offers_marketplace.sql
supabase/migrations/20260318000015_egypt_coaching_marketplace_v1.sql
```

This matters. The current Flutter code expects several objects from those two pending migrations. Features around the newer Egypt-first coaching marketplace may fail against the live database until those migrations are applied.

Examples of local-only objects currently missing from the live database:

```text
list_coach_directory_v2
list_member_subscriptions_live
ensure_coach_member_thread
create_coach_checkout
confirm_coach_payment
submit_weekly_checkin
pause_coach_subscription
switch_coach_request
sync_coach_thread_after_message
coach_checkout_requests
coach_member_threads
coach_messages
weekly_checkins
progress_photos
coach_verifications
coach_payouts
coach_referrals
```

Tables that are especially affected by missing local migrations:

```text
member_profiles
coach_profiles
coach_packages
subscriptions
```

---

## 7. Edge Functions

Live deployed functions verified through Supabase:

```text
ai-chat              ACTIVE
delete-account       ACTIVE
sync-news-feeds      ACTIVE
```

The live function metadata shows `verify_jwt = false` for these functions. That does not mean the functions are public business operations. The sensitive functions manually read the `Authorization` header and validate the user inside the function code.

Local functions that exist in the repo but are not currently deployed on the live project:

```text
billing-apple-notifications
billing-google-rtdn
billing-refresh-entitlement
billing-verify-apple
billing-verify-google
```

Impact:

- `ENABLE_AI_PREMIUM=true` should not be enabled in production until the billing functions are deployed and their secrets are configured.
- Purchase verification and entitlement refresh depend on the billing functions.

Edge Function files:

```text
supabase/functions/ai-chat/
supabase/functions/delete-account/
supabase/functions/sync-news-feeds/
supabase/functions/billing-*/
supabase/functions/_shared/
```

---

## 8. Supabase Storage

Live buckets:

```text
avatars         public=false
product-images  public=true
```

Defined in:

```text
supabase/migrations/20260307000002_storage.sql
```

### avatars

- Private bucket.
- Used for profile avatars.
- Path pattern:

```text
avatars/{userId}/avatar.{extension}
```

- Storage policies allow the owner to read, insert, update, and delete their own avatar files.

### product-images

- Public bucket.
- Used by seller products.
- Path pattern:

```text
{sellerUserId}/{productId}/{timestamp}.jpg
```

- Public read is allowed.
- Seller-owned writes are enforced by the first path segment matching `auth.uid()`.

---

## 9. Codebase Structure

Top-level Flutter source:

```text
lib/
  app/
  core/
  features/
```

### app

```text
lib/app/app.dart
lib/app/routes.dart
```

Responsibilities:

- Root app widget.
- Theme and localization setup.
- Route registration.
- Route argument handling.
- OAuth callback route fallback handling.

### core

```text
lib/core/config/
lib/core/constants/
lib/core/di/
lib/core/error/
lib/core/result/
lib/core/routing/
lib/core/supabase/
lib/core/theme/
lib/core/widgets/
lib/core/utils/
```

Responsibilities:

- Runtime config.
- Shared constants.
- Dependency injection providers.
- Shared failure classes.
- Result/pagination helpers.
- Auth route resolution.
- Supabase initialization and auth callback helpers.
- Theme and shared UI widgets.
- Utilities such as historical record normalization.

### features

```text
lib/features/auth/
lib/features/user/
lib/features/onboarding/
lib/features/member/
lib/features/coach/
lib/features/coaches/
lib/features/seller/
lib/features/store/
lib/features/ai_chat/
lib/features/planner/
lib/features/news/
lib/features/monetization/
lib/features/settings/
```

The project follows a feature-first style. Most features have:

```text
data/
domain/
presentation/
```

---

## 10. Dependency Injection

Main provider file:

```text
lib/core/di/providers.dart
```

Important providers:

```text
supabaseClientProvider
authRepositoryProvider
userRepositoryProvider
storeRepositoryProvider
coachRepositoryProvider
memberRepositoryProvider
plannerRepositoryProvider
sellerRepositoryProvider
billingRepositoryProvider
entitlementRepositoryProvider
chatRepositoryProvider
newsRepositoryProvider
authSessionProvider
currentUserProfileProvider
appRoleProvider
authRouteResolverProvider
```

Practical meaning:

- Feature screens/controllers should not create their own Supabase clients.
- Repositories are injected through Riverpod.
- This keeps features testable and keeps Supabase access centralized.

---

## 11. Routing Map

Main router:

```text
lib/app/routes.dart
```

### Auth routes

```text
/
/welcome
/login
/register
/forgot-password
/reset-password
/otp
/auth-callback
/role-selection
```

### Onboarding routes

```text
/member-onboarding
/seller-onboarding
/coach-onboarding
```

### Member routes

```text
/member-home
/member-profile
/edit-profile
/progress
/workout-plan
/workout-details
/my-subscriptions
/member-checkins
/member-messages
/member-thread
```

### AI routes

```text
/ai-chat-home
/ai-conversation
/ai-planner-builder
/ai-generated-plan
/ai-premium
/subscription-management
```

### News routes

```text
/news-feed
/news-article-details
```

### Store routes

```text
/store-home
/product-list
/product-details
/favorites
/cart
/checkout
/orders
```

### Coach discovery routes

```text
/coaches
/coach-details
/subscription-packages
```

### Seller routes

```text
/seller-dashboard
/product-management
/add-product
/edit-product
/seller-orders
/seller-profile
```

### Coach owner routes

```text
/coach-dashboard
/clients
/packages
/add-package
/coach-profile
```

### Settings routes

```text
/notifications
/settings
/delete-account
/help-support
/privacy-policy
/terms
```

Some routes use `FeaturePlaceholderScreen` when a feature is intentionally incomplete or required arguments are missing.

---

## 12. Auth Flow

Key files:

```text
lib/features/auth/data/datasources/auth_remote_data_source.dart
lib/features/auth/data/repositories/auth_repository_impl.dart
lib/features/auth/presentation/controllers/auth_controller.dart
lib/features/auth/presentation/controllers/google_oauth_controller.dart
lib/features/auth/presentation/screens/
lib/core/routing/auth_route_resolver.dart
```

Supported operations:

- Email/password registration.
- Email/password login.
- OTP verification for signup and recovery.
- Password reset.
- OAuth sign-in with Google and Apple, controlled by config.
- Account deletion via `delete-account`.
- Auth state stream through Supabase Auth.

Initial route logic:

1. No current user: `/welcome`
2. User exists but no profile or no role: `/role-selection`
3. Role exists but onboarding incomplete: role-specific onboarding screen
4. Onboarding complete: role-specific dashboard

Roles:

```text
member -> role_id 1
coach  -> role_id 2
seller -> role_id 3
```

---

## 13. OAuth and Deep Links

Key files:

```text
lib/core/constants/auth_constants.dart
lib/core/supabase/auth_callback_ingress.dart
lib/core/supabase/auth_callback_utils.dart
lib/core/supabase/auth_deep_link_bootstrap.dart
android/app/src/main/AndroidManifest.xml
ios/Runner/Info.plist
```

Default redirect URI:

```text
gymunity://auth-callback
```

Development support also accepts:

```text
gymunity-dev://auth-callback
```

The app disables Flutter's default deep linking handling in native config so OAuth callback URLs are consumed by the app-specific callback handling rather than being routed into the Flutter Navigator as raw paths.

---

## 14. User and Profile Layer

Feature path:

```text
lib/features/user/
```

Main tables:

```text
users
profiles
roles
```

`UserRemoteDataSource` handles:

- Current auth user.
- Account status lookup.
- Profile lookup.
- Upserting `users`.
- Upserting `profiles`.
- Updating role.
- Marking onboarding completed.
- Updating profile details.
- Uploading avatar to Storage.

The profile model includes:

- `userId`
- `email`
- `fullName`
- `avatarPath`
- `phone`
- `country`
- `role`
- `onboardingCompleted`

---

## 15. Member Feature

Feature path:

```text
lib/features/member/
```

Important screens:

```text
member_home_screen.dart
member_home_content.dart
member_profile_screen.dart
edit_profile_screen.dart
progress_screen.dart
my_subscriptions_screen.dart
member_messages_screen.dart
member_checkins_screen.dart
```

Main repository:

```text
lib/features/member/data/repositories/member_repository_impl.dart
```

Live database objects used:

```text
member_profiles
user_preferences
member_weight_entries
member_body_measurements
workout_plans
workout_sessions
subscriptions
list_member_subscriptions_detailed
list_member_orders_detailed
```

Local-only objects expected by the latest code but missing from the live database until pending migrations are applied:

```text
list_member_subscriptions_live
confirm_coach_payment
pause_coach_subscription
coach_member_threads
coach_messages
weekly_checkins
progress_photos
submit_weekly_checkin
```

Member capabilities:

- Create/update member profile during onboarding.
- Store goal, age, gender, height, weight, training frequency, experience level.
- Store newer marketplace preferences locally in code: budget, city, coaching preference, training place, preferred language, preferred coach gender.
- Save the initial onboarding weight into `member_weight_entries`.
- Read/update notification and unit/language preferences.
- Track weight history.
- Track body measurements.
- Read workout plans.
- Read and save workout sessions.
- Read subscriptions.
- Confirm coach payment and pause subscriptions when the newer schema exists.
- List coaching threads and messages when the newer schema exists.
- Submit weekly check-ins when the newer schema exists.
- Read member orders.
- Build a member home summary from latest measurements, active plan, latest workout session, and latest subscription.

Risk:

- Several member screens added for coaching engagement depend on migration `20260318000015_egypt_coaching_marketplace_v1.sql`.

---

## 16. Coach and Coach Marketplace Features

Feature paths:

```text
lib/features/coach/
lib/features/coaches/
```

The split is:

- `features/coach`: tools for the logged-in coach.
- `features/coaches`: discovery/marketplace experience for members browsing coaches.

Important screens:

```text
coach_dashboard_screen.dart
coach_clients_screen.dart
coach_packages_screen.dart
coach_package_editor_screen.dart
coaches_screen.dart
coach_details_screen.dart
subscription_packages_screen.dart
```

Main repository:

```text
lib/features/coach/data/repositories/coach_repository_impl.dart
```

Core live database objects:

```text
coach_profiles
coach_packages
coach_availability_slots
coach_reviews
subscriptions
workout_plans
notifications
list_coach_directory
list_coach_public_packages
coach_dashboard_summary
list_coach_clients
update_coach_subscription_status
```

Objects expected by the latest code but currently missing live:

```text
list_coach_directory_v2
create_coach_checkout
activate_coach_subscription_with_starter_plan
list_coach_public_reviews
submit_coach_review
```

Coach capabilities:

- Create/update coach profile.
- List public coach directory.
- Read coach details.
- Manage packages.
- Manage availability.
- Read dashboard summary.
- List clients.
- Create workout plans for members.
- Update workout plan status.
- List subscriptions.
- List pending subscription requests.
- Request coach subscription from member side.
- Activate a subscription with a starter plan.
- Read and submit reviews.

Important schema mismatch:

The latest repository code expects fields such as:

```text
city
languages
coach_gender
verification_status
response_sla_hours
trial_offer_enabled
trial_price_egp
limited_spots
testimonials_json
result_media_json
visibility_status
subtitle
outcome_summary
ideal_for
duration_weeks
sessions_per_week
difficulty_level
equipment_tags
included_features
faq_json
plan_preview_json
target_goal_tags
location_mode
weekly_checkin_type
deposit_amount_egp
renewal_price_egp
max_slots
pause_allowed
payment_rails
```

These are provided by the two pending local migrations. Without applying them, the newer coach marketplace screens are likely to fail.

---

## 17. Seller Feature

Feature path:

```text
lib/features/seller/
```

Screens:

```text
seller_dashboard_screen.dart
seller_product_management_screen.dart
seller_product_editor_screen.dart
seller_orders_screen.dart
```

Main repository:

```text
lib/features/seller/data/repositories/seller_repository_impl.dart
```

Database/storage objects:

```text
seller_profiles
profiles
products
order_items
orders
order_status_history
seller_dashboard_summary
list_seller_orders_detailed
update_store_order_status
product-images storage bucket
```

Seller capabilities:

- Create/update seller profile.
- Read dashboard metrics.
- List own products.
- Create/update products.
- Upload product images.
- Compress product images before upload.
- Delete a product if it has no order items.
- Archive a product if it is already linked to orders.
- Read seller orders.
- Read order details.
- Update order status.

Product image optimization:

- Max edge: 1600px.
- JPEG quality: 84.
- PNG level: 6.

---

## 18. Store Feature

Feature path:

```text
lib/features/store/
```

Screens:

```text
store_home_screen.dart
store_catalog_screen.dart
product_details_screen.dart
favorites_screen.dart
cart_screen.dart
checkout_preview_screen.dart
my_orders_screen.dart
order_details_screen.dart
```

Main repository:

```text
lib/features/store/data/repositories/store_repository_impl.dart
```

Database objects:

```text
products
store_carts
store_cart_items
product_favorites
shipping_addresses
store_checkout_requests
orders
order_items
order_status_history
create_store_order
list_member_orders_detailed
```

Store capabilities:

- List active non-deleted products.
- Filter by category.
- Load product details.
- Ensure the member has a cart row.
- Add items to cart.
- Update cart quantity.
- Remove cart items.
- Clear unavailable cart items.
- Favorite/unfavorite products.
- Manage shipping addresses.
- Mark a default shipping address.
- Place an order from cart through `create_store_order`.
- List member orders.
- Enrich orders with items and status history.

---

## 19. AI Chat: TAIYO

Feature path:

```text
lib/features/ai_chat/
supabase/functions/ai-chat/
```

Screens:

```text
ai_chat_home_screen.dart
ai_conversation_screen.dart
```

Main repository:

```text
lib/features/ai_chat/data/repositories/chat_repository_impl.dart
```

Database objects:

```text
chat_sessions
chat_messages
ai_user_memories
ai_session_state
ai_plan_drafts
```

Edge Function:

```text
ai-chat
```

Flutter responsibilities:

- List chat sessions.
- Create general chat sessions.
- Stream chat messages.
- Insert the user message.
- Invoke `ai-chat`.
- Retry/recover assistant replies when appropriate.
- Refresh Supabase sessions when tokens are near expiry.
- Clear local session if a JWT belongs to a different Supabase project.
- Redirect planner-specific entry points to the planner-owned guided AI Builder instead of opening the normal conversation UI.

Edge Function responsibilities:

- Read `Authorization` header.
- Validate the current user.
- Load session and recent messages.
- Build planner/member context from profile, preferences, latest weight, latest measurement, recent sessions, active plan, memories, and session state.
- Call an AI provider.
- Return a structured JSON response.
- Save assistant message.
- Save planner draft when a plan is ready.
- Update session state and long-term memories.

AI provider support in the code:

- Gemini via `GEMINI_API_KEY`.
- Groq via `GROQ_API_KEY`.

Important:

- AI provider secrets must stay in Supabase Edge Function secrets.
- They must not be placed in Flutter config.
- Normal TAIYO conversations still use `AiChatHomeScreen`, `AiConversationScreen`, `ChatRepository`, and the `ai-chat` Edge Function as before.
- New planner generation no longer sends members into a chat-style screen. Planner-specific quick chips, planner FAB actions, and planner session rows now open the guided builder or plan review.

---

## 20. AI Planner

Feature path:

```text
lib/features/planner/
```

Screens:

```text
planner_builder_screen.dart
ai_generated_plan_screen.dart
workout_plan_screen.dart
workout_day_details_screen.dart
```

Main repository:

```text
lib/features/planner/data/repositories/planner_repository_impl.dart
```

Database/RPC objects:

```text
ai_plan_drafts
workout_plans
workout_plan_days
workout_plan_tasks
workout_task_logs
activate_ai_workout_plan
list_member_plan_agenda
upsert_workout_task_log
sync_member_task_notifications
update_ai_plan_reminder_time
```

Guided builder files:

```text
lib/features/planner/domain/entities/planner_builder_entities.dart
lib/features/planner/domain/services/planner_builder_question_factory.dart
lib/features/planner/presentation/providers/planner_builder_providers.dart
lib/features/planner/presentation/screens/planner_builder_screen.dart
lib/features/planner/presentation/widgets/planner_builder_controls.dart
```

Planner route:

```text
/ai-planner-builder
```

Planner flow:

1. A member opens AI Builder from the workout plan screen or a planner-specific TAIYO entry point.
2. The builder scans available member context before asking questions:
   - member profile
   - preferences
   - latest weight
   - latest body measurement
   - workout plan history
   - workout session history
   - active AI workout plan
   - `ai_user_memories` when readable through existing RLS
3. The builder creates a known-vs-missing answer model.
4. Known values are shown as preselected confirmation steps instead of blank questions.
5. Missing or important fields are collected through structured controls such as choice chips, option pills, sliders, and guided step cards.
6. The critical fields required by the backend are:
   - goal
   - experience level
   - days per week
   - session minutes
   - equipment
7. Extra adaptive questions can be added for training location, limitations, cardio preference, workout style, focus areas, preferred days, intensity, and exercise dislikes.
8. The member reviews the collected answers before generation.
9. The builder creates or reuses a planner `chat_sessions` row and sends one structured `GYMUNITY_AI_BUILDER_REQUEST` message through `ChatRepository.sendMessage()`.
10. The existing `ai-chat` Edge Function uses server-side member context plus builder answers to create a plan draft.
11. The draft is stored in `ai_plan_drafts`.
12. `AiGeneratedPlanScreen` loads the draft for review.
13. `activate_ai_workout_plan` converts the draft into:
   - `workout_plans`
   - `workout_plan_days`
   - `workout_plan_tasks`
14. The member completes/skips/partially completes tasks.
15. Task logs are stored through `upsert_workout_task_log`.
16. Local reminders are synced.

Adaptive questioning rules:

- If profile goal or experience already exists, it is preselected and the member confirms or edits it.
- `training_frequency` is mapped into `days_per_week`.
- Recent workout session duration can prefill `session_minutes`.
- Home training can preselect bodyweight equipment; gym training can preselect full gym equipment.
- Beginner contexts ask safety and limitation questions earlier.
- Fat-loss contexts add cardio and time-commitment style questions.
- Existing active AI plans show a replacement warning before generation. Activating the new plan archives the previous active AI plan through the existing RPC behavior.

Review behavior:

- `AiGeneratedPlanScreen` remains the polished plan review and activation screen.
- Activation still uses `PlannerActionController.activateDraft()`.
- Chat-style refinement actions were removed from the planner review. Planner-owned actions now send the user back to AI Builder or improve the plan without exposing the normal chat screen.

---

## 21. Planner Local Notifications

Files:

```text
lib/features/planner/data/services/planner_reminder_bootstrap_service.dart
lib/features/planner/data/services/planner_notification_ids.dart
```

Behavior:

- Resolve device timezone.
- Call `sync_member_task_notifications`.
- Load agenda for the next 60 days.
- Select schedulable tasks:
  - plan source is `ai`
  - plan status is `active`
  - task has `reminder_time`
  - completion status is `pending`
- Request permissions when needed.
- Schedule local notifications.
- Cancel outdated planner notifications.

Android permissions:

```text
INTERNET
POST_NOTIFICATIONS
RECEIVE_BOOT_COMPLETED
SCHEDULE_EXACT_ALARM
```

---

## 22. News Feature

Feature path:

```text
lib/features/news/
supabase/functions/sync-news-feeds/
```

Screens:

```text
news_feed_screen.dart
news_article_details_screen.dart
```

Main files:

```text
lib/features/news/data/repositories/news_repository_impl.dart
lib/features/news/data/models/news_article_model.dart
lib/features/news/domain/entities/news_article.dart
lib/features/news/presentation/controllers/news_controller.dart
lib/features/news/presentation/providers/news_feed_provider.dart
```

Database/RPC objects:

```text
news_sources
news_articles
news_article_topics
news_article_interactions
news_article_bookmarks
user_news_interests
list_personalized_news
list_news_article_topics
track_news_interaction
save_news_article
dismiss_news_article
list_saved_news_articles
sync_member_news_interests
```

News capabilities:

- Load personalized articles.
- Paginate with offset-based cursors.
- Track impressions for the first few articles.
- Track open/click events.
- Save and unsave articles.
- Dismiss articles.
- Load article details with source and topic information.

`sync-news-feeds` behavior:

- Reads active rows from `news_sources`.
- Fetches RSS feeds.
- Normalizes entries into article rows.
- Deduplicates by canonical URL/hash.
- Classifies topics, goals, levels, roles, evidence, trust, quality, and safety.
- Upserts `news_articles`.
- Rebuilds `news_article_topics`.
- Supports `dry_run`.
- Uses `NEWS_SYNC_SECRET`.
- Can be triggered by `pg_cron`.

---

## 23. Monetization / AI Premium

Feature path:

```text
lib/features/monetization/
supabase/functions/billing-*
```

Screens:

```text
ai_premium_paywall_screen.dart
subscription_management_screen.dart
```

Database objects:

```text
billing_products
billing_customers
store_transactions
subscription_entitlements
billing_sync_events
ensure_billing_customer
```

Flutter capabilities:

- Read `ENABLE_AI_PREMIUM` and store product IDs from `AppConfig`.
- Load Apple/Google product metadata.
- Start a store purchase.
- Restore purchases.
- Query existing Android purchases.
- Sync purchase data to the backend.
- Refresh current entitlement.

Expected Edge Functions:

```text
billing-verify-google
billing-verify-apple
billing-refresh-entitlement
billing-google-rtdn
billing-apple-notifications
```

Current live state:

- Billing tables exist.
- Flutter billing code exists.
- Billing Edge Functions exist locally.
- Billing Edge Functions are not currently deployed on the live Supabase project.

Do not enable AI Premium for a production build until the billing functions and secrets are deployed.

---

## 24. Settings, Support, and Account Deletion

Feature path:

```text
lib/features/settings/
```

Screens:

```text
settings_screen.dart
notifications_screen.dart
delete_account_screen.dart
support_and_legal_screens.dart
```

Settings capabilities:

- Read and update member preferences.
- Show notifications.
- Open support/legal URLs.
- Delete account.

Account deletion flow:

1. The app calls the `delete-account` Edge Function.
2. If the current auth provider is email/password, the app requires current password confirmation before calling the function.
3. The function validates the JWT.
4. The function calls `prepare_account_for_hard_delete`.
5. It removes user-owned storage files.
6. It deletes the Supabase Auth user through the admin API.

---

## 25. Live Database Tables

These public tables exist in the live Supabase database.

### Identity and profile

```text
roles
users
profiles
user_preferences
```

### Member data

```text
member_profiles
member_weight_entries
member_body_measurements
workout_sessions
```

### Coach and subscriptions

```text
coach_profiles
coach_packages
coach_availability_slots
coach_reviews
subscriptions
workout_plans
```

### AI and planner

```text
chat_sessions
chat_messages
ai_plan_drafts
ai_user_memories
ai_session_state
workout_plan_days
workout_plan_tasks
workout_task_logs
```

### Store and orders

```text
products
store_carts
store_cart_items
product_favorites
shipping_addresses
store_checkout_requests
orders
order_items
order_status_history
```

### Billing

```text
billing_products
billing_customers
store_transactions
subscription_entitlements
billing_sync_events
```

### News

```text
news_sources
news_articles
news_article_topics
news_article_interactions
news_article_bookmarks
user_news_interests
```

### Notifications

```text
device_tokens
notifications
```

---

## 26. Important Live RPC Functions

Important functions currently present in the live `public` schema:

```text
current_role
soft_delete_account
prepare_account_for_hard_delete
create_store_order
update_store_order_status
seller_dashboard_summary
list_member_orders_detailed
list_seller_orders_detailed
list_coach_directory
list_coach_public_packages
list_coach_clients
update_coach_subscription_status
ensure_billing_customer
activate_ai_workout_plan
upsert_workout_task_log
list_member_plan_agenda
sync_member_task_notifications
update_ai_plan_reminder_time
list_personalized_news
list_news_article_topics
list_saved_news_articles
track_news_interaction
save_news_article
dismiss_news_article
upsert_user_news_interest
bump_user_news_interest
sync_member_news_interests
normalize_news_goal
normalize_news_level
news_target_matches
news_safe_jsonb_array
```

Important functions expected by local code but currently not present live:

```text
list_coach_directory_v2
list_member_subscriptions_live
ensure_coach_member_thread
create_coach_checkout
confirm_coach_payment
submit_weekly_checkin
pause_coach_subscription
switch_coach_request
sync_coach_thread_after_message
```

---

## 27. RLS Summary

The schema uses Row Level Security heavily.

Main policy pattern:

- User-owned rows are tied to `auth.uid()`.
- Members manage member-owned data.
- Coaches manage coach-owned data.
- Sellers manage seller-owned data.
- Active products can be read by authenticated users.
- Coach profiles and reviews are readable by authenticated users.
- Orders can be read by the member or seller side.
- Chat messages can be read only if the session belongs to the user.
- News articles must be active, safe, and from an active source.
- Avatar files are private to the owning user.
- Product images are public read but seller-owned write.

---

## 28. Key Data Flows

### Registration and onboarding

1. User registers or signs in.
2. Supabase Auth creates or restores the auth session.
3. The app ensures rows in `users` and `profiles`.
4. If no role exists, the app opens role selection.
5. The selected role writes `profiles.role_id`.
6. The app opens the role-specific onboarding screen.
7. Onboarding writes role-specific profile rows.
8. `profiles.onboarding_completed` becomes true.
9. The user lands on the role dashboard.

### Member onboarding

1. Member enters goal, age, gender, height, current weight, training frequency, and experience level.
2. `member_profiles` is upserted.
3. `profiles.onboarding_completed` is set to true.
4. The first `member_weight_entries` row is inserted if none exists.

### Seller product management

1. Seller creates or edits a product.
2. `products` is inserted/updated.
3. Product images are compressed and uploaded to `product-images`.
4. If a product has order history, delete becomes archive.
5. If no order history exists, product deletion can remove storage images.

### Store checkout

1. Member adds products to cart.
2. `store_carts` is created if missing.
3. `store_cart_items` stores product quantities.
4. Member selects a shipping address.
5. `create_store_order` creates one or more orders.
6. Order items and status history are created.
7. Inventory is adjusted by the database function.

### AI plan activation

1. Member starts AI Builder.
2. AI Builder scans member profile, preferences, progress, workout history, active plans, and memories.
3. AI Builder collects only missing or quality-critical answers in a structured wizard.
4. AI Builder sends one structured planner request through the existing `ai-chat` generation path.
5. TAIYO stores a draft in `ai_plan_drafts`.
6. Member reviews the draft on `AiGeneratedPlanScreen`.
7. `activate_ai_workout_plan` creates a real workout plan.
8. `workout_plan_days` and `workout_plan_tasks` are generated.
9. Member task completion writes to `workout_task_logs`.
10. Local notifications are scheduled.

### News ingestion and feed

1. `sync-news-feeds` reads active `news_sources`.
2. It fetches RSS feeds and classifies articles.
3. It writes `news_articles` and `news_article_topics`.
4. App calls `list_personalized_news`.
5. Interactions are recorded in `news_article_interactions`.
6. Saves are stored in `news_article_bookmarks`.

### Account deletion

1. User opens Delete Account.
2. Email/password users provide current password.
3. Flutter invokes `delete-account`.
4. The function validates the auth token.
5. The database prepares related records for deletion.
6. Storage files are removed.
7. The auth user is deleted.

---

## 29. Tests

Test folder:

```text
test/
```

Existing tests include:

```text
ai_chat_personalization_test.dart
auth_callback_utils_test.dart
auth_flow_screen_test.dart
auth_route_resolver_test.dart
auth_token_project_ref_test.dart
chat_controller_test.dart
delete_account_screen_test.dart
historical_record_utils_test.dart
manual_live_planner_repository_test.dart
member_home_shell_test.dart
news_article_model_test.dart
news_card_test.dart
news_feed_screen_test.dart
onboarding_behavior_test.dart
planner_notification_ids_test.dart
planner_builder_question_factory_test.dart
planner_builder_screen_test.dart
planner_reminder_bootstrap_service_test.dart
planner_summary_provider_test.dart
role_selection_test.dart
routes_and_features_test.dart
widget_test.dart
workout_plan_screen_test.dart
```

Recommended test command:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\flutter_test_dev.ps1
```

---

## 30. Practical Risks and Next Steps

### 1. The code is ahead of the live database

The biggest current risk is schema drift. The latest code uses objects from:

```text
20260317000014_coach_offers_marketplace.sql
20260318000015_egypt_coaching_marketplace_v1.sql
```

but those migrations are not applied live.

Apply these before relying on:

- new coach marketplace filters
- new package fields
- coach checkout
- manual payment confirmation
- coach/member message threads
- weekly check-ins
- progress photos
- subscription pause/switch flows

### 2. Billing functions are local but not deployed

AI Premium should stay disabled until these are deployed:

```text
billing-verify-google
billing-verify-apple
billing-refresh-entitlement
billing-google-rtdn
billing-apple-notifications
```

### 3. Do not store secrets in Flutter

Allowed in Flutter config:

- Supabase URL
- Supabase anon key
- public URLs
- feature flags
- store product IDs

Not allowed in Flutter config:

- Supabase service role key
- Supabase personal access token
- AI provider keys
- store server credentials

### 4. AI secrets belong in Edge Function secrets

Examples:

```text
SUPABASE_SERVICE_ROLE_KEY
GROQ_API_KEY
GROQ_MODEL
GEMINI_API_KEY
GEMINI_MODEL
NEWS_SYNC_SECRET
```

### 5. Rotate the shared access token

Because a Supabase access token was pasted into the conversation, rotate or revoke it in Supabase after this work is complete.

---

## 31. File Map

Startup:

```text
lib/main.dart
lib/app/app.dart
lib/app/routes.dart
```

Config and Supabase:

```text
lib/core/config/app_config.dart
lib/core/config/local_runtime_config_loader.dart
lib/core/supabase/supabase_initializer.dart
lib/core/supabase/auth_token_project_ref.dart
```

Dependency injection:

```text
lib/core/di/providers.dart
```

Auth:

```text
lib/features/auth/
lib/core/routing/auth_route_resolver.dart
lib/core/supabase/auth_callback_*.dart
```

User/profile:

```text
lib/features/user/
```

Member:

```text
lib/features/member/
```

Coach:

```text
lib/features/coach/
lib/features/coaches/
```

Seller:

```text
lib/features/seller/
```

Store:

```text
lib/features/store/
```

AI chat:

```text
lib/features/ai_chat/
supabase/functions/ai-chat/
```

Planner:

```text
lib/features/planner/
lib/features/planner/domain/entities/planner_builder_entities.dart
lib/features/planner/domain/services/planner_builder_question_factory.dart
lib/features/planner/presentation/providers/planner_builder_providers.dart
lib/features/planner/presentation/screens/planner_builder_screen.dart
lib/features/planner/presentation/widgets/planner_builder_controls.dart
```

News:

```text
lib/features/news/
supabase/functions/sync-news-feeds/
```

Monetization:

```text
lib/features/monetization/
supabase/functions/billing-*
```

Supabase:

```text
supabase/migrations/
supabase/sql/
supabase/config.toml
supabase/functions/
```
