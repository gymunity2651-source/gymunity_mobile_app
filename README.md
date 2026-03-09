# GymUnity

GymUnity is a Flutter fitness platform for members, coaches, and sellers, backed by Supabase.

## Local setup

1. Install Flutter dependencies:

```powershell
flutter pub get
```

2. Ensure the local `.env` file exists at the project root.

3. Regenerate env output after changing `.env`:

```powershell
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

4. Run the app:

```powershell
flutter run
```

## Supabase setup

Phase 1 setup instructions live in:

- `docs/supabase_phase1_setup.md`

The SQL bundle for Dashboard SQL Editor lives in:

- `supabase/sql/phase1_dashboard_setup.sql`
