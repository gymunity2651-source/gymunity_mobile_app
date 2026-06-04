# Prompt: Implement Safe Route Restoration and Last App State Navigation

You are working on the Flutter application **GymUnity**.

The current app starts from `AppRoutes.splash` every time because `MaterialApp` uses:

```dart
initialRoute: AppRoutes.splash
```

This is functional, but it does not feel like a professional real-world app. On cold start, the app should not always behave as if the user is opening it for the first time. It should restore the safest meaningful place for the user when possible, while still respecting authentication, role permissions, onboarding state, and security-sensitive flows.

Your task is to implement a robust **Safe Route Restoration** system.

---

## Main Goal

When the user closes the app and opens it again, the app should restore a safe and useful state instead of always sending the user through the full splash-to-dashboard flow.

The app should remember:

1. The last safe route the user visited.
2. The last dashboard route based on the user role.
3. The last selected bottom navigation tab.
4. The last active workout/session/plan/chat only if it is safe and valid to restore.
5. It must never restore sensitive or temporary authentication/payment routes.

---

## Current Behavior to Improve

Currently, `GymUnityApp` uses `MaterialApp` with:

```dart
initialRoute: AppRoutes.splash,
onGenerateRoute: AppRoutes.onGenerateRoute,
```

This means the app starts at the splash screen on every cold start, then resolves the user route through the bootstrap flow.

Keep the existing bootstrap logic, but enhance it so that authenticated users can be redirected to a saved safe destination when appropriate.

Do not remove the existing `SplashScreen`, `AppBootstrapController`, or `AuthRouteResolver`. Improve the behavior around them.

---

## Required Implementation

### 1. Create a Persistent App Navigation State Store

Create a new service/class, for example:

```dart
class AppNavigationStateStore {
  Future<void> saveLastSafeRoute(String routeName, {Map<String, dynamic>? params});
  Future<SavedRouteState?> readLastSafeRoute();
  Future<void> clearLastSafeRoute();

  Future<void> saveLastDashboardRoute(String routeName);
  Future<String?> readLastDashboardRoute();

  Future<void> saveLastTabIndex(String area, int index);
  Future<int?> readLastTabIndex(String area);
}
```

Use a local persistence package that fits the current project architecture.

Recommended options:

- `shared_preferences` for simple non-sensitive UI state.
- `flutter_secure_storage` only if any saved value is sensitive.
- Do not store access tokens manually unless absolutely necessary.

For this feature, prefer `shared_preferences` because route names, tab indexes, and non-sensitive entity IDs are UI state, not secrets.

Add the dependency if missing:

```yaml
dependencies:
  shared_preferences: latest_stable_version
```

Use the latest compatible stable version.

---

### 2. Define Safe and Unsafe Routes

Create a route policy layer, for example:

```dart
class RoutePersistencePolicy {
  static bool isPersistable(String routeName) { ... }
  static bool isSensitive(String routeName) { ... }
  static bool requiresAuthentication(String routeName) { ... }
  static bool requiresRole(String routeName, AppRole role) { ... }
}
```

The following routes must never be persisted as last safe route:

```dart
AppRoutes.splash
AppRoutes.welcome
AppRoutes.login
AppRoutes.register
AppRoutes.forgotPassword
AppRoutes.resetPassword
AppRoutes.otp
AppRoutes.authCallback
```

Also never persist:

- Payment callback routes.
- Password reset routes.
- OTP/verification screens.
- Error-only screens.
- Temporary loading screens.
- Any route that depends on one-time arguments.
- Any route that could expose another user's data after logout/login switch.

Routes that can be persisted:

- Member dashboard/home.
- Coach dashboard.
- Seller dashboard.
- Store home/catalog.
- Nutrition home.
- Workout plan screen, only if the plan ID still belongs to the current user.
- AI chat home.
- AI conversation screen, only if the chat session still belongs to the current user.
- Active workout session, only if there is an unfinished active session for the same user.

---

### 3. Save Route Changes Centrally

Do not manually save routes inside every screen.

Add a `NavigatorObserver` that watches route changes and saves only persistable routes.

Example:

```dart
class AppRouteObserver extends NavigatorObserver {
  AppRouteObserver(this.store);

  final AppNavigationStateStore store;

  @override
  void didPush(Route route, Route? previousRoute) {
    _persist(route);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (newRoute != null) _persist(newRoute);
  }

  void _persist(Route route) {
    final name = route.settings.name;
    if (name == null) return;
    if (!RoutePersistencePolicy.isPersistable(name)) return;
    store.saveLastSafeRoute(name);
  }
}
```

Register it in `MaterialApp`:

```dart
navigatorObservers: [appRouteObserver],
```

Make sure the observer is provided through Riverpod or dependency injection in a clean way.

---

### 4. Enhance AuthRouteResolver

Update `AuthRouteResolver.resolveInitialRoute()` so it can choose between:

1. Welcome route for unauthenticated users.
2. Role selection if authenticated but no profile/role.
3. Onboarding if onboarding is incomplete.
4. Last safe route if valid.
5. Role dashboard fallback.

Expected logic:

```dart
Future<String> resolveInitialRoute() async {
  final currentUser = await _userRepository.getCurrentUser();
  if (currentUser == null) {
    await _navigationStateStore.clearLastSafeRoute();
    return AppRoutes.welcome;
  }

  final profile = await _userRepository.getProfile();
  final requiredRoute = _resolveByProfile(profile);

  if (profile == null || profile.role == null) {
    return AppRoutes.roleSelection;
  }

  if (!profile.onboardingCompleted) {
    return routeForRoleOnboarding(profile.role!);
  }

  final savedRoute = await _navigationStateStore.readLastSafeRoute();

  if (savedRoute != null && await _canRestore(savedRoute, profile)) {
    return savedRoute.routeName;
  }

  return routeForRoleDashboard(profile.role!);
}
```

Do not restore the last route blindly. Always validate it against:

- Current authentication status.
- Current user ID.
- Current role.
- Onboarding completion.
- Entity ownership if the route requires an ID.
- Feature flags if the feature can be disabled.

---

### 5. Store User-Scoped Route State

Saved route state must be scoped to the current user ID.

Example saved object:

```json
{
  "userId": "current-user-id",
  "routeName": "/workout-plan",
  "params": {
    "planId": "abc123"
  },
  "savedAt": "2026-06-04T12:00:00.000Z"
}
```

When restoring, if the saved `userId` does not match the current authenticated user ID, clear the saved state and do not restore it.

This prevents user A from logging out, user B logging in, and user B being redirected to user A's previous route.

---

### 6. Add Expiration Rules

Saved route state should expire.

Use a sensible TTL, for example:

- Last dashboard route: no strict expiration.
- Last tab index: no strict expiration.
- Last safe route: 7 days.
- Active workout/session: only if still active and not completed.
- Checkout/payment-related state: never restore automatically.

If the saved route is expired, clear it and fallback to the role dashboard.

---

### 7. Restore Arguments Safely

Some routes require arguments, for example:

- `WorkoutPlanScreen(planId: ...)`
- `WorkoutDayDetailsScreen(planId: ..., dayId: ...)`
- `AiConversationScreen(sessionId: ...)`
- `ProductDetailsScreen(product: ...)`

Do not persist full objects like `ProductEntity`, `CoachEntity`, or full chat objects.

Persist only stable IDs:

```json
{
  "routeName": "/ai-conversation",
  "params": {
    "sessionId": "session-id"
  }
}
```

Before restoring, re-fetch the entity from the backend and verify it exists and belongs to the current user.

If validation fails, fallback to the nearest safe parent route:

- Invalid workout day → workout plan.
- Invalid workout plan → member home.
- Invalid AI session → AI chat home.
- Invalid product → store home.
- Invalid coach workspace entity → coach dashboard.

---

### 8. Add Last Tab Persistence

For each main app area, persist the selected tab index.

Examples:

```dart
saveLastTabIndex('member_home', selectedIndex);
saveLastTabIndex('coach_dashboard', selectedIndex);
saveLastTabIndex('seller_dashboard', selectedIndex);
```

On screen initialization, read the saved index and apply it if it is within the valid tab range.

If invalid, fallback to index `0`.

Do not store tab index globally only, because member/coach/seller dashboards may have different tab structures.

---

### 9. Splash Behavior

