# Roast My Bestie 😂 (`com.bestiecourt.app`)

Funny, consent-based multiplayer game for two friends, built with **Flutter
(Material 3)** + **Supabase (Auth, PostgreSQL, RLS, Realtime)** following
feature-first **Clean Architecture**. Rive is not used. MongoDB and ads are not
part of the MVP.

## Status (honest)

MVP vertical slice implemented in source: auth, friends, Daily Roast Battle
with server-resolved votes, coin ledger, safe punishments, match history.
The APK is produced **only** by GitHub Actions. Device QA is pending — see
`docs/TESTING.md` for what has and has not been run.

## Quick start

```bash
flutter pub get
flutter analyze
flutter test
```

Configuration → `docs/SETUP.md` · Architecture → `docs/ARCHITECTURE.md` ·
Security/RLS → `docs/SECURITY.md` · Testing → `docs/TESTING.md` ·
Roadmap → `docs/ROADMAP.md`

## Repository map

```
lib/
  app/            app widget, router, theme + design tokens
  core/           config, errors/failure mapping, pagination, DI, widgets
  features/
    auth/ friends/ profile/ home/ history/ roast_battle/ shell/
android/          hand-maintained Gradle/manifest (no local builds)
supabase/
  migrations/     schema + RLS + server-authoritative RPCs
  seed.sql        safe question/punishment catalogue
test/unit/        pure-Dart domain tests
.github/workflows/android-apk.yml   the only APK build path
docs/             architecture, setup, security, testing, roadmap
```

## Non-negotiables

* No `service_role`/secret key in the client, repo or CI.
* RLS on every exposed table; trusted rules in `SECURITY DEFINER` functions.
* No fake online status, fake notifications, fake results or fake multiplayer.
* Virtual coins only — no real-money value.
