# GymUnity Technical Reference

Repo audit date: 2026-04-21  
Live snapshot last verified: 2026-04-20  
Project root: `c:\Flutter_projects\my_app`  
Primary app: Flutter mobile application backed by Supabase  
Reference status: repo-backed audit of the current working tree with live Supabase claims retained only from the last verified snapshot above

## 1. Evidence Model And Scope

This file is intended to be the canonical technical reference for GymUnity as it exists in this repository at the repo audit date above.

Evidence labels used throughout:

| Label | Meaning |
| --- | --- |
| `[Code]` | Verified directly from Flutter/Dart, scripts, or Edge Function source in this working tree. |
| `[Migration]` | Verified from `supabase/migrations/`. |
| `[Live]` | Verified read-only against the linked Supabase project on 2026-04-20. Live claims were not re-verified in the 2026-04-21 repo audit because Supabase CLI access returned `401 Unauthorized` and requested `SUPABASE_DB_PASSWORD`. |
| `[Docs]` | Found in repository documentation only; treated as secondary evidence. |
| `[Inferred]` | Reasonable conclusion from implementation structure, but not directly proven by a single source. |
| `[Risk]` | Known operational, implementation, parity, security, or maintainability risk. |

Source priority:

1. Current code under `lib/`, `supabase/functions/`, `scripts/`, and `test/`.
2. Current migrations under `supabase/migrations/`.
3. Last verified read-only live Supabase snapshot from 2026-04-20.
4. Existing docs such as `docs/gymunity_project_full_documentation.md` and `README.md`.

Important scope note:

- The working tree is dirty and includes untracked coach workspace screens, coach-member-insights files, the new `lib/features/ai_coach/` Flutter module, the repo-defined `supabase/functions/ai-coach/` Edge Function, refreshed app-icon/build files, and migrations through `supabase/migrations/20260421000024_taiyo_member_os.sql`.
- This reference documents the current workspace, not only committed Git history.
- The last verified live Supabase snapshot on 2026-04-20 confirmed project metadata, auth configuration, deployed Edge Functions, storage buckets, and remote migration history through `20260418000017`.
- The 2026-04-21 repo audit could not refresh live Supabase evidence because `supabase migration list --linked` returned `401 Unauthorized` and requested `SUPABASE_DB_PASSWORD`.

## 2. Project Identity

GymUnity is a multi-role fitness platform for:

| Role | Product purpose |
| --- | --- |
| `member` | Fitness user who tracks profile, progress, AI plans, nutrition, coaching subscriptions, store orders, and news. |
| `coach` | Service provider who publishes coaching offers, manages a CRM-style workspace, reviews receipts/check-ins, assigns programs/resources/onboarding flows, books sessions, and views consent-gated member insights. |
| `seller` | Commerce provider who manages products, uploads product images, and fulfills store orders. |

Major product surfaces:

- Authentication and role onboarding.
- Member home shell with editorial home, TAIYO Coach, coaches, store, news, profile, progress, planner, nutrition, and settings surfaces.
- Coach marketplace and coach detail/package purchase flow.
- Coach workspace shell with dashboard metrics, client pipeline, client workspace, check-in inbox, calendar/session booking, billing verification, program library, onboarding flows, resources, coach profile, and member insight dashboard.
- Seller dashboard, seller profile, product management, image upload, and seller order management.
- Store catalog, product details, favorites, cart, checkout, and member order history.
- TAIYO chat, TAIYO Coach daily brief, nudges, active workout companion, weekly summaries, and TAIYO Plan Builder.
- AI-generated planner activation, agenda, task logs, local planner reminders, and active workout session handoff.
- Nutrition profile, target calculation, generated 7-day meal plans, meal completion, quick meal logging, hydration logging, and nutrition check-ins.
- Personalized news feed and article details.
- Settings, notifications, support/legal, subscription management, and account deletion.

AI brand identity:

| Term | Meaning |
| --- | --- |
| `TAIYO` | The in-app AI assistant name from `lib/core/constants/ai_branding.dart`. |
| `TAIYO Coach` | The routed AI landing experience for daily brief, nudges, readiness updates, and guided workouts. |
| `TAIYO Premium` | Monetized AI subscription name used by AI gating and paywall copy. |
| `TAIYO Plan Builder` | Guided AI workout-plan generation flow. |
| `TAIYO Member OS` | Repo-defined backend layer for readiness, adaptations, nudges, active workout sessions, and weekly summaries introduced by migration `20260421000024`. |

Maturity level:

- `[Code]` The app is beyond a prototype: most route targets are real screens, repositories are Supabase-backed, and the backend has a large migration set.
- `[Code]` There are still fallback placeholders for routes that require arguments and are opened without them.
- `[Live]` The last verified live snapshot still had only three deployed Edge Functions: `ai-chat`, `delete-account`, and `sync-news-feeds`.
- `[Code]` The current workspace also includes repo-defined TAIYO Coach surfaces in `lib/features/ai_coach/`, `supabase/functions/ai-coach/`, and `supabase/migrations/20260421000024_taiyo_member_os.sql`.
- `[Risk]` Monetization is not production-complete if `ENABLE_AI_PREMIUM=true`: the client references billing functions that do not exist as source implementations or are not deployed live.
- `[Risk]` Newly added coach workspace, TAIYO Coach, program delivery, onboarding, calendar, billing, and public-profile feature areas are still partly untracked in Git and must be committed or intentionally excluded before release.

## 3. App Startup And Runtime

### 3.1 Startup Chain

Source files:

- `lib/main.dart`
- `lib/app/app.dart`
- `lib/features/auth/presentation/controllers/app_bootstrap_controller.dart`
- `lib/features/auth/presentation/screens/splash_screen.dart`
- `lib/core/config/app_config.dart`
- `lib/core/config/local_runtime_config_loader.dart`
- `lib/core/supabase/supabase_initializer.dart`

Startup sequence:

1. `main()` calls `WidgetsFlutterBinding.ensureInitialized()`.
2. `LocalRuntimeConfigLoader.primeIfNeeded()` runs before app creation.
3. If `AppConfig.current.validationErrorMessage == null`, `SupabaseInitializer.initialize()` is called before `runApp`.
4. `runApp(const ProviderScope(child: GymUnityApp()))` starts Riverpod.
5. `GymUnityApp` registers itself as a `WidgetsBindingObserver`.
6. On first post-frame callback, it starts:
   - `monetizationBootstrapProvider.start()`
   - `plannerReminderBootstrapProvider.start()`
   - `aiCoachBootProvider.start()`
7. `MaterialApp` starts at `AppRoutes.splash`, which renders `SplashScreen`.
8. `AppBootstrapController` loads config/backend/auth state and resolves the initial route.
9. `SplashScreen` enforces a minimum visible duration, then replaces the route with the resolved route.

### 3.2 Runtime Bootstrap Behavior

`AppBootstrapController.load()` performs:

1. Validate `AppConfig.current`.
2. Initialize Supabase.
3. Start auth deep-link bootstrap through `AuthDeepLinkBootstrap.instance.start()`.
4. Read current Supabase user via `UserRepository.getCurrentUser()`.
5. If no user exists, resolve to `/welcome`.
6. If a user exists, read account status from `users`.
7. If deleted/inactive, sign out and surface a deleted-account bootstrap state.
8. Otherwise call `AuthRouteResolver.resolveInitialRoute()`.

Bootstrap terminal states:

| State | Meaning | User-facing behavior |
| --- | --- | --- |
| `loading` | Startup in progress | Splash/loading UI. |
| `unauthenticated` | No Supabase user/session | Navigates to `/welcome`. |
| `authenticated` | Valid session and route resolved | Navigates to onboarding or dashboard. |
| `configError` | Runtime config validation failed | Splash error with retry. |
| `backendError` | Supabase/backend/profile resolution failed | Splash error with retry. |
| `deletedAccount` | Account is inactive/deleted | Error with support-oriented message. |

### 3.3 Supabase Initialization

`SupabaseInitializer.initialize()`:

- Validates `AppConfig.current`.
- Calls `Supabase.initialize()` with:
  - `url: config.supabaseUrl`
  - `anonKey: config.supabaseAnonKey`
  - `FlutterAuthClientOptions(detectSessionInUri: false)`
- Clears a persisted local auth session if its JWT project ref does not match the configured Supabase URL.
- Marks a static `_initialized` flag once completed.

Why `detectSessionInUri: false` matters:

- OAuth/deep-link callback handling is implemented manually by GymUnity, not delegated to the Supabase Flutter SDK default URL detector.

### 3.4 Deep Link And OAuth Callback Handling

Source files:

- `lib/core/supabase/auth_callback_ingress.dart`
- `lib/core/supabase/auth_callback_utils.dart`
- `lib/features/auth/presentation/controllers/google_oauth_controller.dart`
- `lib/features/auth/presentation/screens/auth_callback_screen.dart`

Ingress sources:

| Platform path | Mechanism |
| --- | --- |
| Android native callback bridge | `MethodChannel('gymunity/auth_callback')` and `EventChannel('gymunity/auth_callback_events')`. |
| Cross-platform fallback | `app_links` `uriLinkStream` and `getInitialLink()`. |

Callback rules:

- Accepted schemes come from `AppConfig.acceptedAuthRedirectSchemes`.
- Development accepts `gymunity`, `gymunity-dev`, and the configured scheme.
- Host must match `AppAuthConstants.oauthHost`, which resolves to the configured auth redirect host.
- A URI is an auth callback only if it includes `code`, `access_token`, `refresh_token`, or `error`.
- Fragment parameters are merged into query parameters.
- Route names like `/?code=...` and `/#access_token=...` are converted into the configured custom-scheme URI.

Auth flow controller behavior:

1. Starts OAuth with Supabase `signInWithOAuth`.
2. Enters `waitingForCallback`.
3. Starts a 20-second timeout and 500 ms polling loop.
4. Processes incoming deep-link URIs, deduped by callback fingerprint.
5. Uses `getSessionFromUrl()` first.
6. Falls back to `exchangeCodeForSession()` when an authorization code is present.
7. Completes user/profile bootstrap through `AuthController.completeAuthenticatedSession()`.
8. Routes recovery callbacks to `/reset-password`.
9. Routes normal auth callbacks through `AuthRouteResolver.resolveAfterAuth()`.

### 3.5 Lifecycle Hooks

`GymUnityApp.didChangeAppLifecycleState()` handles `resumed`:

- Refreshes monetization entitlements through `monetizationBootstrapProvider.refreshEntitlements()`.
- Syncs planner reminders through `plannerReminderBootstrapProvider.sync()`.
- Refreshes TAIYO Coach caches and nudges through `aiCoachBootProvider.refresh()`.

`GymUnityApp.dispose()`:

- Removes the app lifecycle observer.
- Disposes monetization and planner reminder bootstrap services.

### 3.6 Startup Failure Modes

| Failure | Detection | Result |
| --- | --- | --- |
| Missing Supabase URL/anon key | `AppConfig.validationErrors()` | Config error on splash. |
| Invalid URL values | `AppConfig._isValidUrl()` | Config error on splash. |
| Missing production privacy/support contact | `AppConfig.validationErrors()` when `APP_ENV=prod` | Config error on splash. |
| AI Premium enabled without product IDs | `AppConfig.validationErrors()` | Config error on splash. |
| Mismatched persisted JWT project | `SupabaseInitializer._clearMismatchedPersistedSession()` | Local sign-out. |
| Backend/profile query failure | `AppBootstrapController` catches `AppFailure` or generic error | Backend error state. |
| Deleted/inactive account | `UserRepository.getAccountStatus()` | Sign-out and deleted-account state. |
| OAuth callback error | `AuthCallbackUtils.errorMessage()` | Auth flow failure state. |
| OAuth callback timeout | `AuthFlowController` timeout | Failure message after 20 seconds. |

## 4. App Configuration Model

### 4.1 Runtime Keys

`AppConfig` reads these `--dart-define` keys and can also load a local asset override from `assets/config/local_env.json` when compile-time config is invalid.

| Key | Purpose | Default/fallback |
| --- | --- | --- |
| `APP_ENV` | Environment selector: `dev`, `staging`, `prod`/`production`. | `dev` |
| `SUPABASE_URL` | Supabase project URL. | Required |
| `SUPABASE_ANON_KEY` | Supabase anon key. | Required |
| `AUTH_REDIRECT_SCHEME` | Custom URI scheme for OAuth callback. | `gymunity`, except staging default `gymunity-staging` |
| `AUTH_REDIRECT_HOST` | Custom URI host for OAuth callback. | `auth-callback` |
| `PRIVACY_POLICY_URL` | External privacy policy. | Optional except production |
| `TERMS_OF_SERVICE_URL` | External terms document. | Optional |
| `SUPPORT_URL` | External support page. | Optional, but production requires this or email |
| `SUPPORT_EMAIL` | Support email. | Optional, but production requires this or URL |
| `SUPPORT_EMAIL_SUBJECT` | Email support subject line. | `GymUnity support request` |
| `REVIEWER_LOGIN_HELP_URL` | Reviewer support/help page. | Optional |
| `ENABLE_COACH_ROLE` | Shows/hides coach role card. | `true` |
| `ENABLE_SELLER_ROLE` | Shows/hides seller role card. | `true` |
| `ENABLE_APPLE_SIGN_IN` | Declared Apple sign-in flag. | `true` |
| `ENABLE_STORE_PURCHASES` | Declared store purchase flag. | `true` |
| `ENABLE_COACH_SUBSCRIPTIONS` | Declared coach subscription flag. | `true` |
| `ENABLE_AI_PREMIUM` | Enables TAIYO Premium gating and in-app purchase flow. | `false` |
| `APPLE_AI_PREMIUM_MONTHLY_PRODUCT_ID` | iOS monthly product ID. | Required only if AI Premium enabled |
| `APPLE_AI_PREMIUM_ANNUAL_PRODUCT_ID` | iOS annual product ID. | Required only if AI Premium enabled |
| `GOOGLE_AI_PREMIUM_SUBSCRIPTION_ID` | Google Play subscription product ID. | Required only if AI Premium enabled |
| `GOOGLE_AI_PREMIUM_MONTHLY_BASE_PLAN_ID` | Google monthly base plan ID. | Required only if AI Premium enabled |
| `GOOGLE_AI_PREMIUM_ANNUAL_BASE_PLAN_ID` | Google annual base plan ID. | Required only if AI Premium enabled |

