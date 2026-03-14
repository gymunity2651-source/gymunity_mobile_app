# Security Best Practices Report

## Executive Summary

This review covered the full GymUnity repo, with priority on the highest-risk trust boundaries visible in code: Supabase edge functions, SQL/RLS/storage, billing entitlement flows, mobile auth callback handling, and runtime configuration.

No confirmed critical issue was found in the checked-in code, but the repo contains 3 high-severity, 4 medium-severity, and 3 low-severity findings. The most urgent issues are:

1. Account deletion relies on client-side reauthentication and does not enforce a fresh-auth proof on the server.
2. The `ai-chat` edge function does not enforce AI Premium entitlement or abuse controls server-side, so client-side paywall checks can be bypassed.
3. The Apple receipt verifier does not fail closed on unallowlisted SKUs and still lets the client influence the entitlement offering code.

Closest available skill references were the general JavaScript server/frontend security guides. Flutter- and Supabase-specific recommendations below are inferred from repo evidence because the named skill did not include first-party references for those stacks.

## Review Notes

- Evidence source: checked-in repo code only.
- Not visible here: Supabase Dashboard settings, edge gateway rate limits, store-console settings, CI release guardrails, or any out-of-band database default privilege changes.
- Client code references `billing-verify-google` and `billing-refresh-entitlement`, but no corresponding implementations are present under `supabase/functions`, so Android billing verification and entitlement refresh could not be audited from this repo.

## Observed Strengths

- `.env` is ignored by Git, and no service-role or OpenAI keys are hard-coded in the repo.
- Many data tables have RLS enabled and ownership checks are present throughout the SQL migrations.
- `SECURITY DEFINER` functions set `search_path = public`, which is a good baseline hardening step.
- The mobile auth callback flow validates scheme and host before processing callback URIs.

## Critical

No confirmed critical findings in checked-in code.

## High

### 1. GYM-SBP-001

- Severity: High
- Location: `supabase/functions/delete-account/index.ts:50-60`, `lib/features/auth/data/repositories/auth_repository_impl.dart:230-246`
- Rule: Secure-by-default destructive actions must be enforced on the server, not only in the client.
- Evidence:

```ts
const payload = (await req.json().catch(() => ({}))) as DeleteAccountPayload;
const provider =
  authData.user.app_metadata?.provider ??
  authData.user.identities?.[0]?.provider ??
  "email";

if (provider === "email" && !payload.current_password?.trim()) {
  return jsonResponse(
    { error: "Current password confirmation is required." },
    400,
  );
}
```

```dart
if (provider == AuthProviderType.emailPassword) {
  final email = currentUser.email?.trim() ?? '';
  final password = currentPassword?.trim() ?? '';
  if (email.isEmpty || password.isEmpty) {
    throw const AuthFailure(
      message: 'Enter your current password to delete this account.',
    );
  }
  await _remoteDataSource.reauthenticateWithPassword(
    email: email,
    password: password,
  );
}

final response = await _remoteDataSource.invokeDeleteAccount(
  currentPassword: currentPassword,
);
```

- Impact: Anyone with a live session or stolen bearer token can call the edge function directly and pass any non-empty `current_password`, causing the account to be deleted without proving recent knowledge of the password on the server.
- Fix: Enforce a fresh-auth requirement inside the edge function itself. Accept only a server-verifiable reauthentication proof or re-run a recent-auth check server-side immediately before invoking `soft_delete_account`.
- Mitigation: Keep the current client UX, but treat it as convenience only. Log deletion attempts and revoke all sessions after successful deletion.
- False positive notes: If Supabase injects a fresh-auth claim or a recent-auth timestamp into JWTs and the function validates it elsewhere, that logic is not visible in this repo.

### 2. GYM-SBP-002

- Severity: High
- Location: `supabase/functions/ai-chat/index.ts:63-132`, `lib/features/ai_chat/presentation/screens/ai_chat_home_screen.dart:58-65`, `lib/features/ai_chat/presentation/screens/ai_conversation_screen.dart:87-92`, `lib/features/monetization/presentation/providers/monetization_providers.dart:254-269`
- Rule: Premium access, quotas, and costly side effects must be enforced on the server.
- Evidence:

```ts
const payload = (await req.json()) as ChatPayload;
const sessionId = payload.session_id;
const userMessage = payload.message?.trim();

if (!sessionId || !userMessage) {
  return new Response(
    JSON.stringify({ error: "session_id and message are required" }),
```

```ts
const openAiResponse = await fetch(
  "https://api.openai.com/v1/chat/completions",
  {
    method: "POST",
```

