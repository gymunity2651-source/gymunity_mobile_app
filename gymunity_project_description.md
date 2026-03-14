# GymUnity Comprehensive Project Description

## 1. What This Project Is

GymUnity is a Flutter mobile application backed by Supabase. It is designed as a multi-role fitness platform that combines:

- A member fitness experience
- A coach discovery and coaching workflow
- A seller and fitness marketplace workflow
- AI-assisted fitness chat
- Store-billing based AI Premium subscriptions

The app is not a single-purpose workout tracker. It is a role-aware product where the same application can serve three different kinds of users:

- Members who want fitness guidance, progress tracking, coaching subscriptions, and product shopping
- Coaches who want to present their services, manage subscriptions, assign plans, and eventually manage clients more deeply
- Sellers who want to publish products, manage inventory, and handle marketplace orders

The codebase already contains real data flows for many of these areas, plus a number of routed placeholder screens for surfaces that are planned but not fully finalized in the UI yet.

This document describes the project as it exists in the current repository, based on the actual Flutter code, Supabase migrations, edge functions, routing, providers, and project docs.

## 2. Product Vision and Core Idea

GymUnity brings several fitness-related experiences into one app:

- Fitness identity and onboarding
- Role-specific dashboards
- Coaching discovery and subscription management
- E-commerce for gym-related products
- AI chat as a premium digital offering
- Real-time notifications and account management

Instead of splitting these into multiple apps, GymUnity centralizes them under one authentication system and one shared profile foundation. A user can sign in, choose a role, finish onboarding for that role, and then land in the correct part of the app automatically.

## 3. Main Technology Stack

### Frontend

- Flutter
- Riverpod for dependency injection and state management
- Supabase Flutter SDK
- In-app purchase packages for Apple App Store and Google Play billing

### Backend

- Supabase Postgres
- Supabase Auth
- Supabase Storage
- Supabase Edge Functions
- PostgreSQL row-level security and RPC functions

### AI

- OpenAI chat completions called from the `ai-chat` Supabase Edge Function

## 4. High-Level Architecture

The repository follows a feature-oriented structure. The main pattern is:

- `lib/app`: app shell, routes, top-level app widget
- `lib/core`: shared config, DI, routing helpers, theme, constants, widgets, Supabase bootstrap
- `lib/features/*`: each business area grouped by feature
- `supabase/migrations`: incremental database schema changes
- `supabase/sql`: a full bootstrap SQL bundle for fresh Supabase setup
- `supabase/functions`: edge functions for AI chat, billing verification, and account deletion
- `docs`: operational and architecture documentation
- `scripts`: local helper scripts for running and building with env-derived config

Each feature commonly contains:

- Domain entities
- Repository interfaces
- Repository implementations
- Presentation providers
- Screens and controllers

The project is close to a clean-architecture style, but implemented pragmatically rather than rigidly.

## 5. Application Startup Lifecycle

The app startup flow is important because GymUnity decides configuration validity, backend readiness, authentication state, deletion state, onboarding state, and role-specific routing before the user reaches the main UI.

### `main.dart`

Startup begins in `lib/main.dart`:

1. Flutter bindings are initialized.
2. `LocalRuntimeConfigLoader.primeIfNeeded()` attempts to load local runtime config from `assets/config/local_env.json` if compile-time defines are missing.
3. If runtime config validates successfully, Supabase is initialized.
4. The app is launched inside a global Riverpod `ProviderScope`.

### Runtime configuration behavior

GymUnity does not read `.env` directly inside Flutter runtime code. Instead:

- `AppConfig` reads compile-time values via `String.fromEnvironment`
- Local helper scripts convert `.env` into the correct `--dart-define` set
- If compile-time config is absent, the app can fall back to `assets/config/local_env.json`
- If config is still invalid, the app does not crash immediately; it stays in a configuration-required startup state

### `GymUnityApp`

The root app widget:

- Builds a `MaterialApp`
- Uses a dark theme
- Starts at the splash route `/`
- Starts monetization bootstrap after the first frame
- Refreshes premium entitlements when the app resumes
- Watches auth-aware monetization behavior when config is valid

## 6. Splash Screen and Bootstrap Logic

The splash screen is not just a branding screen. It is the app’s startup control surface.

Current behavior:

- The splash remains visible for at least `900ms`
- It listens for bootstrap state changes outside the widget build method
- It navigates only after startup state has resolved and the minimum display time has elapsed
- It can display configuration errors, backend errors, deleted-account messaging, retry actions, or support actions

### Bootstrap state machine

`AppBootstrapController` can resolve the app into these states:

- `loading`
- `authenticated`
- `unauthenticated`
- `configError`
- `backendError`
- `deletedAccount`

### Bootstrap decision flow

At launch the app:

1. Validates config through `AppConfig`
2. Initializes Supabase
3. Starts auth deep-link bootstrap
4. Reads the current Supabase-authenticated user
5. If no user exists, routes to the welcome screen
6. If the account is marked deleted/deactivated, logs out and shows a deleted-account state
7. Otherwise resolves the correct post-auth route based on role and onboarding completion

## 7. Authentication System

GymUnity supports several auth-related flows:

- Email/password login
- Registration
- OTP verification
- Forgot password
- Password reset
- OAuth sign-in
- Auth callback handling
- Session completion and profile bootstrapping
- Logout
- Account deletion

### Auth bootstrapping after sign-in

After a successful authenticated session, the app ensures that:

- A row exists in `public.users`
- A row exists in `public.profiles`
- Deleted/deactivated accounts are blocked

This means Supabase auth alone is not the whole identity model. The app relies on database-backed user and profile records to drive role resolution and onboarding.

### OAuth and deep-link callback handling

GymUnity has a dedicated callback pipeline for browser-based OAuth and recovery links.

Key pieces:

- `PlatformAuthCallbackIngress`
- `AuthDeepLinkBootstrap`
- `AuthFlowController`
- `AuthCallbackScreen`

The callback system:

- Listens through Android platform channels when available
- Falls back to `app_links`
- Consumes initial callback URIs if the app launches from a deep link
- Watches live callback URIs while the app is already running
- Detects success, error, and password-recovery callbacks
- Polls and times out if callback completion takes too long

Development and production redirect handling is environment-aware. The accepted redirect scheme list includes the main configured scheme and also accepts `gymunity` and `gymunity-dev` in development.

## 8. Role Model

GymUnity is built around three first-class roles:

- Member
- Coach
- Seller

This role system is persisted in the database through:

- `public.roles`
- `public.profiles.role_id`
- A helper SQL function `public.current_role()`

Role selection determines:

- Which onboarding flow the user sees
- Which dashboard the user reaches after onboarding
- Which tables and actions are available through row-level security

## 9. Route Resolution Logic

Route resolution is centralized in `AuthRouteResolver`.

The app resolves navigation like this:

- No authenticated user: `welcome`
- Authenticated user with no profile role: `role-selection`
- Authenticated user with a role but incomplete onboarding: role-specific onboarding route
- Authenticated user with a role and completed onboarding: role-specific dashboard

### Dashboard mapping

- Member -> `member-home`
- Coach -> `coach-dashboard`
- Seller -> `seller-dashboard`

### Onboarding mapping

- Member -> `member-onboarding`
- Coach -> `coach-onboarding`
- Seller -> `seller-onboarding`

## 10. Onboarding Flows

GymUnity treats onboarding as a real data-writing flow, not only UI.

### Member onboarding

Member onboarding writes to:

- `member_profiles`
- `profiles.onboarding_completed`
- Initial weight history if current weight is provided

Captured member information includes:

- Goal
- Age
- Gender
- Height in centimeters
- Current weight in kilograms
- Training frequency
- Experience level