### 4.2 Feature Flag Reality

| Flag | Current enforcement |
| --- | --- |
| `ENABLE_COACH_ROLE` | Used by `RoleSelectionScreen` to show/hide coach role selection. |
| `ENABLE_SELLER_ROLE` | Used by `RoleSelectionScreen` to show/hide seller role selection. |
| `ENABLE_AI_PREMIUM` | Used by monetization providers and AI gate. When false, TAIYO access is free. |
| `ENABLE_APPLE_SIGN_IN` | Defined in config but not found as enforced in UI/routing during this audit. |
| `ENABLE_STORE_PURCHASES` | Defined in config but not found as enforced in store routing/checkout during this audit. |
| `ENABLE_COACH_SUBSCRIPTIONS` | Defined in config but not found as enforced in coach subscription UI during this audit. |

Risk:

- Flags that are defined but not enforced can create false confidence during production rollouts.
- If business or app-store review depends on disabling store or coaching payments, these flags currently do not appear to guarantee that behavior.

### 4.3 Local Runtime Config

Scripts:

- `scripts/sync_local_runtime_config.ps1`
- `scripts/flutter_with_env.ps1`
- `scripts/flutter_test_dev.ps1`
- `scripts/flutter_run_dev.ps1`
- `scripts/flutter_build_apk_dev.ps1`
- `scripts/flutter_build_appbundle_dev.ps1`

Behavior:

- `scripts/flutter_with_env.ps1` reads `.env`, syncs allowed keys into `assets/config/local_env.json`, then passes allowed keys as `--dart-define`.
- `LocalRuntimeConfigLoader` only loads `assets/config/local_env.json` if the compile-time config is invalid.
- The asset override is accepted only if it produces a fully valid `AppConfig`.

Current local config evidence:

- `[Code]` `.env` and `assets/config/local_env.json` target `https://pooelnnveljiikpdrvqw.supabase.co`.
- `[Code]` `APP_ENV=dev`.
- `[Code]` auth redirect is `gymunity://auth-callback`.
- `[Risk]` `assets/config/local_env.json` exists in the workspace and contains runtime config. It should not contain secrets beyond client-safe values and should be handled intentionally for release builds.

### 4.4 Production-Sensitive Requirements

In `APP_ENV=prod`:

- `PRIVACY_POLICY_URL` is required.
- Either `SUPPORT_URL` or `SUPPORT_EMAIL` is required.
- Supabase URL and anon key are always required.
- AI Premium product IDs/base-plan IDs are required if `ENABLE_AI_PREMIUM=true`.

Live auth configuration:

| Item | Live value on 2026-04-20 |
| --- | --- |
| Project ref | `pooelnnveljiikpdrvqw` |
| Project name | `gymunity` |
| Region | `eu-west-2` |
| Status | `ACTIVE_HEALTHY` |
| Email auth | Enabled |
| Google auth | Enabled |
| Apple auth | Disabled |
| Phone auth | Disabled |
| Signups disabled | `false` |
| Refresh token rotation | Enabled |
| Site URL | `http://localhost:3000` |
| Redirect allow-list | `gymunity://auth-callback`, `gymunity-dev://auth-callback` |

Security note:

- The live auth API response includes sensitive provider secrets. They are intentionally not reproduced in this reference.

## 5. Architecture

### 5.1 Folder Structure

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | Flutter entrypoint and pre-app config/Supabase initialization. |
| `lib/app/` | `GymUnityApp` and route table. |
| `lib/core/config/` | Runtime config model and asset fallback loader. |
| `lib/core/constants/` | Shared app strings, colors, auth constants, AI branding, sizing. |
| `lib/core/di/` | Riverpod provider graph for repositories and global dependencies. |
| `lib/core/error/` | `AppFailure` hierarchy. |
| `lib/core/result/` | Shared result/pagination helpers. |
| `lib/core/routing/` | Auth route resolver. |
| `lib/core/services/` | Shared services such as external link handling. |
| `lib/core/supabase/` | Supabase initialization, auth callback ingress, JWT project-ref validation. |
| `lib/core/theme/` | App theme. |
| `lib/core/widgets/` | Shared widgets and placeholder screen. |
| `lib/features/ai_coach/` | TAIYO Coach daily brief, readiness, nudges, active workout companion, and weekly summary surfaces. |
| `lib/features/*` | Feature modules organized by domain. |
| `supabase/migrations/` | Database schema, RLS, RPCs, scheduler setup. |
| `supabase/functions/` | Edge Functions and shared Deno helpers. |
| `supabase/sql/` | Dashboard SQL bundle; not treated as canonical over migrations. |
| `test/` | Flutter unit/widget tests plus one opt-in manual live test. |
| `scripts/` | Env sync, Flutter wrappers, app icon generation. |
| `assets/config/` | Runtime config asset target. |

### 5.2 Feature Module Pattern

Most feature modules follow some subset of:

- `data/repositories/*_repository_impl.dart`
- `domain/entities/*`
- `domain/repositories/*`
- `domain/services/*`
- `presentation/controllers/*`
- `presentation/providers/*`
- `presentation/screens/*`
- `presentation/widgets/*`

This is a pragmatic clean-architecture style, but not every feature has a separate remote data source. Many repositories talk directly to Supabase.

### 5.3 Dependency Injection

Global DI lives in `lib/core/di/providers.dart`.

Primary providers:

| Provider | Responsibility |
| --- | --- |
| `supabaseClientProvider` | Exposes `Supabase.instance.client` after config and initialization. |
| `authCallbackIngressProvider` | Provides singleton deep-link ingress. |
| `authRemoteDataSourceProvider` | Supabase auth data source. |
| `authRepositoryProvider` | Auth repository. |
| `userRemoteDataSourceProvider` | User/profile remote data source. |
| `userRepositoryProvider` | User/profile repository. |
| `storeRepositoryProvider` | Store/cart/order repository. |
| `coachRepositoryProvider` | Coach marketplace, workspace CRM, calendar, billing, program delivery, and resources repository. |
| `memberRepositoryProvider` | Member profile/progress/subscription repository. |
| `plannerRepositoryProvider` | AI planner/agenda/reminder repository. |
| `sellerRepositoryProvider` | Seller profile/product/order repository. |
| `billingRepositoryProvider` | Native in-app purchase repository. |
| `entitlementRepositoryProvider` | Supabase billing entitlement repository. |
| `chatRepositoryProvider` | TAIYO chat repository. |
| `aiCoachRepositoryProvider` | TAIYO Coach repository for daily briefs, readiness, nudges, active workout companion, prompts, and weekly summaries. |
| `newsRepositoryProvider` | News repository. |
| `nutritionRepositoryProvider` | Nutrition repository. |
| `coachMemberInsightsRepositoryProvider` | Consent-gated coach/member insights repository. |
| `authSessionProvider` | Stream of mapped auth session state. |
| `currentUserProfileProvider` | Future provider for current profile. |
| `appRoleProvider` | Current app role from profile. |
| `authRouteResolverProvider` | Auth route resolver. |

### 5.4 Error Model

`lib/core/error/app_failure.dart` defines:

- `AppFailure`
- `NetworkFailure`
- `AuthFailure`
- `StorageFailure`
- `ValidationFailure`
- `ConflictFailure`
- `PaymentFailure`
- `ConfigFailure`
- `AccountDeletedFailure`

Repository patterns:

- Supabase `PostgrestException` is usually mapped to `NetworkFailure`.
- Auth SDK errors are mapped to `AuthFailure`.
- Storage SDK errors are mapped to `StorageFailure`.
- Business conflicts like out-of-stock or unavailable items are mapped to `ConflictFailure`.
- Billing verification/store failures are mapped to `PaymentFailure`.

### 5.5 Theme, Localization, Shared UI

- `GymUnityApp` uses `AppTheme.darkTheme`.
- Locale is derived from settings preferences: English or Arabic.
- `GlobalMaterialLocalizations.delegates` is installed.
- Many feature screens use `GoogleFonts`.
- Shared widgets include custom buttons, text fields, empty/error states, and `FeaturePlaceholderScreen`.

### 5.6 Storage Conventions

Storage buckets:

| Bucket | Configured public? | Usage |
| --- | --- | --- |
| `avatars` | `false` | Profile avatar uploads. Object path is `avatars/<userId>/avatar.<ext>`. Owner-only policies use `split_part(name, '/', 2) = auth.uid()`. |
| `product-images` | `true` | Seller product images. Object path is `<sellerId>/<productId>/<timestamp>.<ext>`. Public reads, seller-owned writes. |
| `coach-resources` | `false` | Coach-uploaded files and links exposed only to the coach or assigned subscription participants. |
| `coach-payment-receipts` | `false` | Member-uploaded coaching payment receipts referenced from billing verification flows. |

Live note:

- `[Live]` The 2026-04-20 snapshot explicitly confirmed `avatars` and `product-images`.
- `[Risk]` `coach-resources` and `coach-payment-receipts` are repo-defined in migrations but were not re-verified live in the 2026-04-21 repo audit.

Deletion behavior:

- `delete-account` attempts to remove `avatars` files under `avatars/<userId>` and `product-images` under `<userId>`.
- Seller product deletion removes product images only when the product can be hard-deleted; otherwise products are archived.

### 5.7 Notification Conventions

Server-backed notifications:

- `notifications` table stores user notifications.
- `settings` feature streams `notifications` by `user_id`.
- Categories map from `type`: `coaching`, `orders`, `ai`, otherwise `system`.
- Notifications can be marked read individually or in bulk.

Local planner reminders:

- Planner reminders are local-device notifications, not push notifications.
- They are derived from `list_member_plan_agenda()` and `sync_member_task_notifications()`.
- Channel ID is `planner_tasks`.
- Payload format is `planner-task:<taskId>:<planId>:<dayId>`.

## 6. Routing

The route table is implemented in `lib/app/routes.dart`.

### 6.1 Route Map

| Route | Screen | Arguments | Fallback/missing argument behavior |
| --- | --- | --- | --- |
| `/` | `SplashScreen` | none | Bootstrap route. |
| `/welcome` | `WelcomeScreen` | none | Public entry screen. |
| `/login` | `LoginScreen` | none | Google-only login UI. |
| `/register` | `RegisterScreen` | none | Google-only registration UI. |
| `/forgot-password` | `ForgotPasswordScreen` | none | Google-only messaging; password flow disabled in UI. |
| `/reset-password` | `ResetPasswordScreen` | none | Google-only/recovery wrapper route. |
| `/otp` | `OtpScreen` | `OtpFlowArgs` or `String email` | Defaults to empty email and signup mode. |
| `/auth-callback` | `AuthCallbackScreen` | optional route name | Processes callback through auth flow. |
| `/?...` or `/#...` | `AuthCallbackScreen` | route name includes OAuth params | Only intercepted when callback params exist. |
| `/role-selection` | `RoleSelectionScreen` | none | Role cards depend on role feature flags. |
| `/member-onboarding` | `MemberOnboardingScreen` | none | Member onboarding. |
| `/seller-onboarding` | `SellerOnboardingScreen` | none | Seller onboarding. |
| `/coach-onboarding` | `CoachOnboardingScreen` | none | Coach onboarding. |
| `/member-home` | `MemberHomeScreen` | none | Main member shell. |
| `/member-profile` | `MemberProfileScreen` | none | Member profile. |
| `/edit-profile` | `EditProfileScreen` | none | Shared profile edit. |
| `/progress` | `ProgressScreen` | none | Member progress. |
| `/workout-plan` | `WorkoutPlanScreen` | optional `WorkoutPlanArgs(planId)` | Opens active/default plan if no ID. |
| `/workout-details` | `WorkoutDayDetailsScreen` | required `WorkoutDayArgs(planId, dayId)` | Placeholder "Workout Details" if missing. |
| `/ai-chat-home` | `AiCoachHomeScreen` | none | TAIYO Coach daily brief, nudges, and workout guidance. |
| `/ai-conversation` | `AiConversationScreen` | optional `String sessionId` | Starts or opens general chat. |
| `/ai-planner-builder` | `PlannerBuilderScreen` | optional `PlannerBuilderArgs` | Starts builder with optional seed/session. |
| `/ai-generated-plan` | `AiGeneratedPlanScreen` | required `AiGeneratedPlanArgs(sessionId, draftId)` | Placeholder "AI Generated Plan" if missing. |
| `/active-workout-session` | `ActiveWorkoutSessionScreen` | optional `ActiveWorkoutSessionArgs(sessionId, planId, dayId)` | Can open an existing session or self-bootstrap from plan/day context. |
| `/ai-premium` | `AiPremiumPaywallScreen` | none | TAIYO Premium paywall. |
| `/subscription-management` | `SubscriptionManagementScreen` | none | AI Premium subscription management. |
| `/nutrition` | `NutritionHomeScreen` | optional `NutritionRouteArgs(initialHydrationAmountMl)` | Nutrition dashboard with optional hydration quick-log seed. |
| `/nutrition-setup` | `NutritionSetupScreen` | none | Guided nutrition setup. |
| `/nutrition-meal-plan` | `MealPlanScreen` | optional `MealPlanRouteArgs(openQuickAddOnLaunch)` | Active meal plan with optional quick-add launch. |
| `/nutrition-preferences` | `NutritionPreferencesScreen` | none | Nutrition preferences. |
| `/nutrition-insights` | `NutritionInsightsScreen` | none | Nutrition analytics/check-ins. |
| `/news-feed` | `NewsFeedScreen` | none | Personalized news feed. |
| `/news-article-details` | `NewsArticleDetailsScreen` | `NewsArticleEntity` or `String articleId` | Can load by ID or render initial article. |
| `/store-home` | `StoreHomeScreen` | none | Store home. |
| `/product-list` | `StoreCatalogScreen` | none | Product catalog. |
| `/product-details` | `ProductDetailsScreen` | optional `ProductEntity` | Screen receives null if missing. |
| `/favorites` | `FavoritesScreen` | none | Product favorites. |
| `/cart` | `CartScreen` | none | Cart. |
| `/checkout` | `CheckoutScreen` | none | Checkout preview/manual payment flow. |
| `/orders` | `MyOrdersScreen` | none | Member order history. |
| `/coaches` | `CoachesScreen` | none | Coach discovery. |
| `/coach-details` | `CoachDetailsScreen` | optional `CoachEntity` | Screen receives null if missing. |
| `/subscription-packages` | `SubscriptionPackagesScreen` | optional `CoachEntity` | Screen handles null/unavailable state. |
| `/my-subscriptions` | `MySubscriptionsScreen` | none | Member coach subscriptions. |
| `/member-checkins` | `MemberCheckinsScreen` | none | Member weekly check-ins. |
| `/member-messages` | `MemberMessagesScreen` | none | Member coaching threads. |
| `/member-thread` | `MemberThreadScreen` | required `CoachingThreadEntity` | Placeholder "Messages" if missing. |
| `/seller-dashboard` | `SellerDashboardScreen` | none | Seller dashboard. |
| `/product-management` | `SellerProductManagementScreen` | none | Seller product list/admin. |
| `/add-product` | `SellerProductEditorScreen` | none | New product editor. |
| `/edit-product` | `SellerProductEditorScreen` | optional `ProductEntity` | Null means create-mode behavior. |
| `/seller-orders` | `SellerOrdersScreen` | none | Seller order management. |
| `/seller-profile` | `SellerProfileScreen` | none | Seller profile. |
| `/coach-dashboard` | `CoachDashboardScreen` | none | Coach dashboard entry; renders `CoachWorkspaceShell`. |
| `/clients` | `CoachClientPipelineScreen` | none | Primary coach CRM pipeline route. |
| `/coach-client-workspace` | `CoachClientWorkspaceScreen` | `CoachClientWorkspaceArgs` or `String subscriptionId` | Placeholder "Client workspace" if argument is missing. |
| `/coach-checkins` | `CoachCheckinInboxScreen` | none | Pending weekly check-ins awaiting coach feedback. |
| `/coach-calendar` | `CoachCalendarScreen` | none | Session types, availability slots, and booking management. |
| `/coach-billing` | `CoachBillingScreen` | none | Manual payment queue, receipt review, and audit trail. |
| `/coach-program-library` | `CoachProgramLibraryScreen` | none | Coach program templates and exercise library. |
| `/coach-onboarding-flows` | `CoachOnboardingFlowsScreen` | none | Coach onboarding templates, habits, and resource presets. |
| `/coach-resources` | `CoachResourcesScreen` | none | Coach files/links and assignment flow. |
| `/packages` | `CoachPackagesScreen` | none | Coach package management. |
| `/add-package` | `CoachPackageEditorScreen` | optional `CoachPackageEntity` | Null creates package; entity edits package. |
| `/coach-profile` | `CoachProfileScreen` | none | Coach profile. |
| `/coach-member-insights` | `CoachMemberInsightsScreen` | required `InsightDetailArgs` | Placeholder "Member Insights" if missing. |
| `/member-coach-visibility` | `MemberCoachVisibilitySettingsScreen` | required `VisibilitySettingsArgs` | Placeholder "Privacy Settings" if missing. |
| `/notifications` | `NotificationsScreen` | none | Notification list. |
| `/settings` | `SettingsScreen` | none | Settings. |
| `/delete-account` | `DeleteAccountScreen` | none | Account deletion. |
| `/help-support` | `HelpSupportScreen` | none | Support/legal help. |
| `/privacy-policy` | `PrivacyPolicyScreen` | none | External/in-app privacy view. |
| `/terms` | `TermsScreen` | none | External/in-app terms view. |
| unknown route | `FeaturePlaceholderScreen` | route name | Placeholder "Unknown Route". |

