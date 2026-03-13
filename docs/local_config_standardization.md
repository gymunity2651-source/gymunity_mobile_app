# GymUnity Local Config Standardization

GymUnity does not read `.env` directly at runtime.

The app reads configuration only from compile-time `--dart-define` values through `String.fromEnvironment(...)` in `AppConfig`.

## Local source of truth

Use `.env` at the project root for local development values:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `OPENAI_MODEL` (optional)
- any other `AppConfig` keys supported by the helper scripts

`.env` is a developer input file only. It is not a runtime API.

## Commands of record

Use the helper scripts in `scripts/` instead of raw `flutter run` for local development.

### Run on an emulator or device

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\flutter_run_dev.ps1 -DeviceId emulator-5554
```

### Build a local APK

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\flutter_build_apk_dev.ps1
```

### Build a local app bundle

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\flutter_build_appbundle_dev.ps1
```

### Run tests with the same config path

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\flutter_test_dev.ps1
```

## Why raw `flutter run` is not enough

This repo keeps runtime config aligned across debug, CI, and release builds.

That means this command:

```powershell
flutter run
```

does not automatically read `.env`, so GymUnity will show the in-app configuration error state when required values are not passed as `--dart-define`.

## Behavior when config is missing

If required values are missing:

- the helper script fails early in the terminal with a clear error
- the app shows the configuration-required splash state instead of crashing if someone still launches it without valid defines