Keep the splash screen as the bootstrap entry point, but make it smarter.

The splash should:

1. Load config.
2. Initialize Supabase.
3. Resolve current auth state.
4. Resolve profile/role/onboarding.
5. Check saved route state.
6. Navigate to the best safe destination.

The splash should not feel like a full restart every time.

If bootstrapping is fast, keep the splash minimal.
If there is a slow network call, show a clear loading state.
If bootstrapping fails, show retry.

Do not navigate to saved routes before auth/profile validation completes.

---

### 10. Logout Behavior

When logout succeeds, clear all route restoration state for that user.

Required behavior:

```dart
await authRepository.logout();
await appNavigationStateStore.clearLastSafeRoute();
await appNavigationStateStore.clearUserScopedState();
```

Then navigate with stack clearing:

```dart
Navigator.pushNamedAndRemoveUntil(
  context,
  AppRoutes.welcome,
  (route) => false,
);
```

Never allow the user to press back after logout and return to an authenticated screen.

---

### 11. App Lifecycle Handling

When the app goes to background, persist the latest known safe state.

Use Flutter lifecycle APIs such as `AppLifecycleListener` or the existing `WidgetsBindingObserver`.

On pause/inactive:

- Save current safe route.
- Save active tab.
- Save active workout ID if applicable.
- Save unsent drafts if applicable.

On resume:

- Refresh session/profile.
- Refresh feature flags if needed.
- Validate whether the current screen is still allowed.
- If session expired, clear state and redirect to login/welcome.

---

## Acceptance Criteria

The implementation is complete only if all of the following are true:

### Authenticated User

- If a member closes the app on member home tab 2, reopening the app returns to member home tab 2.
- If a coach closes the app on coach dashboard, reopening returns to coach dashboard.
- If a seller closes the app on seller dashboard, reopening returns to seller dashboard.
- If the user closes the app on a safe AI chat session, reopening restores that session only if it still belongs to the same user.
- If the user closes the app on an active workout, reopening offers to continue or restores it only if still active.

### Unauthenticated User

- If the user is logged out, opening the app goes to welcome/login.
- No old authenticated route appears after logout.
- Pressing Android back after logout must not return to a protected screen.

### Sensitive Routes

- OTP screen is never restored.
- Reset password screen is never restored.
- Auth callback screen is never restored.
- Payment callback screen is never restored.
- Checkout state is not restored automatically unless explicitly designed and validated.

### User Switch Safety

- If user A logs out and user B logs in, user B must never see user A's saved route, chat, workout, product, or profile state.

### Invalid Saved Route

- If the saved route no longer exists, fallback to the user's role dashboard.
- If the saved entity was deleted, fallback to the nearest safe parent route.
- If the feature is disabled, fallback to dashboard.

---

## Testing Requirements

Add tests for:

1. Unauthenticated start → welcome.
2. Authenticated member with no saved route → member home.
3. Authenticated coach with no saved route → coach dashboard.
4. Authenticated seller with no saved route → seller dashboard.
5. Authenticated user with valid saved route → saved route.
6. Authenticated user with unsafe saved route → dashboard fallback.
7. Expired saved route → dashboard fallback.
8. Saved route for different user → clear and fallback.
9. Logout clears saved route and prevents back navigation.
10. Last tab index restores correctly.

Use unit tests for `AuthRouteResolver`, `RoutePersistencePolicy`, and `AppNavigationStateStore`.
Use widget/navigation tests for logout stack clearing and route restoration behavior.

---

## Important Constraints

- Do not remove the existing Supabase initialization flow.
- Do not bypass `AuthRouteResolver`.
- Do not restore routes before validating auth/profile/role/onboarding.
- Do not store sensitive pages as last route.
- Do not store full domain objects in local persistence.
- Do not introduce duplicate navigation decisions across many screens.
- Keep route restoration centralized and testable.
- Make the solution compatible with the current Riverpod-based architecture.

---

## Expected Final Result

After this change, GymUnity should feel like a real production app:

- It opens to the right place.
- It does not expose sensitive screens.
- It respects auth and role permissions.
- It remembers useful UI state.
- It handles logout safely.
- It avoids sending the user through unnecessary splash/navigation jumps every time.