### 6.2 Placeholder Routes

Placeholders are not primary feature implementations. They exist as defensive fallbacks:

- `/workout-details` without `WorkoutDayArgs`
- `/ai-generated-plan` without `AiGeneratedPlanArgs`
- `/member-thread` without `CoachingThreadEntity`
- `/coach-client-workspace` without `CoachClientWorkspaceArgs` or subscription id
- `/coach-member-insights` without `InsightDetailArgs`
- `/member-coach-visibility` without `VisibilitySettingsArgs`
- unknown route names

Route note:

- `CoachClientsScreen` still exists in source as a thin wrapper around `CoachClientPipelineScreen`, but `onGenerateRoute` now targets the pipeline screen directly.

### 6.3 Role-Specific Route Behavior

Auth route resolution is not enforced by route guards in `onGenerateRoute`; instead it happens during startup/auth completion through `AuthRouteResolver`.

Dashboard mapping:

| Role | Onboarding route | Dashboard route |
| --- | --- | --- |
| `member` | `/member-onboarding` | `/member-home` |
| `coach` | `/coach-onboarding` | `/coach-dashboard` |
| `seller` | `/seller-onboarding` | `/seller-dashboard` |

Risk:

- Direct navigation to role-specific routes is not protected in the route table itself. The backend RLS and repository failures are the main protection after startup.

## 7. Role System

### 7.1 Role Entities

`AppRole` values:

| Role | Code | Backend `role_id` |
| --- | --- | --- |
| Member | `member` | `1` |
| Coach | `coach` | `2` |
| Seller | `seller` | `3` |

Backend seed:

- `[Migration]` `20260307000001_init_gymunity.sql` creates `roles` and inserts `member`, `coach`, and `seller`.

### 7.2 Persistence

Role persistence lives in:

- `profiles.role_id`
- `roles.code`

Profile fetching selects:

```sql
profiles(..., role_id, roles(code))
```

`ProfileModel` resolves the role from the relation code where possible, with role ID fallback.

### 7.3 Role Selection

`RoleSelectionScreen`:

1. Always shows the member role.
2. Shows seller only if `ENABLE_SELLER_ROLE=true`.
3. Shows coach only if `ENABLE_COACH_ROLE=true`.
4. Calls `OnboardingController.saveRole(role)`.
5. `UserRepository.saveRole()` updates `profiles.role_id`.
6. UI navigates to the selected role's onboarding route only after save succeeds.

### 7.4 Onboarding Completion

Common identity onboarding completion:

- `UserRepository.completeOnboarding()` updates `profiles.onboarding_completed=true`.

Feature-specific onboarding writes:

| Role | Feature table |
| --- | --- |
| Member | `member_profiles`, `user_preferences`, optional initial weight entry. |
| Coach | `coach_profiles` plus coach-specific profile/offer fields. |
| Seller | `seller_profiles`. |

### 7.5 Role-Based Backend Ownership

| Role | Owned objects |
| --- | --- |
| Member | `member_profiles`, `member_weight_entries`, `member_body_measurements`, `workout_sessions`, `workout_plans`, `ai_plan_drafts`, meal/nutrition tables, store carts/orders as buyer, coaching subscriptions as member, coaching messages/check-ins/receipts/bookings as participant. |
| Coach | `coach_profiles`, `coach_packages`, `coach_availability_slots`, `coach_client_records`, `coach_client_notes`, `coach_automation_events`, `coach_thread_reads`, `coach_program_templates`, `coach_exercise_library`, `coach_habit_templates`, `coach_resources`, `coach_onboarding_templates`, `coach_session_types`, `coach_bookings`, coaching subscriptions as coach, receipt verification rows, and visibility read access when member consents. |
| Seller | `seller_profiles`, `products`, product images, order items/orders as seller. |

RLS intent:

- Most tables enable RLS and restrict read/manage access to the owning user or participants.
- RPCs are used for business transitions that cross table boundaries, such as order creation, coach checkout, coach payment confirmation, plan activation, and visibility updates.

## 8. Feature Chapters

### 8.1 Auth

Purpose:

- Start OAuth, restore sessions, handle callbacks, bootstrap user/profile records, and sign out/delete accounts.

Primary screens:

- `WelcomeScreen`
- `LoginScreen`
- `RegisterScreen`
- `ForgotPasswordScreen`
- `ResetPasswordScreen`
- `OtpScreen`
- `AuthCallbackScreen`
- `SplashScreen`
- `RoleSelectionScreen`

Key classes:

- `AuthRepositoryImpl`
- `AuthRemoteDataSource`
- `AuthController`
- `AuthFlowController`
- `AppBootstrapController`
- `AuthRouteResolver`
- `AuthCallbackIngress`
- `AuthCallbackUtils`

Backend touchpoints:

- Supabase Auth.
- `users`
- `profiles`
- `roles`
- Edge Function `delete-account`.
- RPC `prepare_account_for_hard_delete`.

Current behavior:

- `[Code]` UI is Google-first/Google-only for login and registration.
- `[Code]` Email/password, OTP, recovery, password update, and password reset repository methods still exist.
- `[Live]` The last verified live snapshot had email auth enabled, even though the current UI says manual email/password access is disabled.
- `[Live]` The last verified live snapshot had Google auth enabled.
- `[Live]` The last verified live snapshot had Apple auth disabled.

Status:

- Implemented for Google OAuth and session bootstrap.
- Partially implemented/stale for email/password and OTP flows because repository methods exist but UI has been redirected to Google-only behavior.

Risks:

- Email auth enabled live while UI claims Google-only can confuse operational support and account policy.
- Reset/recovery code exists and route exists, but current screen wrappers do not present a full manual password reset UX.

### 8.2 Onboarding

Purpose:

- Collect role-specific profile details and mark onboarding complete.

Primary screens:

- `RoleSelectionScreen`
- `MemberOnboardingScreen`
- `SellerOnboardingScreen`
- `CoachOnboardingScreen`

Key classes:

- `OnboardingController`
- `UserRepositoryImpl`
- `MemberRepositoryImpl`
- `CoachRepositoryImpl`
- `SellerRepositoryImpl`

Backend touchpoints:

- `profiles.role_id`
- `profiles.onboarding_completed`
- `member_profiles`
- `seller_profiles`
- `coach_profiles`
- `user_preferences`

Status:

- Implemented, with widget tests covering failure-stays-on-screen and success routing behavior.

Limitations:

- Route table itself does not prevent users from visiting mismatched role routes; routing discipline depends on auth resolver and backend permissions.

### 8.3 User

Purpose:

- Bridge Supabase Auth users to application profile data.

Key classes:

- `UserRemoteDataSource`
- `UserRepositoryImpl`
- `ProfileModel`
- `UserEntity`
- `ProfileEntity`
- `AppRole`
- `AccountStatus`

Repository behavior:

- Reads current auth user from Supabase.
- Reads `users.is_active` and `users.deleted_at` for account status.
- Reads profile with `roles(code)`.
- Upserts `users` with email, active state, and `last_login_at`.
- Upserts `profiles` with optional full name.
- Updates role and onboarding completion.
- Updates profile details.
- Uploads avatar to `avatars` bucket and stores `profiles.avatar_path`.

Status:

- Implemented.

Risks:

- Avatar object path includes a leading `avatars/` folder inside the `avatars` bucket. Storage policy uses `split_part(name, '/', 2) = auth.uid()`, which matches this path shape; changing it would break owner access.

### 8.4 Member

Purpose:

- Store member profile/preferences, progress history, plans, subscriptions, messages, check-ins, payment receipt submissions, and orders.

Primary screens:

- `MemberHomeScreen`
- `MemberProfileScreen`
- `EditProfileScreen`
- `ProgressScreen`
- `WorkoutPlanScreen`
- `MySubscriptionsScreen`
- `MemberCheckinsScreen`
- `MemberMessagesScreen`
- `MemberThreadScreen`

Key providers/repository:

- `memberRepositoryProvider`
- `MemberRepositoryImpl`
- Member providers in `lib/features/member/presentation/providers/member_providers.dart`

Backend touchpoints:

- `member_profiles`
- `user_preferences`
- `member_weight_entries`
- `member_body_measurements`
- `workout_sessions`
- `workout_plans`
- `subscriptions`
- `coach_member_threads`
- `coach_messages`
- `weekly_checkins`
- `progress_photos`
- `coach_payment_receipts`
- `orders`
- Storage bucket `coach-payment-receipts`
- RPCs:
  - `list_member_subscriptions_live`
  - `list_member_subscriptions_detailed`
  - `confirm_coach_payment`
  - `submit_coach_payment_receipt`
  - `pause_coach_subscription`
  - `submit_weekly_checkin`
  - `list_member_orders_detailed`

Important logic:

- `upsertMemberProfile()` marks onboarding complete and inserts initial weight entry if none exists.
- Subscriptions prefer `list_member_subscriptions_live()` and fall back to `list_member_subscriptions_detailed()` only if the live RPC is missing.
- `MySubscriptionsScreen` can upload receipt binaries into `coach-payment-receipts` and submit receipt metadata through `submit_coach_payment_receipt()`.
- Member message send inserts `coach_messages` with `sender_role='member'`.
- Home summary aggregates profile, preferences, latest weight, latest measurements, active/latest plan, latest workout session, and active/latest subscription.

Status:

- Implemented, with significant repository and widget test coverage.

Limitations:

- Some data aggregation is sequential in the repository, which is simpler but can increase home-load latency.

### 8.5 Coach

Purpose:

- Let coaches run a multi-surface workspace: create public profiles/offers, manage CRM state, message clients, review check-ins, assign programs/resources/onboarding flows, manage calendar bookings, review manual payments, and manage client visibility-aware insights.

Primary screens:

- `CoachDashboardScreen`
- `CoachWorkspaceShell`
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

Key repository/providers:

- `CoachRepositoryImpl`
- Coach providers in `lib/features/coach/presentation/providers/coach_providers.dart`
- `CoachWorkspaceEntity` and related workspace entities in `lib/features/coach/domain/entities/coach_workspace_entity.dart`

Backend touchpoints:

