# PatternHunt Mobile

Flutter iOS/Android client for PatternHunt.

## Setup

1. Copy env and fill in values from your PatternHunt web deployment:

```bash
cp .env.example .env
```

2. Run with dart defines:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=API_BASE_URL=https://www.patternhunt.co/api/v1
```

## Architecture

- **Auth**: `supabase_flutter` (email signup/login)
- **API**: Dio client → PatternHunt `/api/v1/*` (same backend as web)
- **State**: Riverpod
- **Navigation**: go_router with bottom nav shell + search overlay

## Synced assets

- `assets/constants.json` — synced from web repo
- `assets/design-tokens.json` — synced from web repo

Update these when the web API contract or design tokens change. See `openapi.yaml` in the web repo.

## Store submission

1. **iOS**: Archive with Xcode → Distribute App → TestFlight / App Store Connect.
2. **Android**: `flutter build appbundle` → upload to Play Console (Internal testing track first).
3. Add `com.patternhunt://login-callback` to Supabase Auth redirect URLs (Google OAuth, email signup confirmation, and password reset).
4. Configure signing (iOS team + Android keystore) before release builds.