```dart
if (gate.requiresBilling && !gate.hasAccess) {
  return AiPremiumPaywallScreen(
    showBackButton: false,
    lockReason: gate.message,
  );
}
return const _AiChatHomeUnlocked();
```

- Impact: Any authenticated user who owns a `chat_session` can bypass the Flutter paywall and invoke `ai-chat` directly, consuming OpenAI credits and accessing premium functionality without a verified entitlement. The function also has no visible per-user rate limit or message-size cap.
- Fix: Enforce entitlement checks inside `ai-chat` against `subscription_entitlements` before making the LLM call. Add server-side usage throttling, input-size limits, and ideally a usage ledger before calling OpenAI.
- Mitigation: Add edge gateway rate limits and alerting even after server-side entitlement checks land.
- False positive notes: External gateway quotas or per-function rate limits may exist, but no such controls are visible in this repo.

### 3. GYM-SBP-003

- Severity: High
- Location: `supabase/functions/billing-verify-apple/index.ts:51-76`, `supabase/functions/billing-verify-apple/index.ts:186-198`, `supabase/functions/_shared/billing.ts:124-176`
- Rule: Store verification must derive entitlements from server-side allowlists, not client-supplied fields.
- Evidence:

```ts
const productId = payload.product_id?.trim() ?? "";
const transaction = selectLatestTransaction(response, productId);
if (!transaction) {
  return jsonResponse(
    { error: "Apple receipt does not contain the requested product." },
    400,
  );
}

const planCode = resolveApplePlanCode(transaction.product_id);
const lifecycleState = resolveLifecycleState(transaction, pendingRenewal);
```

```ts
if (productId && productId === annualId) {
  return "annual";
}
if (productId && productId === monthlyId) {
  return "monthly";
}
return null;
```

```ts
const summary = await upsertBillingState({
  supabase,
  userId: user.id,
  offeringCode: payload.offering_code ?? "ai_premium",
  planCode,
  platform: "ios",
  productId: transaction.product_id,
```

- Impact: The Apple verifier accepts a valid receipt row even when `resolveApplePlanCode(...)` returns `null`, and it still honors a client-provided `offering_code`. That means entitlement mapping does not fail closed on unknown SKUs and can drift or become exploitable as soon as the app adds more Apple products.
- Fix: Ignore client-provided `offering_code` and derive the offering/plan exclusively from a server-side allowlist of approved Apple product IDs. Reject unknown SKUs before calling `upsertBillingState`.
- Mitigation: Bind receipt verification to the server-generated billing customer token or other store-supported account binding metadata where available.
- False positive notes: If the app will never ship any non-AI Apple IAPs, the exploit surface is smaller, but the implementation is still not secure by default.

## Medium

### 4. GYM-SBP-004

- Severity: Medium
- Location: `supabase/migrations/20260312_000008_monetization_billing.sql:126-136`, `lib/features/monetization/data/repositories/entitlement_repository_impl.dart:47-58`, `lib/features/monetization/data/repositories/entitlement_repository_impl.dart:191-197`
- Rule: Client-facing reads should not expose raw verification artifacts unless strictly required.
- Evidence:

```sql
create policy subscription_entitlements_read_own
on public.subscription_entitlements for select
to authenticated
using (user_id = auth.uid());
```

```dart
final row = await _client
    .from('subscription_entitlements')
    .select(
      'offering_code,entitlement_code,entitlement_status,lifecycle_state,'
      'plan_code,source_platform,store_product_id,store_base_plan_id,'
      'latest_transaction_id,latest_purchase_token,access_expires_at,'
```

```dart
latestTransactionId: row['latest_transaction_id'] as String?,
latestPurchaseToken: row['latest_purchase_token'] as String?,
expiresAt: _parseDate(row['access_expires_at']),
```

- Impact: The mobile app reads `latest_purchase_token` from a client-queryable table, which expands the leakage/replay surface for store verification data and violates least privilege.
- Fix: Remove purchase tokens and similar verification artifacts from client-readable tables or client queries. Keep them in a service-role-only table or expose a redacted view for user-facing entitlement status.
- Mitigation: Redact store verification artifacts from logs, crash reports, and analytics.
- False positive notes: Users can still obtain local receipt data from their devices, but mirroring those values back through your backend is unnecessary exposure.

### 5. GYM-SBP-005

- Severity: Medium
- Location: `supabase/migrations/20260307_000002_storage.sql:52-88`, `lib/features/seller/data/repositories/seller_repository_impl.dart:204-223`, `lib/features/seller/data/repositories/seller_repository_impl.dart:490-502`
- Rule: Public object storage should enforce content restrictions server-side, not only in app code.
- Evidence:

```sql
insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', false),
  ('product-images', 'product-images', true)
```

```sql
create policy product_images_insert_own
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'product-images'
  and split_part(name, '/', 1) = auth.uid()::text
);
```

```dart
await _client.storage
    .from('product-images')
    .uploadBinary(
      path,
      compressedBytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: _contentTypeForExtension(normalizedExtension),
      ),
    );
```

- Impact: The public bucket and insert policy only enforce namespace ownership. A seller can bypass the Flutter client and upload unexpected or oversized public content directly via the storage API, using your Supabase CDN origin as a public file host.
- Fix: Enforce MIME, extension, and size rules outside the client, ideally with signed/server-mediated uploads or a validation hook before public exposure.
- Mitigation: Keep monitoring on public bucket growth and reject or quarantine suspicious objects.
- False positive notes: External storage quotas may reduce cost impact, but they do not replace allowlisting.

### 6. GYM-SBP-006

- Severity: Medium
- Location: `supabase/migrations/20260312_000006_core_role_flows.sql:1426-1439`, contrasted with `supabase/migrations/20260312_000005_account_deletion.sql:96-98`, `supabase/migrations/20260312_000007_store_orders_hardening.sql:734-739`, `supabase/migrations/20260312_000008_monetization_billing.sql:187-188`
- Rule: `SECURITY DEFINER` functions should revoke default execute rights explicitly before granting the minimum intended role.
- Evidence:

```sql
grant execute on function public.get_coach_public_profile(uuid) to authenticated;
grant execute on function public.list_coach_public_packages(uuid) to authenticated;
grant execute on function public.list_coach_public_reviews(uuid) to authenticated;
grant execute on function public.list_member_subscriptions_detailed() to authenticated;
grant execute on function public.list_member_orders_detailed() to authenticated;
grant execute on function public.list_seller_orders_detailed() to authenticated;
grant execute on function public.list_coach_clients() to authenticated;
grant execute on function public.seller_dashboard_summary() to authenticated;
grant execute on function public.coach_dashboard_summary() to authenticated;
grant execute on function public.create_store_order(jsonb, jsonb) to authenticated;
grant execute on function public.update_store_order_status(uuid, text, text) to authenticated;
grant execute on function public.request_coach_subscription(uuid, text) to authenticated;
grant execute on function public.update_coach_subscription_status(uuid, text, text) to authenticated;
grant execute on function public.submit_coach_review(uuid, uuid, smallint, text) to authenticated;
```

```sql
revoke all on function public.soft_delete_account(uuid, text) from public;
revoke all on function public.soft_delete_account(uuid, text) from anon;
revoke all on function public.soft_delete_account(uuid, text) from authenticated;
```

- Impact: These RPCs rely on internal `auth.uid()` and role checks, but many do not explicitly revoke default function execute permissions. That broadens the callable surface and makes any future authorization bug more dangerous.
- Fix: Add explicit `revoke all on function ... from public; revoke all ... from anon;` for every exposed `SECURITY DEFINER` function, then grant only the intended role.
- Mitigation: Keep the internal auth/role checks even after grants are tightened.
- False positive notes: If database default privileges have already been hardened out-of-band, verify that before treating this as exploitable today.

### 7. GYM-SBP-007

- Severity: Medium
- Location: `lib/main.dart:9-15`, `lib/core/config/local_runtime_config_loader.dart:10-48`, `pubspec.yaml:39-41`, `scripts/sync_local_runtime_config.ps1:1-85`
- Rule: Production builds should fail closed on missing runtime configuration instead of loading bundled local fallback assets.
- Evidence:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalRuntimeConfigLoader.primeIfNeeded();
  if (AppConfig.current.validationErrorMessage == null) {
    await SupabaseInitializer.initialize();
  }
  runApp(const ProviderScope(child: GymUnityApp()));
}
```

```dart
static const String _assetPath = 'assets/config/local_env.json';