- `coach_profiles`
- `coach_packages`
- `coach_availability_slots`
- `coach_client_records`
- `coach_client_notes`
- `coach_automation_events`
- `coach_thread_reads`
- `coach_reviews`
- `subscriptions`
- `workout_plans`
- `coach_program_templates`
- `coach_exercise_library`
- `coach_habit_templates`
- `member_habit_assignments`
- `member_habit_logs`
- `coach_resources`
- `coach_resource_assignments`
- `coach_onboarding_templates`
- `coach_onboarding_applications`
- `coach_session_types`
- `coach_bookings`
- `coach_payment_receipts`
- `coach_payment_audit_events`
- `notifications`
- `coach_checkout_requests`
- `coach_member_threads`
- `coach_messages`
- Storage buckets `coach-resources` and `coach-payment-receipts`
- RPCs:
  - `coach_dashboard_summary`
  - `list_coach_clients`
  - `coach_workspace_summary`
  - `list_coach_action_items`
  - `list_coach_client_pipeline`
  - `get_coach_client_workspace`
  - `upsert_coach_client_record`
  - `add_coach_client_note`
  - `mark_coach_thread_read`
  - `dismiss_coach_action_item`
  - `list_coach_subscription_requests`
  - `update_coach_subscription_status`
  - `activate_coach_subscription_with_starter_plan`
  - `list_coach_program_templates`
  - `save_coach_program_template`
  - `assign_program_template_to_client`
  - `list_coach_exercises`
  - `save_coach_exercise`
  - `assign_client_habits`
  - `list_coach_resources`
  - `save_coach_resource`
  - `assign_resource_to_client`
  - `list_coach_onboarding_templates`
  - `save_coach_onboarding_template`
  - `apply_coach_onboarding_flow`
  - `list_coach_session_types`
  - `save_coach_session_type`
  - `list_coach_bookings`
  - `create_coach_booking`
  - `update_coach_booking_status`
  - `list_coach_payment_queue`
  - `verify_coach_payment`
  - `fail_coach_payment`
  - `list_coach_payment_audit`
  - `list_coach_public_reviews`
  - `submit_coach_review`

Important logic:

- `CoachDashboardScreen` is now a shallow entry point that renders `CoachWorkspaceShell`.
- Profile and package writes use schema-compatible retries when columns are missing from the live schema cache.
- Coach CRM state, notes, action items, unread counts, and client workspace data are RPC-driven rather than assembled only from flat table reads.
- Program delivery supports reusable templates, exercise library rows, habit assignment, and client-specific application flows.
- Calendar flows manage session types, availability metadata, and bookings from a dedicated route and entity set.
- Manual billing now includes member receipt upload, coach review actions, and audit history instead of only a single confirm-payment step.
- Coach resources can be uploaded to `coach-resources` or created as external links, then assigned per subscription.
- Public coach profile reads and writes now include `headline`, `positioningStatement`, `certifications`, `trustBadges`, `faqItems`, and `responseMetrics`.
- Package visibility is normalized as `draft`, `published`, or `archived`.
- `is_active` is true only when visibility is published.
- Package deletion hard-deletes only when there are no linked subscriptions; otherwise it archives/deactivates.
- Starter plan activation calls a backend RPC and creates/activates a coaching relationship.

Status:

- Implemented in the current workspace, including coach CRM/workspace, billing review, calendar, resources, onboarding flows, and program delivery surfaces.

Risk:

- Schema-compatible writes are useful during migration rollouts, but they can hide deployment mismatch and should not be treated as a permanent contract.
- Live parity for the 2026-04-21 coach workspace expansion was not re-verified because Supabase CLI access was unauthorized in this repo audit.

### 8.6 Coaches Marketplace

Purpose:

- Let members discover coaches, filter by market criteria, view coach details, review packages, and start coaching checkout.

Primary screens:

- `CoachesScreen`
- `CoachDetailsScreen`
- `SubscriptionPackagesScreen`

Providers:

- `coachListProvider`
- `filteredCoachListProvider`
- selected specialty/search/city/language/gender/budget providers

Backend touchpoints:

- RPC `list_coach_directory_v2`
- RPC `list_coach_public_packages`
- RPC `list_coach_public_reviews`
- RPC `create_coach_checkout`

Important logic:

- `listCoaches()` uses RPC filtering for specialty, city, language, gender, and max budget.
- The local provider additionally applies text search.
- Coach cards/details can surface converted public profile fields such as headline, positioning statement, certifications, FAQ, trust badges, response metrics, and package preview data.
- Package checkout dialog collects structured intake: goal, experience, days/week, session minutes, equipment, limitations, budget, city, member note, and payment rail.
- Payment rails include manual/external rails such as Instapay/card/wallet semantics, and downstream payment completion can continue through member receipt submission in `MySubscriptionsScreen`.

Status:

- Implemented, but checkout is not an in-app real-time payment processor.

Limitations:

- `Paged` abstraction exists, but coach directory cursor pagination is not materially implemented.

### 8.7 Seller

Purpose:

- Let sellers create seller profiles, manage products/images, and process orders.

Primary screens:

- `SellerDashboardScreen`
- `SellerProductManagementScreen`
- `SellerProductEditorScreen`
- `SellerOrdersScreen`
- `SellerProfileScreen`

Key repository:

- `SellerRepositoryImpl`

Backend touchpoints:

- `seller_profiles`
- `products`
- `order_items`
- `orders`
- `order_status_history`
- `product-images` storage bucket
- RPCs:
  - `seller_dashboard_summary`
  - `list_seller_orders_detailed`
  - `update_store_order_status`

Important logic:

- Seller onboarding/profile writes mark onboarding complete.
- Product image upload optimizes images client-side before upload.
- Product image paths are seller-owned under `product-images`.
- Product deletion archives when the product is referenced by order items, otherwise deletes storage objects and product row.
- Product currency is hardcoded as `USD` in seller repository code.

Status:

- Implemented.

Risks:

- Hardcoded `USD` conflicts with Egypt-market coaching semantics and may not match intended commerce localization.
- Store order payment is manual, so seller order status management is operationally important.

### 8.8 Store

Purpose:

- Member-facing physical goods store with catalog, product details, favorites, cart, checkout, and order history.

Primary screens:

- `StoreHomeScreen`
- `StoreCatalogScreen`
- `ProductDetailsScreen`
- `FavoritesScreen`
- `CartScreen`
- `CheckoutScreen`
- `MyOrdersScreen`

Key repository:

- `StoreRepositoryImpl`

Backend touchpoints:

- `products`
- `product_favorites`
- `store_carts`
- `store_cart_items`
- `shipping_addresses`
- `orders`
- `order_items`
- `order_status_history`
- `store_checkout_requests`
- `product-images` storage bucket
- RPCs:
  - `create_store_order`
  - `list_member_orders_detailed`

Important logic:

- Product list reads active, non-deleted products.
- Cart is stored server-side in `store_carts` and `store_cart_items`.
- Shipping address default handling clears previous defaults before setting a new one.
- Checkout calls `create_store_order(target_shipping_address_id, client_idempotency_key)`.
- Checkout UI states that GymUnity does not process card payments in-app yet; orders are created as pending/manual-payment.
- Public product image URLs are resolved from `product-images` for relative paths.

Status:

- Implemented, with manual payment caveat.

Limitations:

- Product catalog uses `Paged` return type but cursor pagination is not implemented.
- Payment status depends on manual seller/admin confirmation flows.

### 8.9 AI Chat

Purpose:

- TAIYO conversational assistant and planner prompt engine for general chat and structured builder sessions.

Primary screens:

- `AiConversationScreen`

Key classes:

- `ChatRepositoryImpl`
- `ChatController`
- `AiBranding`
- Edge Function `ai-chat`

Backend touchpoints:

- `chat_sessions`
- `chat_messages`
- `ai_plan_drafts`
- `ai_user_memories`
- `ai_session_state`
- Edge Function `ai-chat`

Important logic:

- Chat sessions have `session_type`, `planner_status`, `latest_draft_id`, and planner profile JSON.
- `AiChatHomeScreen` still exists in source/tests as an editorial AI surface, but `AppRoutes.aiChatHome` now routes to `AiCoachHomeScreen` in `lib/features/ai_coach/`.
- User messages are inserted into `chat_messages`.
- The `ai-chat` function is invoked with `session_id`, `message_id`, and action `reply` or `regenerate_plan`.
- Repository validates JWT project ref and clears mismatched local sessions.
- AI reply failures retry once for selected network failures.
- If an Edge Function call fails after an assistant reply was already persisted, the repository tries to recover that persisted reply.
- Function 401 invalid-JWT errors are mapped into a project-ref/deploy mismatch message.

Edge Function behavior:

- Authenticates with bearer token using service-role client.
- Verifies session ownership.
- Allows planner sessions only for member role.
- Reads profile, member profile, preferences, latest progress, sessions, active AI plan, drafts, memory, session state, tasks, and logs.
- Uses Gemini if `GEMINI_API_KEY` exists; otherwise can use Groq if `GROQ_API_KEY` exists.
- Defaults:
  - `GEMINI_MODEL=gemini-2.0-flash`
  - `GROQ_MODEL=openai/gpt-oss-120b`
- Saves assistant messages, planner drafts, memories, and session state.

Status:

- Implemented and live-deployed as Edge Function version 24.

Risks:

- `.env.example` references `OPENAI_MODEL`, but the current Edge Function code uses Gemini/Groq provider envs. This is documentation/config drift.
- AI quality, safety, and provider availability depend on Edge Function secrets not visible in this repo.

### 8.10 TAIYO Coach

Purpose:

- Deliver the routed AI landing experience for daily coaching briefs, readiness scoring, nudges, active workout companionship, prompt generation, and weekly summaries.

Primary screens:

- `AiCoachHomeScreen`
- `ActiveWorkoutSessionScreen`

Key classes:

- `AiCoachRepository`
- `AiCoachRepositoryImpl`
- `AiCoachBootController`
- `AiCoachActionController`
- `ActiveWorkoutCompanionController`
- Edge Function `ai-coach`

Backend touchpoints:

- `member_daily_readiness_logs`
- `member_ai_daily_briefs`
- `member_ai_plan_adaptations`
- `member_ai_nudges`
- `member_active_workout_sessions`
- `member_active_workout_events`
- `member_ai_weekly_summaries`
- `workout_plans`
- `workout_plan_days`
- `workout_plan_tasks`
- `workout_task_logs`
- `workout_sessions`
- `notifications`
- `ai_user_memories`
- RPCs:
  - `upsert_member_readiness_log`
  - `get_member_ai_coach_context`
  - `apply_member_ai_adjustment`
  - `start_member_active_workout`
  - `record_member_active_workout_event`
  - `complete_member_active_workout`
  - `build_member_ai_weekly_summary`
  - `share_member_ai_weekly_summary`
- Edge Function `ai-coach`

Important logic:

- `AppRoutes.aiChatHome` now routes to `AiCoachHomeScreen`, and the member home featured AI card plus the member-shell AI tab both target this surface.
- `GymUnityApp` starts `aiCoachBootProvider` after the first frame and refreshes it again on app resume.
- Daily brief loading checks cached `member_ai_daily_briefs` first and falls back to `ai-coach` mode `refresh_daily_brief`.
- Readiness submissions call `upsert_member_readiness_log`, then invalidate the daily brief and nudge providers.
- Adjustment actions such as shorten/swap/move call `apply_member_ai_adjustment` and invalidate active plan state.
- Active workout sessions can be started from a brief or resumed directly; prompt refreshes use `ai-coach` mode `workout_prompt`.
- Workout completion writes session outcomes back through `complete_member_active_workout`, which in turn updates `workout_task_logs` and `workout_sessions`.
- Weekly summaries are built from adherence/nutrition/hydration context and can be shared into the coach thread through `share_member_ai_weekly_summary`.

Status:

- Implemented in the current working tree.
- Repo-defined Flutter module `lib/features/ai_coach/`, repo-defined Edge Function `supabase/functions/ai-coach/`, and migration `20260421000024_taiyo_member_os.sql` are present.
- `[Live]` This feature area was not part of the last verified 2026-04-20 live snapshot and was not re-verified live in the 2026-04-21 repo audit.

Risks:

- Live deployment and schema parity for `ai-coach` and the new member-OS objects are not yet re-verified.
- The routed AI landing surface changed faster than the current widget-test expectations, so some TAIYO/member-home tests are now failing.

### 8.11 Planner

Purpose:

- Convert TAIYO-generated plan drafts into active workout plans, agenda days/tasks, task logs, and local reminders.

Primary screens:

- `PlannerBuilderScreen`
- `AiGeneratedPlanScreen`
- `WorkoutPlanScreen`
- `WorkoutDayDetailsScreen`

Key classes:

- `PlannerBuilderController`
- `PlannerBuilderQuestionFactory`
- `PlannerRepositoryImpl`
- `PlannerReminderBootstrapService`

Backend touchpoints:

- `ai_plan_drafts`
- `workout_plans`
- `workout_plan_days`
- `workout_plan_tasks`
- `workout_task_logs`
- `notifications`
- RPCs:
  - `activate_ai_workout_plan`
  - `list_member_plan_agenda`
  - `upsert_workout_task_log`
  - `sync_member_task_notifications`
  - `update_ai_plan_reminder_time`

Important logic:

- Builder scans member profile, preferences, progress, plans, recent sessions, and AI memories.
- Required critical fields include goal, experience, days per week, session minutes, and equipment.
- Builder sends structured prompt prefixed with `GYMUNITY_AI_BUILDER_REQUEST`.
- Plan activation calls `activate_ai_workout_plan`.
- Task status updates call `upsert_workout_task_log`.
- Reminder time updates call `update_ai_plan_reminder_time`.
- Reminder sync schedules up to 50 pending active AI tasks with reminder times.

Status:

- Implemented and backed by migrations.
- Manual live planner repository test exists but is skipped by default.

Risks:

- `test/manual_live_planner_repository_test.dart` embeds live test credentials and an anon key. Those should be moved to environment variables or rotated before sharing the repo externally.

### 8.12 Nutrition

Purpose:

- Build member nutrition profile, calculate calorie/macronutrient targets, generate a 7-day meal plan, track meal/hydration adherence, and collect check-ins.

Primary screens:

- `NutritionHomeScreen`
- `NutritionSetupScreen`
- `MealPlanScreen`
- `NutritionPreferencesScreen`
- `NutritionInsightsScreen`

Key classes:

- `NutritionRepositoryImpl`
- `NutritionSetupController`
- `CalorieEngine`
- `MacroEngine`
- `MealPlanGenerator`
- `NutritionAdaptationEngine`
- `NutritionSetupQuestionFactory`

