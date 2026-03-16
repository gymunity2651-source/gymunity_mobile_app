# GymUnity Repository Description

## 1. Purpose of This Document

This file is a repository-grounded description of the GymUnity project as it exists in the current workspace.

It is intended to answer these questions in one place:

- What GymUnity is as a product
- How the Flutter app is organized
- How authentication, roles, onboarding, and routing work
- What each feature area does today
- What the Supabase backend contains
- Which database tables, RPCs, storage buckets, and Edge Functions exist
- How configuration, local development, testing, and operations are structured
- Which parts are implemented, partially implemented, or still placeholders

This document is based on the actual code in:

- `lib/`
- `supabase/migrations/`
- `supabase/functions/`
- `supabase/sql/`
- `scripts/`
- `test/`
- `docs/`

Repository state reflected here includes the hard-delete account flow introduced in `20260316000011_hard_delete_account.sql`.

## 2. Product Definition

GymUnity is a multi-role Flutter application backed by Supabase.

It combines several product surfaces into one mobile app:

- A member fitness experience
- A coach discovery and coaching workflow
- A seller storefront and order management workflow
- AI-assisted chat and AI plan generation
- In-app purchase based premium access for AI functionality
- Notifications, settings, legal links, support links, and account deletion

The app is not a single-role product.

The same authenticated account can be routed into one of three product roles:

- Member
- Coach
- Seller

Those roles are reflected in both Flutter routing logic and the Supabase data model.

## 3. Product Model in Plain Terms

At the business level, the app is built around these user stories:

### Member

A member can:

- Register or sign in
- Choose the member role
- Complete member onboarding
- Maintain a member profile
- Track body measurements and weight
- Log workout sessions
- Browse coaches
- Request coach subscriptions
- Receive and review workout plans
- Use AI chat
- Generate AI workout plans
- Buy AI premium through store billing
- Browse store products
- Favorite products
- Add products to a cart
- Save shipping addresses
- Place store orders
- View order history
- Read notifications
- Manage app settings
- Delete the account

### Coach

A coach can:

- Register or sign in
- Choose the coach role
- Complete coach onboarding
- Maintain coach-specific profile data
- Publish coaching packages
- Manage availability slots
- View a coach dashboard summary
- View subscription requests and active subscriptions
- Review client lists
- Create workout plans for members
- Receive notifications related to coaching

### Seller

A seller can:

- Register or sign in
- Choose the seller role
- Complete seller onboarding
- Maintain seller/store profile data
- Create and update products
- Upload product images
- Archive or delete products depending on historical order linkage
- View seller dashboard metrics
- View seller order lists
- Update order statuses

## 4. Main Technology Stack

### Frontend stack

- Flutter
- Riverpod
- Supabase Flutter SDK
- `google_fonts`
- `url_launcher`
- `image_picker`
- `image`
- `fl_chart`
- `flutter_local_notifications`
- `timezone`
- `flutter_timezone`
- `in_app_purchase`
- `in_app_purchase_android`
- `in_app_purchase_storekit`

### Backend stack

- Supabase Postgres
- Supabase Auth
- Supabase Storage
- Supabase Edge Functions
- PostgreSQL RLS
- SQL RPC functions exposed through Supabase

### AI provider layer

The AI chat Edge Function currently supports a provider abstraction and, in the present implementation, uses Groq if `GROQ_API_KEY` is available.

The default Groq model fallback inside the Edge Function is:

- `openai/gpt-oss-120b`

### Language and tooling

- Dart / Flutter SDK `^3.11.1`
- TypeScript in Supabase Edge Functions
- PowerShell helper scripts for local runtime config and launch flows

## 5. Repository Layout

The repository is feature-oriented.

### Top-level directories

- `lib/`: Flutter application code
- `supabase/migrations/`: incremental database migrations
- `supabase/sql/`: cumulative SQL bundle for manual dashboard setup
- `supabase/functions/`: Edge Functions
- `scripts/`: local development helper scripts
- `docs/`: operational and implementation notes
- `test/`: Flutter test suite
- `assets/`: images and local config assets

### `lib/` structure

- `lib/app/`
  - app shell
  - routing
- `lib/core/`
  - configuration
  - dependency injection
  - theme
  - constants
  - shared services
  - Supabase bootstrap utilities
  - reusable widgets
  - small utilities
- `lib/features/`
  - `ai_chat/`
  - `auth/`
  - `coach/`
  - `coaches/`
  - `member/`
  - `monetization/`
  - `onboarding/`
  - `planner/`
  - `seller/`
  - `settings/`
  - `store/`
  - `user/`

### Feature split pattern

Most features follow a pragmatic layered structure:

- `domain/`
  - entities
  - repository interfaces
- `data/`
  - repository implementations
  - remote data sources
