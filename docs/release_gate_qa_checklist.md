# GymUnity Android Release Gate QA Checklist

Use this checklist before treating an Android build as release-ready. Run all
commands from the repository root and use staging/test credentials only.

## Automated Gates

- Static analysis: `flutter analyze`
- Flutter tests: `powershell -ExecutionPolicy Bypass -File .\scripts\flutter_test_dev.ps1 --reporter expanded`
- Edge Function tests: `deno test --allow-env --allow-net` from `supabase/functions`
- Android APK: `powershell -ExecutionPolicy Bypass -File .\scripts\flutter_build_apk_dev.ps1`
- Android App Bundle: `powershell -ExecutionPolicy Bypass -File .\scripts\flutter_build_appbundle_dev.ps1`

The Flutter gate must pass with zero failures. Intentional skips must explain
their enabling dart-define or environment requirement in the test output.

## Environment Rules

- Use Android emulator first.
- Use `.env` through the helper scripts; raw `flutter run` does not load app
  runtime config.
- Use test/staging Supabase, OpenAI, and Paymob credentials.
- Use Paymob test mode only.
- Do not run destructive account deletion, payment callback, or admin payout
  checks against production data.
- Deno must be installed locally or provided by CI before the backend gate can
  be considered complete.

## Role Walkthroughs

- Guest/Auth: splash, welcome, Google login launch, OAuth callback success,
  callback error, role selection, and back navigation.
- Member onboarding: required fields, partial input blocking, successful
  completion, failed save staying on screen, and return to member home.
- Member home: bottom tabs, profile shortcut, edit profile, progress, settings,
  notifications, help, privacy, terms, and logout.
- TAIYO/Planner: AI home, general chat send, planner builder questions,
  generated plan review, activation, workout plan, workout day details, active
  workout session, reminders, loading and retry states.
- Coaching marketplace: coaches list, coach details, packages, paid checkout
  request, subscription list, coach hub, kickoff, habits, resources, sessions,
  checkins, messages, and visibility settings.
- Coach workspace: dashboard, client pipeline, client workspace, consent-gated
  insights, check-in review, calendar, billing, packages, package editor,
  program library, onboarding resources, profile, inactive clients, and payment
  state changes.
- Seller workspace: seller dashboard, product list, add/edit product, orders,
  profile, logout, and seller copilot live smoke.
- Store/news/nutrition: store catalog, product details, add to cart, checkout
  preview, orders, favorites, news feed, news details, save/dismiss, nutrition
  setup, home, meal plan, preferences, insights, hydration, and quick add.
- Admin: access denied for non-admin, dashboard for admin/super-admin, payment
  filters, raw payload visibility, payout review, callback/sync status smoke.

## Failure Scenarios

- Empty repository data renders useful empty states with a clear action.
- Network, Supabase, Edge Function, AI, and Paymob failures show a user-facing
  error and allow retry where retry is logical.
- Malformed route arguments render explicit feature placeholders rather than
  `Unknown Route`.
- Expired or missing sessions return to auth/role flow without stuck loaders.
- Duplicate taps on submit/payment/send buttons do not create duplicate
  mutations.
- Small Android viewport has no critical overflow or inaccessible primary
  action.
- English and Arabic locale selection do not break navigation, layout, or
  persistence.

## Live Smoke Evidence

Record the following for each release candidate:

- Emulator/device id and Android API level.
- Supabase project ref and environment name, never secrets.
- Paymob mode and test transaction identifiers.
- Edge Function test command result.
- APK/App Bundle command result.
- Screenshots or notes for the role walkthroughs above.
- Any skipped item, with owner and follow-up issue.