Backend touchpoints:

- `nutrition_profiles`
- `nutrition_targets`
- `nutrition_meal_templates`
- `member_meal_plans`
- `member_meal_plan_days`
- `member_planned_meals`
- `meal_logs`
- `hydration_logs`
- `nutrition_checkins`

Important logic:

- Setup preloads member profile, preferences, weights, and existing nutrition profile.
- Setup can update the member profile with goal, age, gender, height, current weight, and training frequency.
- `CalorieEngine` uses Mifflin-St Jeor BMR, activity multipliers, goal-based calorie adjustments, safe floors, macro rules, and hydration targets.
- `MealPlanGenerator` chooses active meal templates, filters allergies/exclusions/diet preferences, scores by calories/cuisine/budget/prep/diet, and falls back to built-in templates if none exist.
- Generated meal plans archive previous active plan before inserting the new plan/days/meals.
- Completing a planned meal updates `member_planned_meals.completed_at` and upserts a corresponding `meal_logs` row.
- Quick-add meals and hydration logs are direct inserts.

Status:

- Implemented in code and migration-defined.
- `[Live]` The last verified live snapshot recorded migration `20260418000016`, so nutrition was migration-applied at that point.

Limitations:

- Meal plan generation is local deterministic logic, not AI-generated.
- There is no fresh 2026-04-21 live table-by-table inventory for nutrition because live Supabase access was not available in this repo audit.

### 8.13 News

Purpose:

- Personalized fitness/health news feed, article details, bookmarking, dismissal, and interaction tracking.

Primary screens:

- `NewsFeedScreen`
- `NewsArticleDetailsScreen`

Key classes:

- `NewsRepositoryImpl`
- `NewsController`
- Edge Function `sync-news-feeds`

Backend touchpoints:

- `news_sources`
- `news_articles`
- `news_article_topics`
- `user_news_interests`
- `news_article_interactions`
- `news_article_bookmarks`
- `private.news_scheduler_config`
- RPCs:
  - `list_personalized_news`
  - `list_news_article_topics`
  - `track_news_interaction`
  - `save_news_article`
  - `dismiss_news_article`
  - `list_saved_news_articles`
  - `sync_member_news_interests`

Important logic:

- Feed pagination uses offset encoded as string cursor.
- Initial load tracks impressions for the first six feed items without blocking UX.
- Save/remove/dismiss are optimistic and rollback on failure.
- Article detail can load by article ID or receive an initial article entity.
- `sync-news-feeds` ingests RSS/Atom sources, normalizes articles, classifies topics/goals/levels/safety/trust, deduplicates by canonical URL/hash, and can backfill missing images.
- Scheduled ingestion is configured through private SQL functions using `pg_cron` and `pg_net`.

Status:

- Implemented and live-deployed as Edge Function version 15.

### 8.14 Monetization

Purpose:

- Gate TAIYO Premium and manage native store subscriptions for AI features.

Primary screens:

- `AiPremiumPaywallScreen`
- `SubscriptionManagementScreen`

Key classes:

- `BillingRepositoryImpl`
- `EntitlementRepositoryImpl`
- `MonetizationBootstrapService`
- `SubscriptionManagementController`
- `MonetizationConfig`

Backend touchpoints:

- `billing_products`
- `billing_customers`
- `store_transactions`
- `subscription_entitlements`
- `billing_sync_events`
- RPC `ensure_billing_customer`
- Edge Function expected by code:
  - `billing-refresh-entitlement`
  - `billing-verify-google`
  - `billing-verify-apple`

Current implementation:

- When `ENABLE_AI_PREMIUM=false`, `aiPremiumGateProvider` grants free access and states TAIYO Premium is disabled in the build.
- When enabled, catalog loads products from native stores.
- Android uses Google Play subscription product ID plus base plan IDs.
- iOS uses separate monthly and annual Apple product IDs.
- Purchase updates are listened to globally after app startup.
- Android existing purchases are reconciled on bootstrap.
- Entitlement refresh calls `billing-refresh-entitlement`.
- Android purchase sync calls `billing-verify-google`.
- iOS purchase sync calls `billing-verify-apple`.

Repo/live reality:

- `[Code]` `supabase/functions/billing-verify-apple/index.ts` exists.
- `[Code]` `_shared/billing.ts` exists.
- `[Code]` `billing-refresh-entitlement`, `billing-verify-google`, `billing-apple-notifications`, and `billing-google-rtdn` directories exist but contain no implementation files.
- `[Live]` No billing Edge Functions were deployed in the last verified live snapshot. Only `ai-chat`, `delete-account`, and `sync-news-feeds` were deployed.

Status:

- Partially implemented.
- Safe only while `ENABLE_AI_PREMIUM=false`.

Top risk:

- If AI Premium is enabled, entitlement refresh and Android purchase verification will fail because required functions are missing from source and live deployment.

### 8.15 Settings

Purpose:

- Manage preferences, notifications, support/legal links, subscriptions, and account deletion.

Primary screens:

- `SettingsScreen`
- `NotificationsScreen`
- `HelpSupportScreen`
- `PrivacyPolicyScreen`
- `TermsScreen`
- `DeleteAccountScreen`
- `SubscriptionManagementScreen` when AI Premium is enabled

Key providers/classes:

- `SettingsPreferencesController`
- `NotificationsController`
- `ExternalLinkService`

Backend touchpoints:

- `user_preferences`
- `notifications`
- Edge Function `delete-account`

Important logic:

- Settings preferences map to member `user_preferences`.
- Language preference controls the app locale.
- Notifications are streamed from Supabase by `user_id`.
- `available_at` filters future notifications out of the visible stream.
- Delete account requires typing `DELETE`.
- Email/password accounts require current password before deletion; linked-provider accounts rely on active session.
- Delete success signs out and navigates back to `/login`.

Status:

- Implemented.

### 8.16 Coach Member Insights

Purpose:

- Provide privacy-first, consent-gated insight sharing from member to coach.

Primary screens:

- `CoachMemberInsightsScreen`
- `MemberCoachVisibilitySettingsScreen`

Key classes:

- `CoachMemberInsightsRepositoryImpl`
- `InsightDetailArgs`
- `VisibilitySettingsArgs`
- `MemberInsightEntity`
- `VisibilitySettingsEntity`
- `VisibilityAuditEntity`

Backend touchpoints:

- `coach_member_visibility_settings`
- `coach_member_visibility_audit`
- `member_product_recommendations`
- RPCs:
  - `get_coach_member_insight`
  - `list_coach_member_insight_summaries`
  - `get_member_visibility_settings`
  - `upsert_coach_member_visibility`
  - `list_visibility_audit`

Consent categories:

- AI plan summary.
- Workout adherence.
- Progress metrics.
- Nutrition summary.
- Product recommendations.
- Relevant purchases.

Important logic:

- Member settings default to all sharing disabled.
- Member can revoke all categories.
- Upsert RPC writes audit history.
- Coach insight RPC returns only consented sections.
- Risk flags include low adherence, many missed sessions, and no recent check-in.

Status:

- Implemented in current working tree.
- `[Live]` The last verified live snapshot recorded migration `20260418000017`, but this was not re-checked on 2026-04-21.
- `[Risk]` The entire `lib/features/coach_member_insights/` directory and the migration were untracked in Git at audit time.

Code hygiene risk:

- Several coach-member-insights source files contain mojibake/encoding artifacts in comments and at least some visible UI strings. This should be cleaned before release.

## 9. Database And Backend

### 9.1 Migration Timeline

| Migration | Purpose |
| --- | --- |
| `20260307000001_init_gymunity.sql` | Core roles, users, profiles, coach profiles, products, orders, subscriptions, chat, workout plans, base RLS. |
| `20260307000002_storage.sql` | Storage buckets and policies for avatars/product images. |
| `20260307000003_notifications.sql` | Device tokens and notifications. |
| `20260311000004_coach_directory_rpc.sql` | Initial coach directory RPC. |
| `20260312000005_account_deletion.sql` | Soft delete account RPC. |
| `20260312000006_core_role_flows.sql` | Member/seller profiles, preferences, progress, coach packages/availability/reviews, order items/history, dashboards, order/subscription RPCs. |
| `20260312000007_store_orders_hardening.sql` | Carts, favorites, shipping addresses, checkout requests, hardened store order flow. |
| `20260312000008_monetization_billing.sql` | Billing products, customers, transactions, entitlements, sync events. |
| `20260313000009_ai_member_planner.sql` | AI plan drafts, plan days/tasks/logs, activation and agenda/reminder RPCs. |
| `20260315000010_ai_personalization_memory.sql` | AI long-term user memories and per-session state. |
| `20260316000011_hard_delete_account.sql` | Hard-delete preparation and RPC hardening updates. |
| `20260316000012_personalized_news.sql` | News sources/articles/topics/interactions/bookmarks/interests and news RPCs. |
| `20260316000013_news_sync_scheduler.sql` | Private scheduler config and pg_cron/pg_net helper functions. |
| `20260317000014_coach_offers_marketplace.sql` | Coach offer marketplace RPC refinements and starter plan activation. |
| `20260318000015_egypt_coaching_marketplace_v1.sql` | Egypt coaching checkout, threads, messages, check-ins, photos, verification/payout/referral structures. |
| `20260418000016_nutrition_system.sql` | Nutrition profiles, targets, meal templates, meal plans, logs, hydration, check-ins. |
| `20260418000017_coach_member_insights.sql` | Consent-gated coach/member insight settings, audit, recommendations, and insight RPCs. |
| `20260421000018_coach_workspace_crm.sql` | Coach CRM records, notes, automation events, thread read state, and workspace/client RPCs. |
| `20260421000019_coach_program_delivery.sql` | Coach exercise library, program templates, habit templates/logs, and workout task extensions. |
| `20260421000020_coach_onboarding_resources.sql` | Coach resources bucket, assignments, onboarding templates, and onboarding application RPCs. |
| `20260421000021_coach_calendar_booking.sql` | Coach session types, booking flow, availability extensions, and bookable slot/calendar RPCs. |
| `20260421000022_coach_billing_verification.sql` | Manual coaching payment receipts, audit trail, checkout-status expansion, and billing verification RPCs. |
| `20260421000023_coach_public_profile_conversion.sql` | Public coach profile conversion fields plus hidden v1 group coaching/community hooks. |
| `20260421000024_taiyo_member_os.sql` | TAIYO Member OS readiness, briefs, adaptations, nudges, active workout sessions, weekly summaries, and supporting RPCs. |

Migration parity note:

- `[Code]` The local repo now contains 24 migrations through `20260421000024`.
- `[Live]` The last verified remote migration history on 2026-04-20 included versions through `20260418000017`.
- `[Risk]` Migrations `20260421000018` through `20260421000024` are repo-defined but were not re-verified against live in the 2026-04-21 repo audit because Supabase CLI access was unauthorized.

### 9.2 Table Inventory Grouped By Subsystem

| Subsystem | Tables |
| --- | --- |
| Identity/roles | `roles`, `users`, `profiles` |
| Auth-adjacent profile extensions | `member_profiles`, `coach_profiles`, `seller_profiles`, `user_preferences` |
| Coach marketplace | `coach_packages`, `coach_availability_slots`, `coach_reviews`, `subscriptions` |
| Egypt coaching relationship layer | `coach_checkout_requests`, `coach_member_threads`, `coach_messages`, `weekly_checkins`, `progress_photos`, `coach_verifications`, `coach_payouts`, `coach_referrals` |
| Coach CRM/workspace | `coach_client_records`, `coach_client_notes`, `coach_automation_events`, `coach_thread_reads` |
| Coach program delivery | `coach_exercise_library`, `coach_program_templates`, `coach_habit_templates`, `member_habit_assignments`, `member_habit_logs` |
| Coach onboarding/resources | `coach_resources`, `coach_resource_assignments`, `coach_onboarding_templates`, `coach_onboarding_applications` |
| Coach calendar/billing | `coach_session_types`, `coach_bookings`, `coach_payment_receipts`, `coach_payment_audit_events` |
| Prepared group coaching hooks | `coach_group_programs`, `coach_challenges`, `coach_group_memberships`, `coach_group_posts` |
| Store/orders | `products`, `orders`, `order_items`, `order_status_history`, `store_carts`, `store_cart_items`, `store_checkout_requests`, `product_favorites`, `shipping_addresses` |
| Billing/monetization | `billing_products`, `billing_customers`, `store_transactions`, `subscription_entitlements`, `billing_sync_events` |
| Chat/AI | `chat_sessions`, `chat_messages`, `ai_plan_drafts`, `ai_user_memories`, `ai_session_state` |
| TAIYO coach/member OS | `member_daily_readiness_logs`, `member_ai_daily_briefs`, `member_ai_plan_adaptations`, `member_ai_nudges`, `member_active_workout_sessions`, `member_active_workout_events`, `member_ai_weekly_summaries` |
| Planner/workouts | `workout_plans`, `workout_plan_days`, `workout_plan_tasks`, `workout_task_logs`, `workout_sessions` |
| Member progress | `member_weight_entries`, `member_body_measurements` |
| News | `news_sources`, `news_articles`, `news_article_topics`, `user_news_interests`, `news_article_interactions`, `news_article_bookmarks`, `private.news_scheduler_config` |
| Notifications | `device_tokens`, `notifications` |
| Nutrition | `nutrition_profiles`, `nutrition_targets`, `nutrition_meal_templates`, `member_meal_plans`, `member_meal_plan_days`, `member_planned_meals`, `meal_logs`, `hydration_logs`, `nutrition_checkins` |
| Coach/member insights | `coach_member_visibility_settings`, `coach_member_visibility_audit`, `member_product_recommendations` |

Table-level schema changes to existing objects:

- `workout_plan_tasks` now has `exercise_id`, `rest_seconds`, `substitution_options_json`, `progression_rule`, `coach_cues_json`, and `block_label`.
- `workout_sessions` now includes readiness, difficulty, pace delta, shortened/swapped flags, completion rate, and `summary_json`.
- `workout_task_logs` now includes difficulty, pain, substitution flags, swap reason, and `actual_exercise_title`.
- `workout_plans` now includes `adaptation_mode`, `last_adapted_at`, and `last_ai_brief_at`.
- `coach_availability_slots` now has session-type linkage and booking-policy columns such as notice windows, buffers, and delivery mode.
- `subscriptions.checkout_status` now includes receipt and verification-oriented states such as `receipt_uploaded`, `under_verification`, `paid`, and `failed`.
- `coach_profiles` now includes public conversion fields such as `headline`, `positioning_statement`, `certifications_json`, `trust_badges_json`, `faq_json`, and `response_metrics_json`.

### 9.3 Important RPC Inventory

Identity/account:

- `current_role`
- `soft_delete_account`
- `prepare_account_for_hard_delete`

Store/order:

- `create_store_order`
- `list_member_orders_detailed`
- `list_seller_orders_detailed`
- `seller_dashboard_summary`
- `update_store_order_status`

Coaching marketplace/subscription:

- `list_coach_directory`
- `list_coach_directory_v2`
- `get_coach_public_profile`
- `list_coach_public_packages`
- `list_coach_public_reviews`
- `submit_coach_review`
- `refresh_coach_rating_aggregate`
- `handle_coach_review_aggregate`
- `request_coach_subscription`
- `create_coach_checkout`
- `update_coach_subscription_status`
- `list_coach_subscription_requests`
- `activate_coach_subscription_with_starter_plan`
- `confirm_coach_payment`
- `list_member_subscriptions_detailed`
- `list_member_subscriptions_live`
- `ensure_coach_member_thread`
- `submit_weekly_checkin`
- `pause_coach_subscription`
- `switch_coach_request`
- `sync_coach_thread_after_message`

Coach workspace/CRM:

- `coach_dashboard_summary`
- `list_coach_clients`
- `coach_workspace_summary`
- `list_coach_action_items`
- `list_coach_client_pipeline`
- `get_coach_client_workspace`
- `upsert_coach_client_record`
- `add_coach_client_note`
- `mark_coach_thread_read`
- `dismiss_coach_action_item`

Coach program delivery/onboarding/resources:

- `list_coach_program_templates`
- `save_coach_program_template`
- `assign_program_template_to_client`
- `list_coach_exercises`
- `save_coach_exercise`
- `assign_client_habits`
- `list_coach_resources`
- `save_coach_resource`
- `assign_resource_to_client`
- `list_coach_onboarding_templates`
- `save_coach_onboarding_template`
- `apply_coach_onboarding_flow`

Coach calendar/billing:

- `seed_default_coach_session_types`
- `list_coach_session_types`
- `save_coach_session_type`
- `list_coach_bookings`
- `list_coach_bookable_slots`
- `create_coach_booking`
- `update_coach_booking_status`
- `coach_billing_state`
- `submit_coach_payment_receipt`
- `list_coach_payment_queue`
- `verify_coach_payment`
- `fail_coach_payment`
- `list_coach_payment_audit`

AI/planner:

- `activate_ai_workout_plan`
- `list_member_plan_agenda`
- `upsert_workout_task_log`
- `sync_member_task_notifications`
- `update_ai_plan_reminder_time`

TAIYO coach/member OS:

- `upsert_member_readiness_log`
- `get_member_ai_coach_context`
- `apply_member_ai_adjustment`
- `start_member_active_workout`
- `record_member_active_workout_event`
- `complete_member_active_workout`
- `build_member_ai_weekly_summary`
- `share_member_ai_weekly_summary`

News:

- `list_personalized_news`
- `list_saved_news_articles`
- `list_news_article_topics`
- `track_news_interaction`
- `save_news_article`
- `dismiss_news_article`
- `bump_user_news_interest`
- `sync_member_news_interests`
- `upsert_user_news_interest`
- `news_target_matches`
- `news_safe_jsonb_array`
- `normalize_news_goal`
- `normalize_news_level`

Billing:

- `ensure_billing_customer`

Coach/member insights:

- `get_coach_member_insight`
- `list_coach_member_insight_summaries`
- `get_member_visibility_settings`
- `upsert_coach_member_visibility`
- `list_visibility_audit`

Private scheduler:

- `private.schedule_news_sync`
- `private.unschedule_news_sync`
- `private.upsert_news_scheduler_config`

### 9.4 RLS Intent

Common RLS pattern:

- Owner tables allow the authenticated user to read/manage their own rows.
- Public marketplace tables expose active/published rows and owner rows.
- Participant tables allow member/coach or member/seller participants to read relevant records.
- Storage policies mirror the same owner/participant model for avatars, product images, coach resources, and coach payment receipts.
- Mutating multi-table business flows are centralized into `security definer` RPCs where appropriate.

Examples:

- Products: active products readable by buyers, seller-owned rows manageable by seller.
- Orders: member or seller can read related order rows.
- Coach threads/messages/check-ins: participants can read/insert, and thread read state is participant-scoped.
- Coach resources and payment receipts: object access is limited to owner or related subscription participants.
- Coach billing audit rows: participants can read, but review mutations remain coach-only.
- Nutrition: members manage their own nutrition rows; active templates are readable.
- TAIYO coach/member OS: members own their readiness, brief, nudge, active-session, workout-event, and weekly-summary rows.
- Visibility insights: member manages settings; coach reads only when tied to active subscription and consent.
- Billing entitlements: writes are intended through service-role Edge Functions/RPCs, not direct client table writes.

### 9.5 Edge Function Inventory

Live deployment note:

- `[Live]` The deployment column below reflects the last verified snapshot from 2026-04-20, not a fresh 2026-04-21 re-check.

| Function directory | Source status | Deployed in last verified snapshot? | Purpose |
| --- | --- | --- | --- |
| `ai-chat` | Implemented | Yes, version 24 | TAIYO chat and planner orchestration. |
| `ai-coach` | Implemented | No | TAIYO Coach daily brief, nudges, workout prompts, weekly summary refresh, and memory maintenance orchestration. |
| `delete-account` | Implemented | Yes, version 10 | Prepare account for deletion, remove storage files, delete auth user. |
| `sync-news-feeds` | Implemented | Yes, version 15 | RSS/Atom ingestion and news classification. |
| `billing-verify-apple` | Implemented | No | Apple receipt verification and entitlement upsert. |
| `billing-verify-google` | Empty directory | No | Referenced by client but not implemented. |
| `billing-refresh-entitlement` | Empty directory | No | Referenced by client but not implemented. |
| `billing-apple-notifications` | Empty directory | No | Placeholder only. |
| `billing-google-rtdn` | Empty directory | No | Placeholder only. |
| `_shared` | Shared helper files | Not deployable | `billing.ts` and `cors.ts`. |

### 9.6 Edge Function Details

`ai-chat`:

- Requires `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.
- Optional provider envs: `GEMINI_API_KEY`, `GEMINI_MODEL`, `GROQ_API_KEY`, `GROQ_MODEL`.
- Authenticates user bearer token.
- Supports `reply` and `regenerate_plan`.
- Persists chat messages, planner drafts, memory, and session state.

`ai-coach`:

- Requires `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.
- Authenticates the user bearer token and creates a user-scoped service-role client.
- Supports modes `refresh_daily_brief`, `run_accountability_scan`, `workout_prompt`, `refresh_weekly_summary`, and `maintain_memory`.
- Builds member context through RPC `get_member_ai_coach_context`.
- Upserts `member_ai_daily_briefs`, `member_ai_nudges`, and `member_ai_weekly_summaries` through a mix of direct table writes and RPC calls.
- Records active-workout prompt events and maintains allow-listed `ai_user_memories`.
- Was not deployed in the last verified live snapshot.

`delete-account`:

- Requires `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.
- Authenticates bearer token.
- Requires current password confirmation for email/password provider at client and function layers.
- Calls `prepare_account_for_hard_delete`.
- Removes avatar and product-image storage prefixes.
- Deletes Supabase Auth user using service role.

`sync-news-feeds`:

- Requires `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and usually `NEWS_SYNC_SECRET`.
- Allows authorization via `x-news-sync-secret` or service-role bearer token.
- Fetches active sources, parses feeds, classifies articles, upserts articles/topics, updates source sync status.

`billing-verify-apple`:

- Requires `APPLE_SHARED_SECRET` plus shared service-role envs.
- Verifies Apple receipts against production and sandbox when needed.
- Resolves monthly/annual plan from Apple product IDs.
- Upserts `store_transactions` and `subscription_entitlements`.
- Records billing sync events through shared helper.
- Was not deployed in the last verified live snapshot.

## 10. Live Snapshot Vs Repo Parity

### 10.1 Last Live Snapshot Verified On 2026-04-20

Live project:

| Item | Value |
| --- | --- |
| Project name | `gymunity` |
| Project ref | `pooelnnveljiikpdrvqw` |
| Region | `eu-west-2` |
| Status | `ACTIVE_HEALTHY` |
| Database host | `db.pooelnnveljiikpdrvqw.supabase.co` |
| Postgres engine | `17` |
| Database version | `17.6.1.063` |
| Created at | `2026-03-08T03:15:06.982769Z` |

Live storage seen in that snapshot:

| Bucket | Public |
| --- | --- |
| `avatars` | `false` |
| `product-images` | `true` |

Live functions seen in that snapshot:

| Function | Status | Version | `verify_jwt` |
| --- | --- | --- | --- |
| `ai-chat` | `ACTIVE` | 24 | `false` |
| `delete-account` | `ACTIVE` | 10 | `false` |
| `sync-news-feeds` | `ACTIVE` | 15 | `false` |

Live auth seen in that snapshot:

- Email auth enabled.
- Google auth enabled.
- Apple auth disabled.
- Phone auth disabled.
- Redirect allow-list includes `gymunity://auth-callback` and `gymunity-dev://auth-callback`.
- Signups are not disabled.
- Site URL remained `http://localhost:3000`.

Live migrations seen in that snapshot:

- Remote migration history included all repo migrations through `20260418000017`.

### 10.2 Repo Defined But Not Live Deployed In The Last Verified Snapshot

| Object | Repo status | Last verified live status | Risk |
| --- | --- | --- | --- |
| `ai-coach` Edge Function | Implemented source exists | Not deployed in the last verified snapshot | TAIYO Coach refresh, prompt, and weekly-summary orchestration are not live-confirmed. |
| `billing-verify-apple` Edge Function | Implemented source exists | Not deployed | iOS purchase verification fails if AI Premium enabled. |
| `billing-verify-google` Edge Function | Empty directory only | Not deployed | Android purchase verification fails if AI Premium enabled. |
| `billing-refresh-entitlement` Edge Function | Empty directory only | Not deployed | Subscription refresh fails if AI Premium enabled. |
| `billing-apple-notifications` | Empty directory only | Not deployed | App Store server notifications not handled. |
| `billing-google-rtdn` | Empty directory only | Not deployed | Google RTDN not handled. |

### 10.3 Repo Ahead Of The Last Verified Live Snapshot

The current repo contains migrations and feature code that were not present in the last verified live snapshot:

| Repo-only delta not re-verified live on 2026-04-21 | Evidence |
| --- | --- |
| Coach workspace CRM (`20260421000018`) | New tables for client records, notes, automation events, thread reads, and workspace/client RPCs. |
| Coach program delivery (`20260421000019`) | Program templates, exercise library, habit assignment, and workout task extensions. |
| Coach onboarding/resources (`20260421000020`) | `coach-resources` bucket plus resource/onboarding template RPCs. |
| Coach calendar/booking (`20260421000021`) | Session types, availability-policy columns, bookings, and bookable-slot RPCs. |
| Coach billing verification (`20260421000022`) | `coach-payment-receipts` bucket, receipt/audit tables, and billing verification RPCs. |
| Coach public profile conversion (`20260421000023`) | Public-profile conversion fields and hidden group coaching hooks. |
| TAIYO Member OS (`20260421000024`) | Readiness, daily brief, adaptation, nudge, active-workout, and weekly-summary tables plus member-OS RPCs. |
| TAIYO Coach app/runtime surface | `lib/features/ai_coach/`, `/active-workout-session`, member-home AI entry points, `aiCoachBootProvider`, and `supabase/functions/ai-coach/`. |

Interpretation:

- `[Code]` These changes are present in the repository and wired into the Flutter app.
- `[Risk]` Exact live object presence, grants, and schema-cache behavior for these deltas were not re-verified in this repo audit.

### 10.4 Live Verification Limits In The 2026-04-21 Repo Audit

- `supabase migration list --linked` returned `401 Unauthorized`.
- `supabase projects list` also returned `401 Unauthorized`.
- The CLI explicitly requested `SUPABASE_DB_PASSWORD` to connect to the linked database.
- Because of that, this update intentionally preserves the previous live snapshot as historical evidence rather than presenting it as freshly re-checked state.

### 10.5 Existing Documentation Drift

`docs/gymunity_project_full_documentation.md` still reflects an older live-check pass. The current repo audit updates the technical reference to account for:

- Seven repo-only migrations (`20260421000018` through `20260421000024`).
- The expanded coach workspace plus TAIYO Coach surface in Flutter routes, repositories, Edge Functions, and tests.
- The fact that live claims in this file are now clearly labeled as a retained 2026-04-20 snapshot rather than a fresh 2026-04-21 verification.

## 11. End-To-End Flows

### 11.1 App Startup

```text
main()
  -> ensure Flutter bindings
  -> load local runtime config only if dart-define config invalid
  -> initialize Supabase if config valid
  -> run ProviderScope/GymUnityApp
  -> start monetization, planner reminder, and TAIYO Coach bootstraps after first frame
  -> MaterialApp opens "/"
  -> SplashScreen watches AppBootstrapController
  -> AppBootstrapController validates config
  -> SupabaseInitializer initializes/validates persisted session
  -> AuthDeepLinkBootstrap starts
  -> UserRepository reads current user
  -> account status checked
  -> AuthRouteResolver picks welcome, role selection, onboarding, or dashboard
  -> SplashScreen route-replaces after minimum splash duration
```

### 11.2 Login / Register / OAuth / Recovery