- `presentation/`
  - providers
  - controllers
  - screens
  - models/widgets where needed

The project is clean-architecture influenced, but not rigidly doctrinal.

## 6. Application Boot Process

### `main.dart`

Startup begins in `lib/main.dart`.

The startup order is:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `LocalRuntimeConfigLoader.primeIfNeeded()`
3. `SupabaseInitializer.initialize()` if config is valid
4. `runApp(const ProviderScope(child: GymUnityApp()))`

### Why runtime config matters before app launch

GymUnity does not directly read `.env` from Flutter runtime.

Instead:

- local scripts translate `.env` into `--dart-define`
- `AppConfig` reads compile-time values through `String.fromEnvironment`
- `assets/config/local_env.json` can act as a fallback source through `LocalRuntimeConfigLoader`

If config is invalid:

- the app still boots
- but the splash/bootstrap flow resolves to a configuration error state

### `GymUnityApp`

The root widget in `lib/app/app.dart`:

- extends `ConsumerStatefulWidget`
- observes app lifecycle
- starts monetization bootstrap on first frame
- starts planner reminder bootstrap on first frame
- refreshes premium entitlements on app resume
- syncs planner reminders on app resume
- wires the app theme and route generator

### MaterialApp setup

The app shell uses:

- `title: AppStrings.appName`
- `debugShowCheckedModeBanner: false`
- `theme: AppTheme.darkTheme`
- `initialRoute: AppRoutes.splash`
- `onGenerateRoute: AppRoutes.onGenerateRoute`

## 7. Runtime Configuration Model

The central runtime model is `AppConfig`.

### AppConfig fields

The app currently models:

- environment
- Supabase URL
- Supabase anon key
- auth redirect scheme
- auth redirect host
- privacy policy URL
- terms URL
- support URL
- support email
- support email subject
- reviewer login help URL
- feature flags for coach role
- feature flags for seller role
- feature flags for Apple sign-in
- feature flags for store purchases
- feature flags for coach subscriptions
- feature flag for AI premium
- Apple AI premium monthly product id
- Apple AI premium annual product id
- Google AI premium subscription id
- Google AI premium monthly base plan id
- Google AI premium annual base plan id

### Environment model

`AppEnvironment` currently supports:

- `dev`
- `staging`
- `prod`

### Config validation behavior

The app validates:

- non-empty Supabase URL
- valid absolute URLs for support/legal links when provided
- support contact presence in production
- product ids if AI premium is enabled

### Auth redirect behavior

The configured redirect URI is:

- `AUTH_REDIRECT_SCHEME://AUTH_REDIRECT_HOST`

Development also accepts fallback schemes:

- `gymunity`
- `gymunity-dev`

## 8. Dependency Injection and Global Providers

Global DI lives in `lib/core/di/providers.dart`.

### Core providers

- `supabaseClientProvider`
- `authCallbackIngressProvider`
- `authRemoteDataSourceProvider`
- `authRepositoryProvider`
- `userRemoteDataSourceProvider`
- `userRepositoryProvider`
- `storeRepositoryProvider`
- `coachRepositoryProvider`
- `memberRepositoryProvider`
- `plannerRepositoryProvider`
- `sellerRepositoryProvider`
- `inAppPurchaseProvider`
- `billingRepositoryProvider`
- `entitlementRepositoryProvider`
- `chatRepositoryProvider`

### State providers

- `authSessionProvider`
- `currentUserProfileProvider`
- `appRoleProvider`
- `authRouteResolverProvider`

The design choice here is straightforward:

- repositories are global providers
- controllers sit in feature presentation layers
- `authSessionProvider` is a shared stream of the current auth session
- `currentUserProfileProvider` is the app-wide profile read point

## 9. Routing System

Routing is centralized in `lib/app/routes.dart`.

### Auth and bootstrap routes

- `/`
- `/welcome`
- `/login`
- `/register`
- `/forgot-password`
- `/reset-password`
- `/otp`
- `/auth-callback`
- `/role-selection`

### Onboarding routes

- `/member-onboarding`
- `/seller-onboarding`
- `/coach-onboarding`

### Member routes

- `/member-home`
- `/member-profile`
- `/edit-profile`
- `/progress`
- `/workout-plan`
- `/workout-details`

### AI and monetization routes

- `/ai-chat-home`
- `/ai-conversation`
- `/ai-generated-plan`
- `/ai-premium`
- `/subscription-management`

### Store routes

- `/store-home`
- `/product-list`
- `/product-details`
- `/favorites`
- `/cart`
- `/checkout`
- `/orders`

### Coach discovery routes

- `/coaches`
- `/coach-details`
- `/subscription-packages`
- `/my-subscriptions`

### Seller routes