### Seller onboarding

Seller onboarding writes to:

- `seller_profiles`
- `profiles.onboarding_completed`

Captured seller information includes:

- Store name
- Store description
- Primary category
- Shipping scope
- Optional support email

### Coach onboarding

Coach onboarding is the most composite onboarding flow. It writes:

- `coach_profiles`
- An initial coaching package
- An initial availability slot
- `profiles.onboarding_completed`

This means a coach can be bootstrapped into the system with public-facing service data from the beginning.

## 11. Member Experience

The member role is the most consumer-facing part of the app.

### Member home

The member home is backed by a summary model assembled from multiple sources:

- Latest weight entry
- Latest body measurement entry
- Active or most recent workout plan
- Latest logged workout session
- Latest coach subscription

### Member profile and progress

The backend supports:

- Member profile persistence
- Preferences
- Weight tracking history
- Body measurement tracking history
- Workout plan listing
- Workout session logging
- Subscription listing
- Order listing

### Preferences

Member/user preferences are stored in `user_preferences` and currently include:

- Push notifications enabled
- AI tips enabled
- Order updates enabled
- Measurement unit: metric or imperial
- Language: English or Arabic

### Progress tracking

Progress-related data currently exists in the backend and repository layer through:

- `member_weight_entries`
- `member_body_measurements`
- `workout_sessions`

The dedicated progress UI route still points to a placeholder screen, but the data model and repository support already exist.

### Workout plans and sessions

Members can:

- Retrieve coach-authored or AI-authored workout plans
- Log completed workout sessions
- Link a workout session to a workout plan
- Resolve coach ownership from the plan if needed

Workout plans store structured JSON content, which gives GymUnity flexibility to evolve the exercise model without changing the app contract too aggressively.

## 12. Coach Experience

GymUnity separates coach discovery from coach management.

### Public coach discovery

Members can browse coaches through repository calls that use Supabase RPCs such as:

- `list_coach_directory`
- `get_coach_public_profile`
- `list_coach_public_reviews`

Public coach details include:

- Name
- Bio
- Specialties
- Delivery mode
- Experience
- Pricing
- Verification state
- Rating average and count
- Packages
- Availability
- Reviews

### Coach-managed content

Coaches can manage:

- Their profile
- Coaching packages
- Availability slots
- Dashboard metrics
- Client list
- Workout plans
- Subscription state

### Coach dashboard

The coach dashboard is backed by a repository and summary RPC. It is intended to surface operational coaching metrics rather than static content.

### Coaching packages

Coach packages support:

- Title
- Description
- Billing cycle
- Price
- Active/inactive state

The codebase already includes repository methods for listing, saving, and deactivating packages, even though some dedicated UI routes are still placeholders.

### Availability

Availability is modeled as reusable weekly slots:

- Weekday
- Start time
- End time
- Timezone
- Active state

### Coach subscriptions

Members can request a coach subscription through an RPC-backed workflow. Coaches can update subscription status through another RPC.

This flow is distinct from AI Premium billing. Coach subscriptions are business-domain subscriptions stored in app tables, not App Store / Google Play entitlements.

### Workout plan assignment

A coach can create a workout plan for a member. When this happens:

- A row is inserted into `workout_plans`
- The member receives a notification in `notifications`

This is one of the clearest examples of cross-feature coordination in GymUnity.

### Reviews

Members can submit coach reviews tied to subscriptions, and public review listings are exposed through RPC-backed repository calls.

## 13. Store and Marketplace Experience

GymUnity includes a marketplace for fitness-related products.

### Store browsing

Members can:

- Browse product categories
- Search products
- Open product details
- Favorite products
- Add items to cart
- Review and update cart contents
- Save shipping addresses
- Place orders
- Track their orders

The built-in category model currently includes:

- All
- Supplements
- Equipment
- Apparel
- Accessories

Search works across:

- Product name
- Category
- Description

