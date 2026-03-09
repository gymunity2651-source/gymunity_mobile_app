# Supabase Phase 1 Setup

This project is now preconfigured to use the `pooelnnveljiikpdrvqw` Supabase project from a local `.env`.

## Local app config

The local `.env` file contains:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `OPENAI_MODEL`

`.env` is ignored by Git so the local project can run without committing credentials.

If the `.env` file changes, regenerate env output:

```powershell
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

## Dashboard work that still must be done

Phase 1 still requires Supabase Dashboard access because the current machine is not linked to the target project.

### 1. Apply the SQL bundle

Open Supabase Dashboard for project `pooelnnveljiikpdrvqw`, then run:

`supabase/sql/phase1_dashboard_setup.sql`

This applies:

- base schema
- roles seed data
- RLS policies
- storage buckets and storage policies
- notifications tables

### 2. Auth settings

In `Authentication -> Providers -> Email`:

- keep Email provider enabled
- keep `Confirm email` enabled

Remote check on March 9, 2026 from this workspace confirmed:

- `email = true`
- `mailer_autoconfirm = false`

Important:
the current mobile flow uses a 6-digit OTP screen for signup verification.
Supabase documents that magic links and OTPs share the same flow, and that sending a code instead of a link requires using the email token in the template instead of the confirmation URL.

For the current app flow, configure the signup confirmation email template to send the OTP code, not only a confirmation link.

### 3. What is intentionally postponed

These are not part of phase 1:

- AI edge-function secrets
- password reset deep links
- OAuth providers
- mobile redirect URLs / intent filters

## Verification checklist

After SQL + Auth settings are done:

1. Launch the app.
2. Register a fresh user.
3. Confirm the email with the 6-digit code.
4. Login and complete role selection.
5. Complete onboarding and verify it persists after app restart.
6. Upload an avatar.
7. As a seller, create a product and upload a product image.
8. Verify product reads work from the store tab.