- `/seller-dashboard`
- `/product-management`
- `/add-product`
- `/edit-product`
- `/seller-orders`
- `/seller-profile`

### Coach-owner routes

- `/coach-dashboard`
- `/clients`
- `/packages`
- `/add-package`
- `/coach-profile`

### Settings routes

- `/notifications`
- `/settings`
- `/delete-account`
- `/help-support`
- `/privacy-policy`
- `/terms`

### Placeholder routing behavior

Several routes currently resolve to `FeaturePlaceholderScreen` rather than full feature screens.

These include:

- edit profile
- progress
- my subscriptions
- seller profile
- coach clients
- coach packages
- add package
- coach profile
- unknown routes

The placeholders are explicit, route-safe, and intentionally descriptive rather than broken.

## 10. App Bootstrap State Machine

The splash/bootstrap logic lives mainly in:

- `AppBootstrapController`
- `SplashScreen`
- `AuthRouteResolver`

### Bootstrap states

- `loading`
- `authenticated`
- `unauthenticated`
- `configError`
- `backendError`
- `deletedAccount`

### Actual bootstrap flow

At launch:

1. validate config
2. initialize Supabase
3. start auth deep-link bootstrap
4. read current authenticated user from Supabase
5. if no user exists, route to welcome
6. if user exists, read account status from `public.users`
7. if status is legacy deleted/inactive, sign out and show deleted-account state
8. otherwise resolve role/onboarding route with `AuthRouteResolver`

This means the app treats authentication as:

- Supabase auth session
- plus database-backed account state
- plus role
- plus onboarding completion

## 11. Authentication System

The auth feature supports:

- email/password login
- registration
- signup OTP verification
- forgot password
- password reset
- OAuth sign-in
- auth callback completion
- logout
- account deletion

### Main auth classes

- `AuthRemoteDataSource`
- `AuthRepositoryImpl`
- `AuthController`
- `GoogleOAuthController`
- `AppBootstrapController`
- `AuthCallbackScreen`
- `OtpScreen`
- `LoginScreen`
- `RegisterScreen`
- `ForgotPasswordScreen`
- `ResetPasswordScreen`

### Login flow

Email/password login:

1. `AuthController.login`
2. `AuthRepositoryImpl.login`
3. `AuthRemoteDataSource.signInWithPassword`
4. bootstrap profile through `UserRepository.ensureUserAndProfile`

### Registration flow

Registration:

1. `AuthController.register`
2. `AuthRepositoryImpl.register`
3. `AuthRemoteDataSource.signUp`
4. if session exists immediately, bootstrap profile
5. if session is absent, route to OTP verification

### OTP flow

OTP is used for:

- signup confirmation
- recovery/reset-related flows

The app models OTP mode through `OtpFlowMode`.

### OAuth flow

OAuth handling includes:

- browser launch through Supabase auth
- deep-link callback normalization
- polling and timeout handling
- callback ingestion through Android-specific paths and `app_links`

### Post-auth bootstrap

After a successful auth session the app ensures:

- `public.users` row exists
- `public.profiles` row exists

That behavior lives in `UserRepositoryImpl.ensureUserAndProfile`.

### Legacy deletion protection

For older soft-deleted accounts, the app still treats database state as authoritative and will block bootstrap if the account is marked inactive or deleted in `public.users`.

## 12. Role System

Roles are first-class in both UI and backend.

### Role persistence

Roles are stored via:

- `public.roles`
- `public.profiles.role_id`

### Role helper SQL

`public.current_role()` returns the role code for `auth.uid()`.

### Supported role codes

- `member`
- `coach`
- `seller`

### Role impact

Role affects:

- route resolution
- onboarding path
- RLS permissions
- accessible tables
- feature visibility

## 13. Route Resolution Rules

`AuthRouteResolver` is the central route policy object.

### Resolution logic

- no authenticated user -> welcome
- authenticated but no role -> role-selection
- role exists but onboarding incomplete -> role-specific onboarding
- role exists and onboarding complete -> role-specific dashboard

### Dashboard mapping

- member -> member home
- coach -> coach dashboard
- seller -> seller dashboard

### Onboarding mapping

- member -> member onboarding
- coach -> coach onboarding
- seller -> seller onboarding

## 14. Onboarding Flows

Onboarding is persisted, not cosmetic.

### Member onboarding

Writes include:

- `member_profiles`
- `profiles.onboarding_completed`
- optional weight tracking seeds

Captured member fields include:

- goal
- age
- gender
- height
- current weight
- training frequency
- experience level

### Coach onboarding

Writes include:

- `coach_profiles`
- `profiles.onboarding_completed`

Captured coach fields include:

- bio
- specialties
- years of experience
- hourly rate
- delivery mode
- service summary

### Seller onboarding