```text
Login/Register UI
  -> user taps Google CTA
  -> AuthFlowController.startOAuth(google)
  -> AuthRepository.signInWithOAuth()
  -> Supabase launches provider browser
  -> app receives gymunity://auth-callback...
  -> AuthCallbackIngress emits URI or AuthCallbackScreen handles route callback
  -> AuthFlowController hydrates session from URL or exchanges code
  -> AuthController.completeAuthenticatedSession()
  -> UserRepository.ensureUserAndProfile()
  -> AuthRouteResolver.resolveAfterAuth()
  -> route to role selection, onboarding, or dashboard
```

Recovery path:

```text
Recovery callback with type=recovery
  -> AuthFlowController marks pending recovery
  -> session hydrated if available
  -> success route becomes /reset-password
```

Current caveat:

- Register/forgot/reset screens are present but currently communicate Google-only access instead of full email/password UX.

### 11.3 Role Selection And Onboarding

```text
Authenticated user without profile role
  -> /role-selection
  -> user selects member/coach/seller
  -> UserRepository.saveRole()
  -> profiles.role_id updated
  -> role-specific onboarding screen
  -> role-specific repository upserts profile data
  -> profiles.onboarding_completed = true
  -> AuthRouteResolver sends user to role dashboard
```

### 11.4 Member Home Loading

```text
/member-home
  -> member home providers load profile/preferences/progress/plans/subscriptions
  -> aiCoachDailyBriefProvider(today) resolves the featured TAIYO Coach card
  -> MemberRepository.getHomeSummary()
  -> reads member profile
  -> reads preferences
  -> reads latest weight and measurements
  -> reads active/latest plan
  -> reads recent workout sessions
  -> reads subscriptions through live RPC with fallback
  -> UI renders summary cards and navigation into TAIYO Coach, coaches, store, news, progress, profile
```

### 11.5 Coach Subscription Flow

```text
Member opens /coaches
  -> CoachRepository.listCoaches() calls list_coach_directory_v2
  -> member opens coach details/packages
  -> member starts paid checkout
  -> structured intake dialog collects goals, constraints, budget, city, payment rail
  -> CoachRepository.requestSubscription()
  -> RPC create_coach_checkout()
  -> subscription enters pending/manual-payment state
  -> member uploads a receipt or payment reference from My Coaching
  -> file is stored in coach-payment-receipts when present
  -> RPC submit_coach_payment_receipt()
  -> coach billing queue surfaces the submission for review
  -> coach verifies or fails the payment and audit history is written
  -> thread is ensured and coach can activate/assign starter plan from client workflow
```

### 11.6 Store Checkout Flow

```text
Member opens store
  -> StoreRepository.listProducts()
  -> member adds item to server-side cart
  -> cart rows stored in store_carts/store_cart_items
  -> checkout requires shipping address
  -> CheckoutScreen states payment is manual/not in-app card processing
  -> StoreRepository.placeOrderFromCart()
  -> RPC create_store_order(target_shipping_address_id, client_idempotency_key)
  -> order/items/status history created
  -> member sees order in /orders
  -> seller manages status in /seller-orders
```

### 11.7 AI Chat Flow

```text
Member opens chat from TAIYO Coach or another AI entry point
  -> aiPremiumGateProvider decides free/unlocked/locked
  -> ChatController creates or opens chat session
  -> user message inserted into chat_messages
  -> ChatRepository invokes ai-chat Edge Function
  -> Edge Function builds context from profile/progress/plans/memory
  -> provider call to Gemini or Groq
  -> assistant reply persisted
  -> session metadata/memory updated
  -> UI stream displays ordered messages
```

### 11.8 TAIYO Coach Daily Brief And Active Workout

```text
App startup or resume
  -> aiCoachBootProvider.start()/refresh()
  -> AiCoachRepository.maintainMemory()
  -> ai-coach refreshes daily brief, nudges, and weekly summary
  -> member opens /ai-chat-home
  -> AiCoachHomeScreen loads brief, nudges, readiness form, and weekly summary
  -> readiness submit calls upsert_member_readiness_log()
  -> shorten/swap/move actions call apply_member_ai_adjustment()
  -> start workout calls start_member_active_workout()
  -> /active-workout-session opens or self-bootstraps
  -> ai-coach workout_prompt records prompt events for the active session
  -> complete_member_active_workout() writes workout_task_logs/workout_sessions
  -> share_member_ai_weekly_summary() can post the recap into the coach thread
```

### 11.9 Planner Generation And Activation Flow

```text
Member opens Plan Builder
  -> Builder scans member context and AI memory
  -> critical missing fields become question cards
  -> structured prompt sent to planner chat session
  -> ai-chat returns needs_more_info or plan_ready
  -> plan_ready creates/updates ai_plan_drafts
  -> AiGeneratedPlanScreen opens with sessionId/draftId
  -> member activates draft
  -> RPC activate_ai_workout_plan()
  -> workout_plans/workout_plan_days/workout_plan_tasks created
  -> WorkoutPlanScreen loads active plan
  -> planner reminder bootstrap syncs local notifications
```

### 11.10 Nutrition Flow

```text
Member opens Nutrition
  -> if no profile/target/plan, user starts NutritionSetupScreen
  -> setup loads member profile, preferences, weight entries, existing nutrition profile
  -> user answers nutrition questions
  -> member profile may be updated with missing body/goal fields
  -> nutrition profile upserted
  -> CalorieEngine calculates BMR/TDEE/calorie target/macros/hydration
  -> active target saved; prior targets archived
  -> meal templates loaded
  -> MealPlanGenerator creates 7-day deterministic plan
  -> active meal plan saved; prior active meal plans archived
  -> user completes planned meals, quick-adds meals, logs hydration, and records check-ins
```

### 11.11 Coach-Member Insights Flow

```text
Member with coaching subscription opens visibility settings
  -> get_member_visibility_settings(subscriptionId)
  -> all sharing defaults off if no row
  -> member toggles categories and saves
  -> upsert_coach_member_visibility writes settings and audit row
  -> coach dashboard/client insight summary calls list_coach_member_insight_summaries()
  -> coach opens member insight detail
  -> get_coach_member_insight(memberId, subscriptionId)
  -> backend returns only consented sections plus risk flags
```

### 11.12 Monetization / Entitlement Flow

```text
App startup
  -> MonetizationBootstrapService.start()
  -> if ENABLE_AI_PREMIUM=false, exit and AI gate grants free access
  -> if true, listen to native purchase updates
  -> refresh entitlement through billing-refresh-entitlement
  -> Android reconciles existing purchases
  -> paywall loads native store products
  -> purchase update received
  -> sync purchase through billing-verify-google or billing-verify-apple
  -> subscription_entitlements refreshed
  -> aiPremiumGateProvider unlocks or locks TAIYO
```

Current blocker:

- This flow is not production-safe while required billing Edge Functions are absent from source/live deployment.

### 11.13 Delete Account Flow

```text
User opens /delete-account
  -> screen resolves current auth provider
  -> user types DELETE
  -> email/password users must enter current password
  -> AuthRepository reauthenticates email/password users
  -> AuthRemoteDataSource invokes delete-account Edge Function
  -> function authenticates bearer token
  -> function calls prepare_account_for_hard_delete()
  -> function removes storage prefixes
  -> function deletes Supabase Auth user
  -> client signs out
  -> UI routes to /login
```

## 12. Test Coverage

### 12.1 Test Inventory

Flutter tests under `test/` include:

- Auth callback utilities, token project-ref parsing, auth route resolution, and auth screen flows.
- Welcome screen behavior.
- Role selection and onboarding failure/success behavior.
- Route and feature wiring for support, edit profile, OAuth callback route, coach dashboard, coach package editor, subscription package intake, coach client approval, seller dashboard, store add-to-cart, cart, TAIYO landing surfaces, and AI conversation behavior.
- AI chat personalization and controller behavior.
- AI chat home screen behavior.
- AI coach provider, readiness, and active workout companion behavior.
- Planner builder screen, question factory, summary provider, notification IDs, reminder bootstrap service, and workout plan reminder card behavior.
- News model, card, and feed behavior.
- Member home shell behavior.
- Delete account screen validation.
- Coach repository mapping/parsing behavior.
- Coach workspace widget flows such as billing details and workspace state rendering.
- Coach-member insight and visibility entity parsing.
- General app render smoke tests.
- Historical record utility tests.
- One opt-in manual live planner repository test skipped by default.

Deno tests under `supabase/functions/` include:

- `ai-chat/engine_test.ts`
- `ai-coach/engine_test.ts`
- `delete-account/index_test.ts`
- `sync-news-feeds/classifier_test.ts`
- `sync-news-feeds/index_test.ts`

### 12.2 Covered Well

- Auth route/callback edge cases.
- Google OAuth screen behavior and timeout/error handling.
- TAIYO landing and conversation routing behavior.
- AI coach provider refresh/start-workout state behavior.
- Onboarding failure and success behavior.
- Route wiring for many formerly placeholder-prone routes.
- AI chat UI flow and message ordering/locking behavior.
- Planner builder question derivation and reminder scheduling helpers.
- Coach workspace widget behavior for billing and related UI state.
- Coach repository entity parsing for newer workspace/domain payloads.
- Coach-member insight entity parsing.
- Store/cart basic UI wiring through fakes.

### 12.3 Partially Covered

- Coach subscription request/activation is tested through fakes and route widgets, not live backend.
- Coach calendar, booking, resources, onboarding-flow, and billing-review screens are represented in route/repository/widget coverage, but not validated end-to-end against a live Supabase backend.
- Store checkout/order behavior is partially covered through fakes and UI tests, not full live RPC integration.
- Planner repository has an opt-in live test, but it is skipped by default.
- Edge Function internals have Deno tests for `ai-chat`, `ai-coach`, news ingestion, and delete-account, but not for billing.

### 12.4 Missing Or Weak Coverage

- No full integration test for production OAuth on real devices.
- No end-to-end live tests for store checkout, seller fulfillment, coach checkout/payment receipt verification, or thread messaging.
- No live tests for coach-member visibility RPCs.
- No live tests for new coach workspace RPCs such as pipeline/workspace/calendar/resources/billing/onboarding flows.
- No live tests for TAIYO Coach daily brief, nudges, active workout, or weekly summary flows against Supabase.
- No live tests for nutrition persistence and meal plan generation against Supabase.
- No automated tests for RLS policy correctness.
- No tests for deployed Edge Function parity.
- No tests for billing verification functions, and several billing functions are missing.
- No fresh automated schema parity test between local migrations and live objects.

### 12.5 Test Execution Status In This Audit

- `flutter --version` succeeded: Flutter 3.41.4, Dart 3.11.1.
- `flutter test` was run during this audit and failed.
- Result observed: `107` passed, `1` skipped, `4` failed.
- The skipped test was the opt-in live planner probe in `test/manual_live_planner_repository_test.dart`.
- Failing tests observed:
  - `test/news_card_test.dart`: expected an icon that was not found.
  - `test/news_feed_screen_test.dart`: expected `Recommended Reads` text that was not found.
  - `test/member_home_shell_test.dart`: `AI tab remains on the TAIYO home after rebuild`.
  - `test/member_home_shell_test.dart`: `home quick action opens the TAIYO screen`.
- Supabase live read-only checks were not refreshed in this 2026-04-21 repo audit because CLI access was unauthorized.

## 13. Known Risks And Gaps

### 13.1 Highest-Risk Gaps

| Risk | Severity | Evidence |
| --- | --- | --- |
| Billing/AI Premium backend is incomplete. | High | Client calls `billing-refresh-entitlement` and `billing-verify-google`, but those directories are empty and no billing functions were deployed in the last verified live snapshot. |
| Last verified live state is stale relative to the repo. | High | The 2026-04-21 repo audit could not re-run live Supabase checks because CLI commands returned `401 Unauthorized` and requested `SUPABASE_DB_PASSWORD`. |
| Manual live test embeds live credentials/client key material. | High | `test/manual_live_planner_repository_test.dart` contains live login credentials and anon key. |
| Feature flags are partially declarative but not enforced. | Medium/High | Store purchases, coach subscriptions, and Apple sign-in flags are not found in route/business gating. |
| Direct route access is not role-guarded in `AppRoutes`. | Medium | Startup resolver routes users correctly, but route table itself builds role screens without checking role. |
| Empty Edge Function directories can mislead reviewers/deploy scripts. | Medium | Billing notification/Google/refresh directories exist but contain no implementation. |
| Working tree contains untracked coach and TAIYO feature code and migrations. | Medium | Coach workspace, coach-member-insights, TAIYO Coach, and `20260421000024_taiyo_member_os.sql` additions remain partly untracked in `git status`. |
| Current Flutter test suite is not green. | Medium | `flutter test` failed with 4 current failures in `test/news_card_test.dart`, `test/news_feed_screen_test.dart`, and two expectations in `test/member_home_shell_test.dart`. |
| Mojibake encoding artifacts exist in some source files. | Medium | Role selection and coach-member-insights files contain garbled comment text and at least some visible separator/product symbols. |
| Product currency hardcoded as `USD`. | Medium | Seller/product repository behavior conflicts with Egypt-market context. |

### 13.2 Implementation Gaps

- AI Premium is not production-ready.
- Android billing verification is not implemented.
- Billing entitlement refresh is not implemented as an Edge Function.
- Store and coach payments are manual/external, not real-time in-app payment processing.
- Some feature flags do not enforce feature availability.
- Pagination abstractions exist where actual cursor pagination is absent.
- Some repository methods include schema-compatible fallback logic, indicating tolerated backend drift.
- Email/password auth code remains while UI has moved to Google-only behavior.

### 13.3 Operational Concerns

- Live auth `site_url` is `http://localhost:3000`; mobile redirect allow-list is correct, but production web/support flows should verify whether this is intentional.
- The last verified live snapshot had email auth enabled even though current UI is Google-only.
- Apple auth was disabled in the last verified live snapshot while config has `ENABLE_APPLE_SIGN_IN` default true.
- The last verified live snapshot only confirmed remote migration history through `20260418000017`; newer coach and TAIYO Member OS migrations remain repo-only until re-verified.
- Local Supabase config does not mirror live Google provider settings.

### 13.4 Security And Privacy Caveats