### Product model

Products support:

- Seller ownership
- Title
- Description
- Category
- Price
- Currency
- Stock quantity
- Low stock threshold
- Image paths and resolved image URLs
- Active state
- Soft-deletion marker

### Favorites

Favorites are stored separately from the product table. The app supports:

- Loading favorite product IDs
- Resolving favorite products in user-defined order
- Toggling favorites on and off

### Cart system

The cart is server-backed, not only local UI state.

GymUnity uses:

- `store_carts`
- `store_cart_items`

The repository ensures that a cart row exists for the current member on demand. Cart contents are enriched with live product data so the UI can reflect:

- Current stock
- Unavailable products
- Over-limit quantities

There is also a cleanup flow that removes unavailable items or clamps quantities to available stock.

### Shipping addresses

The app supports multiple shipping addresses with a default flag. Address fields include:

- Recipient name
- Phone
- Address lines
- City
- State/region
- Postal code
- Country code
- Delivery notes
- Default state

### Checkout and order placement

Checkout is performed through the `create_store_order` SQL function. The Flutter repository calls it with:

- A shipping address ID
- A client-provided idempotency key

The function returns a list of order summaries instead of a single order. This fits GymUnity’s marketplace design, where a single cart can produce one or more seller-specific orders.

### Order detail model

Order data is enriched from:

- `orders`
- `order_items`
- `order_status_history`

That gives each order:

- Summary information
- Line items
- Shipping snapshot
- Status history timeline

## 14. Seller Experience

The seller role is the supply-side counterpart to the store.

### Seller dashboard

The seller dashboard aggregates:

- Total products
- Active products
- Low-stock products
- Pending orders
- In-progress orders
- Delivered orders
- Gross revenue

### Seller product management

Sellers can:

- List their own products
- Create products
- Edit products
- Activate/deactivate products
- Upload product images
- Delete or archive products

### Product image uploads

Seller image uploads are handled through Supabase Storage. Before upload:

- Image bytes are optimized/compressed
- File extension is normalized
- A storage path is generated under seller and product ownership

The uploaded image path is then used to resolve public image URLs.

### Delete versus archive behavior

A seller product is not always deleted outright. If the product is already linked to order history, the app archives it instead of hard-deleting it. This preserves marketplace history while preventing further sale.

### Seller order management

Sellers can:

- Load detailed seller-side orders
- View individual order details
- Update order status through RPC

This is backed by:

- `list_seller_orders_detailed`
- `update_store_order_status`

## 15. AI Chat Experience

GymUnity includes an AI chat feature that stores conversations in the app database.

### Chat model

The AI chat feature uses:

- `chat_sessions`
- `chat_messages`

### Session behavior

Users can:

- Create chat sessions
- List their sessions
- Open a conversation
- Watch messages in real time
- Send a message and receive an assistant response

### Message flow

When a user sends a message:

1. The app inserts the user message into `chat_messages`
2. The app invokes the `ai-chat` edge function
3. The function loads recent chat history from Supabase
4. The function calls OpenAI with a system instruction and message history
5. The assistant reply is returned to the client
6. The client stores the assistant reply in `chat_messages`
7. The chat session’s `updated_at` field is refreshed

The realtime message stream is powered by Supabase query streaming on `chat_messages`.

## 16. AI Premium and Monetization

GymUnity’s AI feature can operate in one of two modes:

- Free/unlocked mode when AI Premium is disabled in config
- Gated mode when AI Premium is enabled and tied to verified billing entitlements

### Feature gating

The gate decision is computed by `aiPremiumGateProvider`, which returns:

- Free access
- Premium unlocked
- Premium locked

### Billing catalog

The app queries store products for AI Premium plans and maps them into an internal catalog. The premium offering currently models:

- Monthly plan
- Annual plan

### Purchase handling

The billing layer supports:

- Product catalog loading
- Purchase initiation
- Restore purchases
- Existing Android purchase queries
- Purchase completion