Writes include:

- `seller_profiles`
- `profiles.onboarding_completed`

Captured seller fields include:

- store name
- store description
- primary category
- shipping scope
- support email

## 15. User and Profile Foundation

The `user` feature is the shared identity bridge between Supabase Auth and business data.

### Core responsibilities

- read current auth user
- read account status
- fetch profile
- ensure user/profile rows exist
- save role
- complete onboarding
- update profile details
- upload avatar

### Account status model

`AccountStatus` currently models:

- missing
- active
- inactive
- deleted

The app still uses this to block legacy soft-deleted accounts even though new account deletion is now a hard delete.

## 16. Member Experience

The member role is the largest implemented experience in the app.

### Member home

The member dashboard is a consolidated home surface that points into:

- AI tasks for today
- active plan access
- store browsing
- coach browsing
- account settings

### Member profile

The profile screen exposes:

- member summary data
- logout
- navigation into settings
- access to other member-specific areas

### Preferences

Member preferences persist in `public.user_preferences`.

Preferences include:

- push notifications enabled
- AI tips enabled
- order updates enabled
- measurement unit
- language

### Weight tracking

Weight entries live in `public.member_weight_entries`.

Each entry stores:

- member id
- weight
- recorded timestamp
- note

### Body measurements

Body measurements live in `public.member_body_measurements`.

Supported tracked values include:

- waist
- chest
- hips
- arm
- thigh
- body fat percentage
- note

### Workout sessions

Completed/real workout activity logs live in `public.workout_sessions`.

They can be linked to:

- a member
- an optional workout plan
- an optional coach

### Workout plans

The member consumes workout plans from:

- coach-created plans
- AI-generated plans

Plans are persisted in:

- `public.workout_plans`
- `public.workout_plan_days`
- `public.workout_plan_tasks`
- `public.workout_task_logs`

### Member orders and subscriptions

Members can:

- view store order history
- view coaching subscription history

Historical views are backed by RPCs so the app sees normalized, display-safe records rather than raw table joins.

## 17. Planner Experience

The planner subsystem is a dedicated feature layer around structured plans and task completion.

### Main planner flows

- show active workout plan
- show plan day details
- show AI-generated plan review screen
- update task completion logs
- show member agenda
- sync member task notifications
- update reminder time

### Planner RPCs

- `activate_ai_workout_plan`
- `upsert_workout_task_log`
- `list_member_plan_agenda`
- `sync_member_task_notifications`
- `update_ai_plan_reminder_time`

### Planner reminder bootstrap

The app starts planner reminder bootstrap on startup and refreshes/syncs it on lifecycle resume.

## 18. Coach Discovery Experience

The `coaches` feature represents the public marketplace/discovery side of coaches.

### Main capabilities

- browse coach directory
- open public coach details
- view public coach packages
- view public coach reviews
- request subscription to a package

### Main data sources

- `list_coach_directory`
- `get_coach_public_profile`
- `list_coach_public_packages`
- `list_coach_public_reviews`
- `request_coach_subscription`

### Public coach data shown

- name
- avatar
- bio
- specialties
- rate
- rating average
- rating count
- verification state
- packages
- availability
- reviews

## 19. Coach Owner Experience

The `coach` feature is the logged-in coach’s operating surface.

### Coach-specific assets

- coach dashboard summary
- packages
- availability slots
- client list
- subscriptions
- workout plan assignment
- review-backed rating aggregate

### Coach dashboard summary

The coach dashboard summary is RPC-backed and exposes:

- active clients
- pending requests
- active packages
- active plans
- rating average
- rating count

### Coach packages

Packages live in `public.coach_packages`.

Fields include:

- title
- description
- billing cycle
- price
- active state

Package delete behavior:

- delete if there is no historical linkage
- otherwise archive/deactivate

### Availability

Coach availability slots live in `public.coach_availability_slots`.

### Clients

Coach clients are derived, not manually maintained.

The list is currently computed from subscriptions, plans, and sessions through `list_coach_clients`.

After the hard-delete update, client rows with missing `member_id` are filtered out from coach operational lists.

### Coach subscriptions

Coach subscriptions live in `public.subscriptions`.

Coaches can:

- see incoming requests
- activate subscriptions
- cancel subscriptions
- complete subscriptions

### Coach review aggregate

Coach ratings are maintained through:

- `refresh_coach_rating_aggregate`
- `handle_coach_review_aggregate`
- trigger on `coach_reviews`

## 20. Store and Marketplace Experience

The store is a real data-backed product catalog, not only demo UI.

### Buyer-facing capabilities

- browse catalog
- filter by category
- open product details
- manage favorites
- manage cart
- manage shipping addresses
- place checkout requests
- view orders

### Core store entities

