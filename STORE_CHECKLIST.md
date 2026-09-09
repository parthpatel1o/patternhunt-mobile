# Pattern Hunt — App Store & Play Store checklist

Remaining work only. Code blockers already fixed in-repo are omitted.

| Item | Value |
|------|--------|
| Version | `1.0.0+1` |
| iOS bundle ID | `com.patternhunt.patternhuntMobile` |
| Android application ID | `com.patternhunt.patternhunt_mobile` |
| Display name | `Pattern Hunt` |
| Support email | `patternhunt@outlook.com` |
| Deep link | `com.patternhunt://login-callback` |

---

## 0. Accounts & decisions

- [ ] **Apple Developer Program** enrolled ($99/year) — [developer.apple.com](https://developer.apple.com)
- [ ] **Google Play Console** enrolled ($25 one-time) — [play.google.com/console](https://play.google.com/console)
- [ ] Confirm whether bundle/application IDs stay as-is (changing later = new listing)
- [ ] Marketing / support website URL for store listings

---

## 1. Deploy & signing (still blocking uploads)

- [ ] **Deploy Pattern Hunt web** so these are live:
  - `https://www.patternhunt.co/privacy`
  - `https://www.patternhunt.co/terms`
  - `DELETE /api/v1/me` (account deletion)
- [ ] **Create Android upload keystore** + fill `android/key.properties` (see README; never commit secrets)
- [ ] Set Xcode `DEVELOPMENT_TEAM` / Apple signing for your Apple ID
- [ ] Confirm Google Sign-In / OAuth on both platforms with the deep link
- [ ] Confirm email confirmation + password reset deep links with `com.patternhunt://login-callback`

### Production env / builds

- [ ] Production `SUPABASE_URL` and `SUPABASE_ANON_KEY` ready
- [ ] Production `API_BASE_URL=https://www.patternhunt.co/api/v1` (never localhost in store builds)
- [ ] Supabase Auth redirect URLs include `com.patternhunt://login-callback`
- [ ] Google Cloud OAuth clients configured for iOS + Android + Web
- [ ] Decide how release builds get dart-defines (CI, `--dart-define-from-file`, or Xcode scheme)

```bash
# Android App Bundle
flutter build appbundle \
  --dart-define=SUPABASE_URL=https://YOUR.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=API_BASE_URL=https://www.patternhunt.co/api/v1

# iOS IPA (after Xcode signing is set)
flutter build ipa \
  --dart-define=SUPABASE_URL=https://YOUR.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=API_BASE_URL=https://www.patternhunt.co/api/v1
```

---

## 2. Branding & store listing assets

- [ ] Play feature graphic (1024×500)
- [ ] Screenshots on real devices (or simulators at required sizes)
- [ ] Short description / subtitle
- [ ] Full description
- [ ] Keywords (Apple) / tags (Play where applicable)
- [ ] Category (e.g. Lifestyle / Shopping / Crafts)
- [ ] Age rating questionnaire answers prepared (UGC photos, social features, etc.)

### Screenshot plan

1. Hunt / browse patterns  
2. Pattern detail  
3. Auth (email + Google)  
4. Submit pattern (photos)  
5. Saved / boards  
6. Settings / profile  

**Apple**

- [ ] 6.7" iPhone screenshots
- [ ] 6.5" and/or 5.5" if App Store Connect still asks
- [ ] iPad screenshots if you keep iPad support enabled

**Google Play**

- [ ] Phone screenshots (at least 2; 4–8 recommended)
- [ ] 7" and/or 10" tablet screenshots if you declare tablet support
- [ ] Optional promo video

### Copy

- [ ] App name: **Pattern Hunt** (≤ 30 characters)
- [ ] Subtitle ≤ 30 characters (Apple)
- [ ] Short description ≤ 80 characters (Play)
- [ ] Full description: what Pattern Hunt is, who it’s for, browse / vote / save / submit
- [ ] No placeholder or “coming soon” for features that aren’t live
- [ ] UGC moderation story ready for review notes

---

## 3. Legal & store privacy forms

- [ ] Confirm privacy/terms pages look right after deploy (contact: `patternhunt@outlook.com`)
- [ ] App Store Connect **Privacy Nutrition Labels** filled to match reality
- [ ] Play Console **Data safety** form filled to match reality
- [ ] If Google Fonts loads at runtime, disclose that network use (or bundle fonts offline)
- [ ] Support URL + marketing URL set (`patternhunt@outlook.com` as support email)
- [ ] Copyright / trader / developer name correct (individual vs company)

---

## 4. Apple App Store

### Accounts & identifiers

- [ ] Create App ID / confirm bundle ID in Apple Developer → Identifiers
- [ ] Create the app record in [App Store Connect](https://appstoreconnect.apple.com)
- [ ] Distribution cert + App Store provisioning (or Xcode Automatic Signing)
- [ ] Bump build number for every upload (`pubspec.yaml` `+N`)

### Compliance

- [ ] Google OAuth tested on a physical iPhone
- [ ] Photo library / camera prompts show correct usage strings
- [ ] Export compliance answered
- [ ] UGC / content rights notes if you have a report/moderation path
- [ ] Confirm guideline 4.8 (Sign in with Apple) against your email + Google auth UI

### Build & TestFlight

- [ ] Archive release build with **production** dart-defines
- [ ] Upload via Xcode Organizer or `flutter build ipa` + Transporter
- [ ] Wait until build is processed in App Store Connect
- [ ] Internal TestFlight smoke test:
  - [ ] Cold start
  - [ ] Email signup / login / logout
  - [ ] Google OAuth round-trip
  - [ ] Hunt feed loads
  - [ ] Save / unsave
  - [ ] Submit pattern with library photo
  - [ ] Edit pattern
  - [ ] Password reset email deep link
  - [ ] Account deletion
  - [ ] Privacy / Terms links
- [ ] External TestFlight (optional but recommended)

### Listing & submit

- [ ] Screenshots + description + support URL + privacy URL
- [ ] Age rating
- [ ] App Review contact + demo account in Review Notes
- [ ] Review Notes: OAuth deep link, how to find submit/delete
- [ ] Submit for Review
- [ ] After approval: manual or automatic release

---

## 5. Google Play

### Signing & package

- [ ] **Create upload keystore** and back it up offline
- [ ] Enable **Play App Signing**
- [ ] Confirm `applicationId` matches the Play app
- [ ] Target recent API level (verify current Play requirement before upload)

### Console setup

- [ ] Create application
- [ ] Store listing
- [ ] Data safety
- [ ] Content rating (IARC)
- [ ] Target audience / other declarations as prompted
- [ ] Ads: **No** (unless you add ads later)
- [ ] App access / demo credentials if login is required
- [ ] Privacy policy URL
- [ ] Categories / tags
- [ ] Countries / pricing

### Testing → production

- [ ] Upload AAB to **Internal testing**
- [ ] Testers install from Play link + smoke QA
- [ ] Promote to **Closed testing** (recommended), then **Open** (optional)
- [ ] Complete production “ready for review” items
- [ ] Production release notes
- [ ] Optional staged rollout 20% → 50% → 100%
- [ ] Monitor ANRs/crashes after launch

---

## 6. Pre-upload QA matrix

Run on at least one physical iPhone and one physical Android phone.

| Area | Pass? | Notes |
|------|-------|-------|
| Install fresh / first launch | [ ] | |
| Offline / bad network messaging | [ ] | |
| Email signup + confirm | [ ] | |
| Email login | [ ] | |
| Google OAuth | [ ] | |
| Password reset | [ ] | |
| Hunt swipe / browse | [ ] | |
| Search | [ ] | |
| Save / boards | [ ] | |
| Submit with gallery photo | [ ] | |
| Crop / reorder photos | [ ] | |
| PDF/file attach (if offered) | [ ] | |
| Insights (designer) | [ ] | |
| Settings save | [ ] | |
| Log out | [ ] | |
| Delete account | [ ] | |
| Privacy/terms links open | [ ] | |
| Deep link cold-start | [ ] | |
| Deep link warm-start | [ ] | |
| No localhost / staging URLs in build | [ ] | |
| Version & build number incremented | [ ] | |

---

## 7. Launch order

1. Deploy web (privacy, terms, `DELETE /me`)
2. Create Android keystore + Apple signing team
3. Configure Supabase + Google OAuth for production
4. Build signed artifacts with production dart-defines
5. TestFlight + Play Internal testing
6. Fix tester / crash issues
7. Finish store listings + privacy/data forms
8. Submit Apple + Play review
9. Soft-launch → monitor auth, uploads, crash-free sessions
10. Announce

---

## 8. After you’re live

- [ ] Crash monitoring (Crashlytics, Sentry, or store consoles)
- [ ] Every store upload increments build number (`+N`)
- [ ] Update privacy / data-safety forms when you add new data types
- [ ] Keystore + Apple cert backup in a password manager
- [ ] Release notes template for future updates
- [ ] Refresh screenshots when UI changes materially

---

## Ready-to-upload gate

1. Privacy + terms URLs live after web deploy  
2. Account deletion works against production `DELETE /me`  
3. Android upload keystore configured (`key.properties`)  
4. Production dart-defines baked into the binary  
5. OAuth deep link works on both platforms  
6. Screenshots + listing copy done  
7. TestFlight / Internal testing smoke QA passed  