### Subscription state

The entitlement layer supports:

- Ensuring a billing customer token exists
- Reading current subscription entitlement
- Refreshing entitlement from the backend
- Syncing completed purchases with backend verification functions

### Purchase stream bootstrap

Monetization bootstrap does the following:

- Subscribes to purchase updates
- Refreshes entitlements when the app starts
- Reconciles previous Android purchases
- Refreshes entitlements when auth state changes
- Refreshes entitlements when the app resumes

### Physical marketplace vs digital premium

The marketplace/store domain and AI Premium are separate concerns:

- Store products are ordinary marketplace items inside GymUnity
- AI Premium is a digital subscription verified through platform billing

## 17. Notifications and Settings

GymUnity has both backend-backed notifications and local settings state.

### Notification system

Notifications are stored in `public.notifications` and streamed live to the client.

Each notification has:

- ID
- Title
- Body
- Type
- Read/unread state
- Creation time
- Optional structured `data`

The app currently categorizes notifications as:

- Coaching
- Orders
- AI
- System

Users can:

- View notifications
- Filter them by category
- Mark one as read
- Mark all as read

### Settings state

The settings provider currently stores:

- Push notifications enabled
- AI tips enabled
- Order updates enabled
- Measurement unit
- Language

This is currently implemented as app-side state in the settings presentation layer, while broader persisted preference support exists in the member/user data layer.

### Support and legal

GymUnity includes dedicated routes/screens for:

- Help and support
- Privacy policy
- Terms

These are driven by runtime config such as:

- `SUPPORT_URL`
- `SUPPORT_EMAIL`
- `PRIVACY_POLICY_URL`
- `TERMS_OF_SERVICE_URL`

## 18. Account Deletion Flow

GymUnity supports account deletion through a dedicated edge function and backend soft-delete logic.

### Delete request flow

The `delete-account` edge function:

- Authenticates the requester using the bearer token
- Requires current password confirmation for email-based accounts
- Calls the `soft_delete_account` SQL function
- Removes avatar files from storage

### Backend soft-delete behavior

The `soft_delete_account` function:

- Rewrites the account email to a deleted placeholder address
- Marks the user inactive
- Clears or sanitizes profile fields
- Clears coach profile details
- Deactivates seller products
- Cancels active subscriptions where appropriate
- Archives active workout plans where appropriate
- Deletes notifications
- Deletes device tokens
- Deletes chat sessions

This is a business-level soft deletion with selective cleanup rather than a simple hard delete of the auth user.

## 19. Routing Inventory

The app currently defines routes for the following areas.

### Auth routes

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

### Coach management routes

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

## 20. Current Placeholder and In-Progress Screens

Some routes intentionally point to `FeaturePlaceholderScreen` instead of final UI implementations.

Current placeholder surfaces include:

- Edit Profile
- Progress Tracking screen
- Workout Plans screen
- Workout Details screen
- AI Generated Plan screen
- My Subscriptions screen
- Seller Profile screen
- Coach Clients screen
- Coach Packages screen
- Coach Add Package screen
- Coach Profile screen

This is important because GymUnity already contains backend and repository support for several of these areas even when the dedicated screen is still placeholder-based.

## 21. State Management and Dependency Injection

Riverpod is the backbone of app state and dependency wiring.

Patterns used across the app include:

- `Provider`
- `FutureProvider`
- `StreamProvider`
- `StateProvider`
- `StateNotifierProvider`
- `AsyncNotifierProvider`

The DI layer exposes providers for:

- Supabase client
- Auth callback ingress
- Auth repository
- User repository
- Member repository
- Coach repository
- Seller repository
- Store repository
- Billing repository
- Entitlement repository
- Chat repository
- Current auth session
- Current user profile
- App role
- Auth route resolver

This makes feature screens depend on repository-backed providers rather than manually constructing backend clients in the UI.