- products
- favorites
- carts
- cart items
- shipping addresses
- orders
- order items
- order status history

### Product model

Products contain:

- seller id
- title
- description
- category
- price
- currency
- stock quantity
- image paths
- low stock threshold
- is_active
- deleted_at

### Favorites

Favorites are stored in `public.product_favorites`.

### Cart

Cart state is stored through:

- `public.store_carts`
- `public.store_cart_items`

### Shipping addresses

Shipping addresses live in `public.shipping_addresses`.

They include:

- recipient name
- phone
- address lines
- city
- state/region
- postal code
- country code
- default flag

### Checkout

Checkout uses server-side RPC-backed order creation.

The relevant assets are:

- `public.create_store_order(...)`
- `public.store_checkout_requests`
- persisted `orders`
- persisted `order_items`
- status history

### Historical order resilience

After the hard-delete account update:

- orders can outlive member or seller identity deletion
- `seller_id` and `member_id` may be `null` in historical rows
- buyer/seller views use fallback labels such as `Deleted seller` and `Deleted member`

## 21. Seller Experience

The seller feature is the management side of the store.

### Seller dashboard

The seller dashboard summary exposes:

- total products
- active products
- low stock products
- pending payment orders
- in-progress orders
- delivered orders
- gross revenue

### Product management

Seller product management supports:

- create product
- edit product
- upload product images
- delete or archive product

### Product image handling

Product images are:

- compressed client-side
- uploaded to the `product-images` storage bucket
- stored by path in `products.image_paths`

### Delete versus archive logic

Products are:

- fully deleted if no order items reference them
- archived if historical order linkage exists

### Seller order management

Sellers can:

- list orders
- inspect order details
- update status transitions

Status transitions are enforced server-side through RPCs, not trusted to client-side state.

## 22. AI Chat Experience

The AI chat feature is a major subsystem.

### High-level responsibilities

- store chat sessions
- store chat messages
- support general coaching conversation
- support structured planner conversation
- support regeneration/refinement flows
- persist planner drafts
- persist long-term AI memory
- persist session state summaries and open loops

### Core chat tables

- `chat_sessions`
- `chat_messages`
- `ai_plan_drafts`
- `ai_user_memories`
- `ai_session_state`

### Chat session types

`chat_sessions.session_type` currently supports:

- `general`
- `planner`

### Planner-specific chat state

Planner-related session status can be:

- `idle`
- `collecting_info`
- `plan_ready`
- `plan_updated`
- `unsafe_request`
- `error`

### AI Edge Function behavior

The `ai-chat` Edge Function:

- authenticates the user
- loads planner/member/profile context
- classifies conversation mode
- selects provider
- generates structured JSON
- stores assistant messages
- stores memory updates
- stores draft state
- can activate or refine plan flows

### AI context sources

The planner/AI system pulls context from:

- profile basics
- member profile
- user preferences
- recent sessions
- current active plan
- prior profile state
- memory rows
- session state
- adherence and activity signals

### AI conversation modes

The engine models these modes:

- `general_coaching`
- `planner_collect`
- `planner_generate`
- `planner_refine`
- `progress_checkin`

### AI plan result shape

The normalized plan shape includes:

- title
- summary
- duration in weeks
- level
- start date suggestion
- safety notes
- rest guidance
- nutrition guidance
- hydration guidance
- sleep guidance
- step target
- weekly structure
- per-day tasks

## 23. AI Premium and Monetization

Monetization is focused on premium AI access.

### Main monetization pieces

- product catalog metadata
- billing customer token generation
- store transaction persistence
- entitlement persistence
- entitlement refresh
- purchase verification via Edge Functions

### Core tables

- `billing_products`
- `billing_customers`
- `store_transactions`
- `subscription_entitlements`
- `billing_sync_events`

### Flutter monetization components

- `BillingRepositoryImpl`
- `EntitlementRepositoryImpl`
- monetization bootstrap provider
- auth-aware monetization provider
- paywall screen
- subscription management screen

### Billing customer

`ensure_billing_customer()` creates or refreshes an `app_account_token` tied to the authenticated user.

### Purchase verification functions

Edge Functions include:

- `billing-verify-apple`
- `billing-verify-google`
- `billing-refresh-entitlement`
- `billing-apple-notifications`
- `billing-google-rtdn`

### Apple billing implementation

The Apple verification function:

- authenticates the user
- validates receipt data with Apple
- resolves plan code
- determines lifecycle state
- upserts billing state into Supabase

### Entitlement states

The entitlement model supports:

- enabled
- disabled
- pending
- verification_required

### Lifecycle states

The lifecycle layer includes states such as:

- pending
- active
- renewing
- cancellation requested active until expiry
- expired
- grace period
- on hold or suspended
- restored or restarted
- revoked or refunded

