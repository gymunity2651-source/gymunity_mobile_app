# GymUnity

GymUnity is a Flutter fitness platform for members, coaches, and sellers, backed by Supabase.

## Local setup

1. Install Flutter dependencies:

```powershell
flutter pub get
```

2. Ensure the local `.env` file exists at the project root.

3. Run the app through the local config helper:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\flutter_run_dev.ps1 -DeviceId emulator-5554
```

4. Build local Android artifacts through the same config path when needed:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\flutter_build_apk_dev.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\flutter_build_appbundle_dev.ps1
```

Important:

- GymUnity reads runtime config from `--dart-define`, not directly from `.env`.
- Raw `flutter run` does not read `.env` automatically.
- Local helper commands are documented in `docs/local_config_standardization.md`.

## Supabase setup

Phase 1 setup instructions live in:

- `docs/supabase_phase1_setup.md`

The SQL bundle for Dashboard SQL Editor lives in:

- `supabase/sql/phase1_dashboard_setup.sql`
