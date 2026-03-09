# Google OAuth Setup

GymUnity uses Supabase browser-based OAuth for Google sign-in.

## In App
- Redirect placeholder used everywhere: `gymunity://auth-callback`
- Android custom scheme: `gymunity`
- iOS custom scheme: `gymunity`

The placeholder client IDs in `.env.example` are documentation only:
- `GOOGLE_WEB_CLIENT_ID`
- `GOOGLE_ANDROID_CLIENT_ID`
- `GOOGLE_IOS_CLIENT_ID`

Flutter does not read those values at runtime for browser-based Supabase OAuth.

## Supabase
1. Open `Authentication -> Providers -> Google`
2. Enable Google
3. Insert the Google `Client ID` and `Client Secret`
4. Open `Authentication -> URL Configuration`
5. Add `gymunity://auth-callback` to `Additional Redirect URLs`

## Google Cloud Console
1. Create OAuth credentials for the Google provider used by Supabase
2. Add this authorized redirect URI:
   - `https://pooelnnveljiikpdrvqw.supabase.co/auth/v1/callback`

## Before Production
- Replace Android placeholder application id: `com.example.my_app`
- Replace iOS placeholder bundle id: `com.example.myApp`
- Keep the app scheme and Supabase redirect configuration aligned