## 24. Notifications

Notifications are implemented as persisted backend records plus local scheduling for planner reminders.

### Core notification tables

- `device_tokens`
- `notifications`

### Notification table behavior

Notifications include:

- user id
- type
- title
- body
- data payload
- read state
- external key
- availability timestamp

### Planner reminder linkage

Planner notifications use:

- task-level reminder syncing
- `external_key`
- server-side sync logic

## 25. Settings, Legal, and Support

The settings area includes:

- app settings screen
- notifications screen
- support and legal screens
- delete account screen

### Legal/support configuration

Settings surfaces read from runtime config:

- support URL
- support email
- privacy policy URL
- terms URL
- reviewer login help URL

### Support behavior

The app can:

- open support URL
- compose support email
- open legal URLs

## 26. Account Deletion Flow

This area changed materially from the older soft-delete implementation.

### Current deletion contract

The Flutter side still calls the same Edge Function:

- `delete-account`

The payload contract is still:

- optional `current_password`

### Current user-facing behavior

The delete account screen now explains:

- deletion is permanent
- personal data is erased
- shared historical records may be kept in anonymized form
- the same email can be used again later for a brand new account

### Current Edge Function behavior

The `delete-account` Edge Function:

1. authenticates the request using the bearer token
2. resolves the auth provider
3. requires `current_password` for email/password accounts
4. calls `prepare_account_for_hard_delete(target_user_id uuid)`
5. removes `avatars/<userId>/...`
6. removes `product-images/<userId>/...`
7. calls `auth.admin.deleteUser(userId)`

### Current SQL hard-delete preparation behavior

`prepare_account_for_hard_delete`:

- deletes private member/coach/seller preference and profile data
- deletes notifications and device tokens
- deletes AI memory/session/draft records
- deletes carts, favorites, addresses, checkout requests
- deletes billing customer and user-linked billing rows
- nulls out user references in shared historical records where retention matters
- deletes member-owned workout plans
- archives coach-owned plans and nulls `coach_id`
- deletes coach packages
- deletes seller products
- deletes chat sessions

### Historical retention model

The new design retains shared history where useful:

- store orders
- order items
- coaching subscriptions

but removes or nulls identity links when the deleted user was one side of that relationship.

### Legacy soft-delete compatibility

The app still contains bootstrap handling for legacy soft-deleted accounts:

- `public.users.is_active = false`
- `public.users.deleted_at is not null`

That code is intentionally kept for older data even though new deletions are hard deletes.

## 27. Supabase Database Design

The Supabase schema is layered over a shared identity core.

### Identity foundation

- `roles`
- `users`
- `profiles`

### Role extensions

- `coach_profiles`
- `member_profiles`
- `seller_profiles`

### Member wellness data

- `user_preferences`
- `member_weight_entries`
- `member_body_measurements`
- `workout_sessions`

### Coach business data

- `coach_packages`
- `coach_availability_slots`
- `coach_reviews`

### Store data

- `products`
- `orders`
- `order_items`
- `order_status_history`
- `store_carts`
- `store_cart_items`
- `product_favorites`
- `shipping_addresses`
- `store_checkout_requests`

### Messaging and AI data

- `chat_sessions`
- `chat_messages`
- `ai_plan_drafts`
- `workout_plans`
- `workout_plan_days`
- `workout_plan_tasks`
- `workout_task_logs`
- `ai_user_memories`
- `ai_session_state`

### Notifications

- `device_tokens`
- `notifications`

### Monetization data

- `billing_products`
- `billing_customers`
- `store_transactions`
- `subscription_entitlements`
- `billing_sync_events`

## 28. Migration History

Current migration inventory:

1. `20260307000001_init_gymunity.sql`
2. `20260307000002_storage.sql`
3. `20260307000003_notifications.sql`
4. `20260311000004_coach_directory_rpc.sql`
5. `20260312000005_account_deletion.sql`
6. `20260312000006_core_role_flows.sql`
7. `20260312000007_store_orders_hardening.sql`
8. `20260312000008_monetization_billing.sql`
9. `20260313000009_ai_member_planner.sql`
10. `20260315000010_ai_personalization_memory.sql`
11. `20260316000011_hard_delete_account.sql`
12. `20260316000012_personalized_news.sql`
13. `20260316000013_news_sync_scheduler.sql`

### What the migration progression tells us

The project evolved in this order:

- base identity/store/chat schema
- storage
- notifications
- coach directory RPC
- older account deletion logic
- role and business flows
- hardened store/orders
- billing and entitlements
- AI planner foundation
- AI personalization memory
- hard-delete account correction
- personalized health/news recommendations
- scheduled news sync automation

## 29. RPC Inventory

Important public SQL functions and RPC-backed business logic include:

- `current_role`
- `list_coach_directory`
- `get_coach_public_profile`
- `list_coach_public_packages`
- `list_coach_public_reviews`
- `list_member_subscriptions_detailed`
- `list_member_orders_detailed`
- `list_seller_orders_detailed`
- `list_coach_clients`
- `seller_dashboard_summary`
- `coach_dashboard_summary`
- `create_store_order`
- `update_store_order_status`
- `request_coach_subscription`
- `update_coach_subscription_status`
- `submit_coach_review`
- `ensure_billing_customer`
- `activate_ai_workout_plan`
- `upsert_workout_task_log`
- `list_member_plan_agenda`
- `sync_member_task_notifications`
- `update_ai_plan_reminder_time`
- `prepare_account_for_hard_delete`

## 30. Row-Level Security Model

The schema uses RLS extensively.

### Broad access pattern

Most tables follow one of these shapes:

- own-read / own-write
- public-read with role-bound writes
- derived data through security definer RPCs

### Examples

- users and profiles are generally owned by `auth.uid()`
- coach public discovery uses public-ish authenticated reads
- seller products are readable when active, or by their seller owner
- order and subscription transitions are enforced through RPCs
- monetization state is user-scoped
- AI memory and planner rows are member-owned

### Why RPCs matter here

Several business flows are intentionally executed through `security definer` SQL functions rather than direct client table writes, especially where:

- multi-table consistency matters
- status transitions matter
- server-side validation matters
- side effects such as notifications matter

## 31. Storage Design

GymUnity currently uses at least two storage buckets:

### `avatars`

- private bucket
- owner-scoped read/write/delete
- file paths follow the user namespace

### `product-images`

- public-read bucket
- seller-scoped write/delete
- file paths are seller-rooted

### Storage ownership conventions

- avatar paths are under `avatars/<userId>/...`
- product images are under `<sellerId>/<productId>/...`

## 32. Edge Function Inventory

Current Edge Function directories:

- `ai-chat`
- `billing-apple-notifications`
- `billing-google-rtdn`
- `billing-refresh-entitlement`
- `billing-verify-apple`
- `billing-verify-google`
- `delete-account`
- `_shared`

### `_shared`

Shared helper layer for:

- CORS
- billing helpers

### `ai-chat`

Responsible for:

- AI response generation
- planner conversation state
- profile extraction
- memory updates
- plan generation/refinement

### `billing-verify-apple`

Responsible for:

- Apple receipt verification
- lifecycle state resolution
- entitlement upsert

### `billing-verify-google`

Parallel role for Google Play verification.

### Notification webhooks

- Apple notifications function
- Google RTDN function

These are for store-side subscription state changes outside the app runtime.

### `billing-refresh-entitlement`

Used to re-sync entitlement status for an authenticated user from backend state.

### `delete-account`

Responsible for authenticated destructive account deletion and auth user removal.

### How backend work is actually triggered

The backend is not driven by a single server process.

It is triggered through several concrete channels:

- direct Supabase client reads and writes from Flutter for simple table-backed features
- RPC calls for higher-level workflows, filtered list screens, status transitions, and dashboard summaries
- Edge Functions when secret keys, provider verification, or privileged destructive actions are required
- storage API calls for avatar and product image upload/remove flows
- Apple and Google webhook-style notifications for billing events that happen outside app runtime

In practical terms, most user actions follow one of these paths:

1. Flutter screen or provider calls a repository
2. repository chooses either table access, RPC, storage, or Edge Function
3. Supabase applies RLS and SQL-side business logic
4. Flutter maps the result into domain models and updates Riverpod state

### What happens in the background

Several important behaviors happen without a visible button press on the current screen:

- app startup loads runtime config before the widget tree is built
- auth session restoration runs on launch and may immediately redirect to the correct dashboard
- bootstrap checks re-evaluate role, profile completeness, onboarding completion, and legacy deletion state
- planner reminder setup initializes local reminder behavior on app startup
- billing flows may refresh entitlements after purchase, restore, or external platform notifications
- AI flows may update memory, extract profile signals, or persist planner drafts as part of a chat request lifecycle
- account deletion removes storage objects and auth identity after SQL cleanup has already prepared shared records

## 33. Scripts and Local Workflow

The repository includes PowerShell helper scripts:

- `scripts/flutter_with_env.ps1`
- `scripts/flutter_run_dev.ps1`
- `scripts/flutter_test_dev.ps1`
- `scripts/flutter_build_apk_dev.ps1`
- `scripts/flutter_build_appbundle_dev.ps1`
- `scripts/sync_local_runtime_config.ps1`

### Why scripts exist

Because Flutter runtime config is sourced from `--dart-define`, raw `flutter run` is not enough to reproduce the app’s intended environment.

