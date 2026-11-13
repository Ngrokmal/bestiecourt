# Roast My Bestie 😂 (`com.bestiecourt.app`)

Funny, consent-based multiplayer game for two friends, built with **Flutter
(Material 3)** + **Supabase (Auth, PostgreSQL, RLS, Realtime)** following
feature-first **Clean Architecture**. Rive is not used. MongoDB and ads are not
part of the MVP.

## Status (honest)

MVP vertical slice implemented: auth, friends, Daily Roast Battle with
server-resolved votes, coin ledger, safe punishments, match history.

Verified on 2026-11-13 (GitHub Actions): `flutter analyze` clean,
`flutter test` pass, **release APK builds**, and the SQL migrations + seed +
RLS/business-rule smoke test all pass on PostgreSQL 16.

Not yet verified: real two-device play (owner action), widget/pgTAP tests,
`dart format` (runs report-only). Details: `docs/TESTING.md`.

**Download the APK:** GitHub → Actions → latest green *Android APK* run →
Artifacts → `roast-my-bestie-apk`.

## Features

Core games: daily roast battle (hidden votes, server result), secret accusation,
truth-or-lie bluff, bestie court (complaint → defence → votes → verdict),
punishment wheel with paid skip, revenge round.

Social extras: friendship contracts (both must sign, 30-day expiry), private
confessions box with explicit one-friend sharing, silent-treatment /
ghosting-reminder nudges, virtual tomato & slipper wall, block & report.

Rewards: friendship coins + immutable ledger, title catalogue + active title,
weekly friends leaderboard, weekly awards, shareable verdict/award text,
notification inbox with unread badge, and a preferences screen (humour level,
nudges, slaps).

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