- Move hardcoded live test credentials and anon key out of tests.
- Do not commit personal access tokens or service role keys.
- Confirm delete-account storage deletion prefixes match all actual uploaded file paths.
- Confirm coach resource and payment receipt storage policies do not expose unrelated subscription files.
- Validate that coach-member insight RPCs never leak non-consented sections.
- Add RLS tests or SQL policy checks for participant tables.
- Treat AI memories and session state as sensitive user data.

## 14. Implementation Status Matrix

| Feature | Status | Notes |
| --- | --- | --- |
| Auth / Google OAuth | Fully implemented | Google auth was enabled in the last verified live snapshot. |
| Email/password auth | Partial / code-only UI-disabled | Repository exists; UI says Google-only. |
| Role selection | Fully implemented | Coach/seller cards feature-flagged. |
| Member onboarding | Implemented | Persists member profile/preferences. |
| Coach onboarding/profile | Implemented but needs live UX verification | Schema-compatible writes hide drift. |
| Seller onboarding/profile | Implemented | Seller profile screen exists. |
| Member home/progress | Implemented | Uses real repositories and providers. |
| Coach workspace/CRM | Implemented in repo; live parity not re-verified | Dashboard shell, pipeline, client workspace, notes, alerts, and read state are wired through new RPCs. |
| Coach programs/resources/onboarding | Implemented in repo; live parity not re-verified | Program library, habits, resources, and onboarding templates exist in UI/repository/migrations. |
| Coach calendar/billing | Implemented in repo; live parity not re-verified | Session types, bookings, receipt queue, verification, and audit flows are present. |
| Coach marketplace | Implemented but manual/external checkout | Discovery and public profile conversion fields are live in code; payment remains manual. |
| Store/catalog/cart/checkout/orders | Implemented but manual payment | Store order RPCs defined; payment not processed in-app. |
| Seller product/order management | Implemented | Currency hardcoded USD. |
| TAIYO chat | Implemented and live-deployed in the last verified snapshot | `ai-chat` live. |
| TAIYO Coach / Member OS | Implemented in repo; live parity not re-verified | Daily brief, readiness, nudges, weekly summary, active workout companion, `/ai-chat-home` remap, and `ai-coach` are present in source. |
| TAIYO planner | Implemented and migration-applied through the last verified snapshot | Activation/agenda/reminders implemented. |
| Nutrition | Implemented but needs live feature testing | Last verified migration snapshot included nutrition; no fresh 2026-04-21 object inventory. |
| Personalized news | Implemented and live-deployed ingestion in the last verified snapshot | `sync-news-feeds` live. |
| Notifications | Implemented | Supabase stream for in-app notifications, AI nudges, plus local planner reminders. |
| AI Premium monetization | Partial / unsafe if enabled | Missing/deployed billing functions. |
| Settings/support/legal | Implemented | External links depend on config. |
| Delete account | Implemented and live-deployed in the last verified snapshot | Function live. |
| Coach-member insights | Implemented but untracked; needs live feature testing | Last verified live snapshot included its migration; code contains encoding artifacts. |
| Billing Apple verification | Repo-defined but not live-confirmed in the last verified snapshot | Source exists but function was not deployed. |
| Billing Google verification | Placeholder only | Empty directory and not live. |
| Billing entitlement refresh | Placeholder only | Empty directory and not live. |

## 15. File Map

### 15.1 Core Files

| File | Purpose |
| --- | --- |
| `lib/main.dart` | Entry point and pre-run initialization. |
| `lib/app/app.dart` | `MaterialApp`, lifecycle hooks, locale/theme, bootstrap services. |
| `lib/app/routes.dart` | Central route map. |
| `lib/core/config/app_config.dart` | Runtime config keys, defaults, validation. |
| `lib/core/config/local_runtime_config_loader.dart` | Asset fallback config loader. |
| `lib/core/di/providers.dart` | Riverpod dependency graph. |
| `lib/core/error/app_failure.dart` | Failure types. |
| `lib/core/routing/auth_route_resolver.dart` | Auth/role/onboarding route decisions. |
| `lib/core/supabase/supabase_initializer.dart` | Supabase initialization and JWT project-ref validation. |
| `lib/core/supabase/auth_callback_ingress.dart` | Native/app_links auth callback ingestion. |
| `lib/core/supabase/auth_callback_utils.dart` | Callback parsing/normalization. |

### 15.2 Major Feature Directories

| Directory | Purpose |
| --- | --- |
| `lib/features/auth/` | Auth screens, controllers, repository, callback behavior. |
| `lib/features/auth/presentation/widgets/` | Editorial Google-only auth wrappers such as `GoogleOnlyAuthScreen` and `PreAuthScene`. |
| `lib/features/onboarding/` | Member/coach/seller onboarding screens. |
| `lib/features/user/` | Shared user/profile/role bridge. |
| `lib/features/member/` | Member profile, progress, subscriptions, messages, check-ins, home. |
| `lib/features/coach/` | Coach workspace shell, CRM, profile, packages, calendar, billing, resources, onboarding flows, and repository. |
| `lib/features/coaches/` | Member-facing coach marketplace. |
| `lib/features/seller/` | Seller dashboard/profile/products/orders. |
| `lib/features/store/` | Member-facing store/cart/checkout/orders. |
| `lib/features/ai_chat/` | TAIYO chat sessions/messages/UI. |
| `lib/features/ai_coach/` | TAIYO Coach briefs, readiness, nudges, active workouts, and weekly summaries. |
| `lib/features/planner/` | Plan builder, generated plan activation, agenda/reminders. |
| `lib/features/nutrition/` | Nutrition setup, calculations, meal plans, logs. |
| `lib/features/news/` | Personalized news feed and articles. |
| `lib/features/monetization/` | AI Premium gating and native IAP. |
| `lib/features/settings/` | Settings, notifications, support/legal, delete account. |
| `lib/features/coach_member_insights/` | Consent-gated coach/member insights. |

Representative feature files:

| File | Purpose |
| --- | --- |
| `lib/features/ai_coach/presentation/screens/ai_coach_home_screen.dart` | Routed TAIYO Coach landing screen for daily brief, readiness, nudges, and weekly summary. |
| `lib/features/ai_coach/presentation/screens/active_workout_session_screen.dart` | Guided active workout companion flow backed by member-OS session RPCs. |
| `lib/features/coach/domain/entities/coach_workspace_entity.dart` | Canonical domain model for coach workspace summary, pipeline, client workspace, bookings, billing, resources, and onboarding entities. |
| `lib/features/coach/presentation/screens/coach_workspace_shell.dart` | Dashboard shell that composes workspace metrics, schedule, and action items. |

### 15.3 Backend Files

| Path | Purpose |
| --- | --- |
| `supabase/migrations/` | Canonical schema/RLS/RPC source. |
| `supabase/migrations/20260421000018_coach_workspace_crm.sql` | Coach CRM/workspace tables and RPCs. |
| `supabase/migrations/20260421000019_coach_program_delivery.sql` | Program delivery, exercise library, and habit assignment. |
| `supabase/migrations/20260421000020_coach_onboarding_resources.sql` | Coach resources bucket and onboarding flows. |
| `supabase/migrations/20260421000021_coach_calendar_booking.sql` | Session types, booking flow, and availability extensions. |
| `supabase/migrations/20260421000022_coach_billing_verification.sql` | Manual payment receipt verification and audit trail. |
| `supabase/migrations/20260421000023_coach_public_profile_conversion.sql` | Public profile conversion fields and hidden group hooks. |
| `supabase/migrations/20260421000024_taiyo_member_os.sql` | TAIYO Member OS tables, RLS, and RPCs for readiness, nudges, active workouts, and weekly summaries. |
| `supabase/functions/ai-chat/` | TAIYO Edge Function and tests. |
| `supabase/functions/ai-coach/` | TAIYO Coach orchestration Edge Function and tests. |
| `supabase/functions/delete-account/` | Account deletion Edge Function and tests. |
| `supabase/functions/sync-news-feeds/` | News ingestion Edge Function, classifier, tests, README. |
| `supabase/functions/billing-verify-apple/` | Apple billing verification source. |
| `supabase/functions/_shared/` | Shared Deno helpers. |
| `supabase/functions/billing-verify-google/` | Empty placeholder directory. |
| `supabase/functions/billing-refresh-entitlement/` | Empty placeholder directory. |
| `supabase/functions/billing-apple-notifications/` | Empty placeholder directory. |
| `supabase/functions/billing-google-rtdn/` | Empty placeholder directory. |
| `supabase/sql/phase1_dashboard_setup.sql` | Consolidated dashboard SQL bundle; secondary to migrations. |

### 15.4 Scripts

| Script | Purpose |
| --- | --- |
| `scripts/sync_local_runtime_config.ps1` | Copies allowed `.env` keys into `assets/config/local_env.json`. |
| `scripts/flutter_with_env.ps1` | Runs Flutter with allowed env keys as dart-defines. |
| `scripts/flutter_test_dev.ps1` | Runs `flutter test` through env wrapper. |
| `scripts/flutter_run_dev.ps1` | Runs app through env wrapper. |
| `scripts/flutter_build_apk_dev.ps1` | Builds APK through env wrapper. |
| `scripts/flutter_build_appbundle_dev.ps1` | Builds app bundle through env wrapper. |
| `scripts/generate_app_icon.py` | Generates `assets/images/logo_app_icon.png` and `assets/images/logo_app_icon_foreground.png`. |

### 15.5 Build And Release Support Files

| File | Purpose |
| --- | --- |
| `flutter_launcher_icons.yaml` | Source configuration for Android/iOS launcher icon generation. |
| `assets/images/logo_app_icon.png` | Generated base launcher-icon source asset. |
| `assets/images/logo_app_icon_foreground.png` | Generated adaptive foreground icon source asset. |
| `android/key.properties.example` | Example keystore properties for local Android release signing. |
| `android/app/build.gradle.kts` | Release signing now requires either `android/key.properties` or `ANDROID_KEYSTORE_*` environment variables. |

## 16. Glossary

| Term | Meaning |
| --- | --- |
| `TAIYO` | GymUnity AI assistant. |
| `TAIYO Coach` | The routed AI surface for daily coaching, nudges, readiness, and active workout guidance. |
| `TAIYO Premium` | Paid AI subscription/offering controlled by `ENABLE_AI_PREMIUM` and billing entitlements. |
| `AI Premium` | Internal product/offering code `ai_premium` for TAIYO Premium access. |
| `TAIYO Member OS` | Repo-defined backend layer of readiness, adaptation, nudge, active workout, and weekly-summary objects introduced in `20260421000024`. |
| `planner` | AI-guided workout plan system that creates drafts, activates plans, schedules days/tasks, and logs task completion. |
| `coach workspace` | The coach-side operational shell spanning dashboard metrics, CRM pipeline, client workspace, check-ins, billing, calendar, programs, onboarding, and resources. |
| `client pipeline` | Coach CRM view over subscriptions using `pipeline_stage`, `internal_status`, `risk_status`, tags, and renewal/payment signals. |
| `draft` | An AI-generated plan candidate stored in `ai_plan_drafts` before activation. |
| `activation` | Converting an `ai_plan_drafts` record into `workout_plans`, `workout_plan_days`, and `workout_plan_tasks` through `activate_ai_workout_plan`. |
| `agenda` | Date-filtered list of active workout tasks returned by `list_member_plan_agenda`. |
| `daily brief` | The per-day TAIYO Coach recommendation row stored in `member_ai_daily_briefs`. |
| `nudge` | A proactive TAIYO intervention stored in `member_ai_nudges` and often mirrored into `notifications`. |
| `active workout session` | A guided member workout companion session stored in `member_active_workout_sessions` and `member_active_workout_events`. |
| `weekly summary` | TAIYO-generated adherence and recovery recap stored in `member_ai_weekly_summaries`. |
| `visibility settings` | Member-controlled consent settings that determine which data categories a coach can see. |
| `member thread` | Coaching conversation thread in `coach_member_threads` with messages in `coach_messages`. |
| `checkout request` | Coach service payment/request row in `coach_checkout_requests`. |
| `payment receipt` | A member-submitted proof-of-payment object/row used by coach billing verification flows in `coach_payment_receipts` and `coach-payment-receipts`. |
| `payment rail` | External/manual payment path for coaching checkout, such as wallet/card/Instapay semantics. |
| `subscription` | Coach/member service relationship in `subscriptions`, not necessarily an app-store subscription. |
| `entitlement` | Digital access state for AI Premium in `subscription_entitlements`. |
| `store transaction` | App-store billing transaction record in `store_transactions`, despite the name overlapping with physical store concepts. |
| `manual payment` | Store/coach payment mode where GymUnity records orders/requests but does not process card payments in-app. |
| `RLS` | Supabase/Postgres Row Level Security policies controlling table access. |
| `RPC` | Supabase-exposed Postgres function called from Flutter via `.rpc()`. |
| `repo-defined` | Present in the current repository/migrations/functions. |
| `live-deployed` | Confirmed deployed on the linked Supabase project. |
| `migration-applied` | Remote migration history contains the migration version. |

## 17. Top Next Actions

1. Implement and deploy billing functions or keep `ENABLE_AI_PREMIUM=false`.
2. Remove or replace hardcoded live credentials in `test/manual_live_planner_repository_test.dart`.
3. Commit or intentionally remove untracked coach workspace, coach-member-insights, TAIYO Coach, billing/calendar/resource screens, tests, and migrations.
4. Restore Supabase CLI/database access so live schema/function parity can be re-verified beyond the 2026-04-20 snapshot.
5. Clean mojibake/encoding artifacts in affected Dart files.
6. Enforce feature flags at route/business-action level, especially store purchases and coach subscriptions.
7. Decide whether email auth is supported or fully disabled; align live auth config, UI, and support docs.
8. Add integration tests for TAIYO Coach daily brief/workout companion flows, store checkout, coach checkout/payment verification, coach workspace/calendar/resources/onboarding RPCs, nutrition persistence, coach-member visibility RPCs, and deployed Edge Functions.
9. Resolve currency/localization strategy for store and coaching commerce.
10. Deploy repo-defined Edge Functions such as `ai-coach` from source and maintain a function deployment manifest so repo and live state cannot silently drift. 
