# Setup

## 1. Supabase (owner action — no secrets in chat)

1. Open your Supabase project → **SQL Editor**.
2. Paste and run `supabase/migrations/20261113000100_init.sql`.
3. Paste and run `supabase/seed.sql` (question bank + punishment catalogue).
4. **Authentication → Providers → Email**: turn *Confirm email* **off** for the
   fastest MVP testing (or keep it on and click the verification link).
5. **Authentication → URL configuration**: not needed for the mobile MVP.
6. Copy `Project URL` and the **publishable / anon** key. They are already the
   compile-time defaults in `lib/core/config/app_config.dart`.

> Never put the `service_role` / secret key in this app, in git, or in CI. The
> client only needs the publishable key; RLS does the enforcement.

## 2. Configure the client (optional override)

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
```

## 3. Build the APK (GitHub Actions only)

Push to `main` (or run `Android APK` workflow manually). The workflow:

1. installs Flutter 3.24.5 + Java 17,
2. copies `gradlew`/`gradle-wrapper.jar` from the Flutter template
   (they are git-ignored binary blobs — no downloads into the repo),
3. runs `dart format --set-exit-if-changed` (report-only), `flutter analyze`,
   `flutter test`,
4. builds `app-release.apk` and uploads it as the artifact
   `roast-my-bestie-apk` (7-day retention).

Download the APK from the Actions run page on your phone and install it
(“Install from unknown sources”). No `service_role` key, keystore or password is
stored in the repository.

## 4. Firebase / FCM (later, optional)

Push is intentionally **off** (`AppConfig.fcmEnabled == false`). When you have a
real Firebase project: add `google-services.json` locally (it is git-ignored),
apply the Google Services Gradle plugin, then enable the flag. Until then no
code pretends that push works.

## 5. Two-device test

1. Install the APK on two phones (or one phone + one emulator).
2. Sign up twice with different emails.
3. Phone A → **প্রোফাইল** → copy invite code → share to phone B.
4. Phone B → **বন্ধু** → paste code → send request.
5. Phone A → **বন্ধু** → accept.
6. Phone A → **হোম** → “বন্ধুকে চ্যালেঞ্জ করুন” → pick friend.
7. Phone B → **হোম** → tap the open match → “ম্যাচে যোগ দিন”.
8. Both vote → server resolves → result + punishment appears on both phones.