static Future<void> primeIfNeeded() async {
  if (AppConfig.current.validationErrorMessage == null) {
    return;
  }
```

```yaml
flutter:
  uses-material-design: true

  assets:
    - assets/images/
    - assets/config/
```

- Impact: The app can recover from missing compile-time configuration by loading a bundled asset generated from `.env`. That broadens the configuration source of truth and increases the chance of packaging stale or local environment values into release artifacts.
- Fix: Restrict `LocalRuntimeConfigLoader` to debug/profile builds only, or move local config outside bundled assets and fail closed in release mode.
- Mitigation: Add CI checks to ensure `assets/config/local_env.json` is absent or ignored for release builds.
- False positive notes: If all release artifacts come only from clean CI and never from local machines, the practical risk is lower.

## Low

### 8. GYM-SBP-008

- Severity: Low
- Location: `android/app/src/main/AndroidManifest.xml:3-9`
- Rule: Mobile builds should explicitly harden backup behavior for apps that may cache tokens or profile data.
- Evidence:

```xml
<application
    android:label="my_app"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher">
```

- Impact: `android:allowBackup` and data-extraction rules are not set here, so Android backup behavior is left to platform defaults and merged manifest behavior. That can expose locally persisted app data through device/cloud backup paths.
- Fix: Set `android:allowBackup="false"` or define explicit backup/data extraction rules that exclude sensitive app storage.
- Mitigation: Minimize locally stored auth/session material and avoid persisting sensitive caches unnecessarily.
- False positive notes: This is partly inferred from Android defaults. Verify the merged release manifest and actual persisted Supabase session storage before treating it as exploitable.

### 9. GYM-SBP-009

- Severity: Low
- Location: `lib/core/services/external_link_service.dart:8-19`, `lib/core/config/app_config.dart:308-323`, `lib/core/config/app_config.dart:450-453`
- Rule: Config-driven external links should allowlist schemes explicitly.
- Evidence:

```dart
static Future<bool> openUrl(String rawUrl) async {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) {
    return false;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return false;
  }

  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
```

```dart
if (supportUrl.trim().isNotEmpty && !_isValidUrl(supportUrl)) {
  errors.add('SUPPORT_URL must be a valid absolute URL.');
}
```

```dart
static bool _isValidUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && uri.hasScheme && uri.host.isNotEmpty;
}
```

- Impact: Misconfigured support/legal URLs can use `http` or unexpected custom schemes because the validation only checks for an absolute URL, not an approved scheme.
- Fix: Allowlist `https` for support/legal links and keep `mailto:` handling isolated to the dedicated mail helper.
- Mitigation: Add release-time config linting that rejects unsafe schemes.
- False positive notes: If all production config is centrally controlled and immutable, this is primarily a hardening recommendation.

### 10. GYM-SBP-010

- Severity: Low
- Location: `supabase/functions/ai-chat/index.ts:136-145`, `supabase/functions/ai-chat/index.ts:168-177`, `supabase/functions/delete-account/index.ts:82-86`, `supabase/functions/billing-verify-apple/index.ts:109-113`
- Rule: User-facing error responses should not expose raw upstream or internal exception details.
- Evidence:

```ts
if (!openAiResponse.ok) {
  const errorBody = await openAiResponse.text();
  return new Response(
    JSON.stringify({
      error: "LLM request failed",
      details: errorBody,
    }),
```

```ts
return new Response(
  JSON.stringify({
    error: "Unhandled ai-chat function error",
    details: String(error),
  }),
```

```ts
return jsonResponse(
  { error: error instanceof Error ? error.message : "Unknown error" },
  500,
);
```

- Impact: Clients receive raw upstream failure bodies and exception strings, which helps reconnaissance and can leak operational detail that should stay server-side.
- Fix: Return stable, user-safe error codes/messages and log detailed failure context only on the server.
- Mitigation: Add request IDs or trace IDs so support can correlate generic client errors with backend logs.
- False positive notes: None.

## Remediation Queue

### Immediate Fixes

1. Enforce fresh-auth or recent-auth proof server-side in `delete-account`.
2. Add server-side entitlement verification, rate limiting, and input-size caps to `ai-chat`.
3. Make Apple billing verification fail closed on unknown SKUs and derive offering/plan only from server-side allowlists.
4. Remove purchase tokens from client-facing entitlement reads.
5. Tighten public upload controls for `product-images`.

### Defense-in-Depth

1. Add explicit `PUBLIC` and `anon` revokes for every exposed `SECURITY DEFINER` function.
2. Restrict local runtime config fallback to non-release builds.
3. Explicitly harden Android backup behavior.
4. Allowlist schemes for config-driven external links.
5. Replace raw edge-function error details with generic responses plus server-side logging.

## External Verification Notes

- Verify Supabase Dashboard auth settings, redirect URL configuration, and any edge gateway rate limits or WAF rules.
- Verify store-console account-binding settings and whether Apple `appAccountToken` / Google obfuscated account identifiers are enforced outside this repo.
- Verify database default privileges if this project has custom post-deploy privilege hardening not represented in migrations.