### Command of record

Example run flow:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\flutter_run_dev.ps1 -DeviceId emulator-5554
```

## 34. Documentation Inventory

Additional repository docs include:

- `docs/google_oauth_setup.md`
- `docs/local_config_standardization.md`
- `docs/production_architecture.md`
- `docs/supabase_phase1_setup.md`
- `docs/store_orders/store_and_orders_audit.md`

### What they cover

- Google OAuth provider setup
- local config discipline
- production foundation snapshot
- Supabase dashboard setup sequence
- store/orders audit and hardening notes

## 35. Test Suite Inventory

Current Flutter test files include:

- `ai_chat_personalization_test.dart`
- `auth_callback_utils_test.dart`
- `auth_flow_screen_test.dart`
- `auth_route_resolver_test.dart`
- `auth_token_project_ref_test.dart`
- `chat_controller_test.dart`
- `delete_account_screen_test.dart`
- `historical_record_utils_test.dart`
- `onboarding_behavior_test.dart`
- `planner_notification_ids_test.dart`
- `planner_reminder_bootstrap_service_test.dart`
- `planner_summary_provider_test.dart`
- `role_selection_test.dart`
- `routes_and_features_test.dart`
- `widget_test.dart`
- `workout_plan_screen_test.dart`
- `manual_live_planner_repository_test.dart`

### What the current suite emphasizes

- auth flows
- route safety
- onboarding behavior
- planner summaries and notifications
- chat controller error handling
- utility behavior
- screen-level widget behavior

Edge Function tests also exist for at least:

- `supabase/functions/ai-chat/engine_test.ts`
- `supabase/functions/delete-account/index_test.ts`

## 36. Screens That Are Fully Data-Backed vs Placeholder-Backed

### Strongly data-backed screens today

- splash
- welcome
- login
- register
- forgot password
- reset password
- OTP
- role selection
- onboarding screens
- member home
- member profile
- AI chat home
- AI conversation
- AI generated plan
- AI premium paywall
- subscription management
- store home
- store catalog
- product details
- favorites
- cart
- checkout preview
- my orders
- coaches
- coach details
- subscription packages
- seller dashboard
- seller product management
- seller product editor
- seller orders
- notifications
- settings
- help/support
- privacy policy
- terms
- delete account

### Placeholder-backed or partial screens

- edit profile
- progress route
- my subscriptions route
- seller profile route
- coach clients route
- coach packages route
- add package route
- coach profile route

These surfaces are deliberately routed, but not yet fully wired to final production UI behavior.

## 37. Current Architectural Reality

GymUnity is not a small toy app anymore.

The repository already has:

- real multi-role auth
- role-aware onboarding
- a shared profile core
- store/catalog/order persistence
- coach package and subscription persistence
- AI planner persistence
- billing state persistence
- notification persistence
- storage uploads
- hard-delete account handling

At the same time, the app is still in active buildout.

Some areas are clearly mature in backend modeling but not yet equally mature in final UI:

- coach owner screens
- some profile editing surfaces
- some management screens currently routed to placeholders

## 38. End-to-End Product Flows

### First-time user flow

1. open app
2. splash validates config and backend state
3. user lands on welcome
4. user registers or logs in
5. profile bootstrap creates `users` and `profiles`
6. role selection is required if role is missing
7. role-specific onboarding is required if onboarding is incomplete
8. user reaches role-specific dashboard

### Returning member flow

1. app restores auth session
2. bootstrap validates account state
3. route resolver sends member to member home
4. member can continue AI plan, browse coaches, browse store, or manage settings

### Returning coach flow

1. app restores auth session
2. route resolver sends coach to coach dashboard
3. coach manages packages, availability, subscriptions, and plans

### Returning seller flow

1. app restores auth session
2. route resolver sends seller to seller dashboard
3. seller manages products and orders

### Account deletion and re-registration flow

1. user confirms delete account
2. Edge Function prepares data for hard delete
3. storage objects are removed
4. auth user is deleted
5. user is signed out
6. the same email may be used later to create a brand new account

## 39. Summary

GymUnity is a Flutter + Supabase multi-role fitness platform with:

- shared authentication
- role-aware onboarding
- member wellness tracking
- coach discovery and package subscriptions
- seller product and order management
- AI chat and AI workout planning
- AI premium billing
- notifications and planner reminders
- storage-backed avatars and product images
- a modern hard-delete account flow that allows future re-registration with the same email

The backend is centered on a relational Supabase schema with RLS and many `security definer` RPCs.

The frontend is centered on Riverpod-managed repositories and feature-oriented modules.

The codebase already contains substantial real behavior, plus a smaller set of clearly marked placeholder routes that represent the next UI integration layer rather than missing architectural foundations.