## 22. Supabase Database Design

GymUnity uses Supabase as the central system of record.

### Identity and role tables

- `roles`
- `users`
- `profiles`

### Member domain tables

- `member_profiles`
- `user_preferences`
- `member_weight_entries`
- `member_body_measurements`
- `workout_plans`
- `workout_sessions`

### Coach domain tables

- `coach_profiles`
- `coach_packages`
- `coach_availability_slots`
- `subscriptions`
- `coach_reviews`

### Store domain tables

- `products`
- `store_carts`
- `store_cart_items`
- `product_favorites`
- `shipping_addresses`
- `orders`
- `order_items`
- `order_status_history`
- `store_checkout_requests`

### AI and messaging tables

- `chat_sessions`
- `chat_messages`

### Notification tables

- `device_tokens`
- `notifications`

### Billing and entitlement tables

- `billing_products`
- `billing_customers`
- `store_transactions`
- `subscription_entitlements`
- `billing_sync_events`

## 23. Row-Level Security and Access Model

The schema enables row-level security broadly across application tables.

Key design themes:

- Users can read and mutate their own records
- Coaches manage coach-owned data
- Sellers manage seller-owned data
- Members manage member-owned data
- Public discovery is allowed only where explicitly intended, such as coach directory style data
- RPC functions and helper functions are used for multi-step server-side operations

The project relies heavily on the combination of:

- `auth.uid()`
- `profiles.role_id`
- `public.current_role()`
- ownership predicates in RLS policies

## 24. Storage Design

GymUnity uses Supabase Storage buckets with different visibility models.

### `avatars`

- Private bucket
- Owner-oriented access rules
- Used for profile avatars

### `product-images`

- Public bucket
- Used for seller product images

This storage split reflects the different nature of the files:

- Avatars are user account assets
- Product images are marketplace-facing public assets

## 25. Edge Functions

The repository currently includes these edge functions:

- `ai-chat`
- `billing-verify-apple`
- `delete-account`

There are also shared helpers under:

- `_shared/cors.ts`
- `_shared/billing.ts`

### `ai-chat`

Purpose:

- Validate the authenticated user
- Validate session ownership
- Load recent message history
- Call OpenAI
- Return assistant text

Important behavior:

- Uses service-role access server-side
- Checks the session belongs to the caller
- Loads recent conversation history from Supabase
- Uses `OPENAI_MODEL` with default `gpt-4o-mini`

### `billing-verify-apple`

Purpose:

- Accept Apple receipt verification data
- Validate it with Apple
- Resolve plan, lifecycle, and entitlement state
- Upsert billing and entitlement state in GymUnity tables

### `delete-account`

Purpose:

- Validate the authenticated user
- Require current password confirmation for email-provider accounts
- Trigger backend soft deletion
- Remove avatar storage files

## 26. SQL Functions and RPC-Backed Business Logic

GymUnity uses SQL functions and RPCs for operations that are more complex than a direct table insert/update.

Examples visible in the codebase include:

- `current_role`
- `touch_updated_at`
- `seller_dashboard_summary`
- `create_store_order`
- `ensure_billing_customer`
- `soft_delete_account`
- `list_coach_directory`
- `get_coach_public_profile`
- `coach_dashboard_summary`
- `list_coach_clients`
- `request_coach_subscription`
- `update_coach_subscription_status`
- `list_coach_public_reviews`
- `submit_coach_review`
- `list_member_orders_detailed`
- `list_member_subscriptions_detailed`
- `list_seller_orders_detailed`
- `update_store_order_status`

This means GymUnity is not only a table-driven CRUD app. Important business logic is intentionally centralized in the database layer.

## 27. Runtime Configuration and Feature Flags

`AppConfig` is a central runtime contract for the app.

It includes:

- Environment selection: dev, staging, production
- Supabase URL
- Supabase anon key
- Auth redirect scheme and host
- Privacy policy URL
- Terms URL
- Support URL
- Support email
- Support email subject
- Reviewer login help URL
- OpenAI model
- Feature flags
- AI Premium store product identifiers

### Feature flags currently modeled

- `ENABLE_COACH_ROLE`
- `ENABLE_SELLER_ROLE`
- `ENABLE_APPLE_SIGN_IN`
- `ENABLE_STORE_PURCHASES`
- `ENABLE_COACH_SUBSCRIPTIONS`
- `ENABLE_AI_PREMIUM`

### Production config validation

Production builds enforce stricter validation such as:

- Privacy policy URL required
- At least one support contact required

AI Premium also requires all corresponding store product IDs and base plan IDs when enabled.

## 28. Local Development and Operational Workflow

The repository includes scripts to standardize local execution:

- `scripts/flutter_run_dev.ps1`
- `scripts/flutter_build_apk_dev.ps1`
- `scripts/flutter_build_appbundle_dev.ps1`
- `scripts/flutter_test_dev.ps1`
- `scripts/flutter_with_env.ps1`
- `scripts/sync_local_runtime_config.ps1`

Important operational rules in this codebase:

- `.env` is a source input for helper scripts, not a runtime file read directly by Flutter
- Raw `flutter run` does not automatically inject config
- Local runtime config can be synchronized into an asset fallback file
- Supabase Dashboard SQL setup is documented separately

## 29. End-to-End “How the App Works”

### First-time user flow

1. The user opens the app.
2. Splash validates config and backend readiness.
3. The user reaches welcome, registration, or login.
4. After authentication, GymUnity creates/ensures `users` and `profiles` rows.
5. If no role is chosen yet, the user goes to role selection.
6. After role selection, the user enters the matching onboarding flow.
7. Onboarding writes role-specific records and marks onboarding complete.
8. The user is routed to the correct dashboard.

### Returning user flow

1. The user opens the app.
2. Splash restores the session.
3. Bootstrap checks whether the account is deleted or active.
4. The correct role dashboard is resolved automatically.
5. If AI Premium is enabled, monetization bootstrap refreshes entitlement state.

### Member daily flow

Typical member actions can include:

- Viewing fitness summary
- Tracking weight and measurements
- Logging workout sessions
- Browsing coaches
- Requesting a coach subscription
- Browsing the marketplace
- Adding products to favorites or cart
- Placing store orders
- Using AI chat if premium access allows it

### Coach daily flow

Typical coach actions can include:

- Viewing dashboard metrics
- Managing packages and availability
- Reviewing subscriptions
- Creating workout plans
- Viewing public profile data
- Receiving and acting on member demand

### Seller daily flow

Typical seller actions can include:

- Monitoring dashboard metrics
- Publishing and editing products
- Uploading product images
- Reviewing orders
- Updating order statuses

## 30. Current Project Maturity

GymUnity is beyond a blank scaffold. It already has:

- Real route orchestration
- Real role-aware onboarding
- Real Supabase schema and RLS
- Real marketplace cart/order behavior
- Real coach and member repository logic
- Real notifications
- Real account deletion backend logic
- Real AI chat persistence
- Real in-app billing scaffolding for AI Premium

At the same time, some product areas are still maturing:

- Several routes are placeholder-driven
- Some rich coach/member UI surfaces are backed by data but not fully finalized on-screen
- Google billing verification and some production integrations are implied by the architecture but not all visible in the route/UI layer reviewed here

## 31. Short Summary

GymUnity is a multi-role fitness platform that combines:

- Authentication and role onboarding
- Member wellness tracking
- Coach discovery and coaching operations
- Seller marketplace management
- Store ordering
- Real-time notifications
- AI chat
- Premium subscription entitlements

The most important architectural characteristic of this project is that the app is not organized around isolated screens. It is organized around business domains with shared identity, role-aware routing, Supabase-backed persistence, and a growing set of backend-enforced workflows.
