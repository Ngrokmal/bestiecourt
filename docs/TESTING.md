# Testing — what is actually verified

Last verified: **2026-11-13** (GitHub Actions run `43372914640`, branch `main`).

| Check | Where | Result |
|---|---|---|
| Flutter toolchain (3.24.5) + Java 17 | CI `build-apk` | ✅ pass |
| `flutter pub get` (dependency resolution) | CI `build-apk` | ✅ pass |
| `flutter analyze --no-fatal-infos` | CI `build-apk` | ✅ pass — 0 errors, 0 warnings (9 info-level style hints: `prefer_const_*`, one deprecation notice for `anonKey`) |
| `flutter test` — 3 unit test files | CI `build-apk` | ✅ pass |
| `flutter build apk --release` | CI `build-apk` | ✅ pass — artifact **`roast-my-bestie-apk`** (~56 MB, 7-day retention) |
| Migrations applied to real PostgreSQL 16 | CI `sql-check` | ✅ pass (`supabase/migrations/*.sql`) |
| Seed catalogue applied | CI `sql-check` | ✅ pass (`supabase/seed.sql`) |
| RLS + RPC smoke test as `authenticated` role | CI `sql-check` | ✅ pass — “SQL SMOKE TEST PASSED” |
| `dart format` gate | CI (report-only) | ⚠️ informational only — see note below |
| Two-device end-to-end play | real phones | ❌ **NOT RUN** — owner action (see checklist) |
| pgTAP / policy unit tests, widget tests | — | ❌ not written yet |

### What the SQL smoke test proves (`tool/sql_smoke_test.sql`)

It runs the real RPCs as the least-privileged `authenticated` role, then
verifies as the owner:

* auth trigger creates profile + wallet + 20-coin signup bonus,
* self-friend-request rejected; internal `fn_resolve_match` **not** callable by clients,
* invite-code lookup works and does not expose secrets,
* friend request → accept → `are_friends` true,
* match creation picks the server-side daily question (fails loudly if the seed is missing),
* `rpc_join_match` opens a 10-minute voting window,
* **opponent's vote and winner stay hidden until resolution**,
* duplicate vote → `ALREADY_VOTED`,
* both votes → server resolves (2-0 → Nadia), winner win-count +1,
* rewards are **exactly once** (idempotent `fn_resolve_match`, single ledger row),
* loser gets a punishment offer; skipping charges 15 coins once (30 → 15),
* stranger gets `NOT_PARTICIPANT`, RLS hides other wallets/profiles,
* direct `insert into coin_transactions` → permission denied,
* insufficient coins → `INSUFFICIENT_COINS`, balance unchanged, no negative balance,
* a match nobody votes in resolves by timeout as a tie with **no** punishment.

### Note on formatting

The AI workspace has no Dart SDK, so `dart format --set-exit-if-changed` runs
report-only (it does not block the build). Run once locally:

```bash
dart format lib test
```

### Manual two-device QA checklist (still required)

1. Sign up / sign in / sign out / relaunch (session restores).
2. Wrong password shows a Bengali error (no raw backend text).
3. Invite code: invalid, self, duplicate, happy path.
4. Accept / reject a request; both lists update after pull-to-refresh.
5. Create match → opponent sees it under “চলমান ম্যাচ” → joins.
6. Vote on both phones → result appears on both within ~1s (Realtime).
7. Double-tap vote → “আপনি ইতিমধ্যে ভোট দিয়েছেন” (server rejection).
8. Kill the app mid-vote, reopen → state restored from the server.
9. Leave one phone on the vote screen 10+ min → resolves by timeout.
10. Lose → punishment card → complete / skip (coins −15).
11. Skip with too few coins → “পর্যাপ্ত কয়েন নেই”.
12. Airplane mode → error + retry state (no infinite spinner).

## Feature-pack coverage (migration `20261113000200_feature_packs.sql`)

`tool/sql_smoke_test.sql` now has 20 sections. Sections 1–10 are the original
daily-roast flows; 11–20 cover the feature pack:

| § | What it proves |
|---|---|
| 11 | Secret accusation: the target *cannot* read the body before guessing, guessing twice is rejected, body is revealed after the guess |
| 12 | Bestie Court: file → respond → both votes → server decides `guilty` (client never sets the verdict) |
| 13 | Friendship Contract: starts `pending`, only becomes `active` after the second signature |
| 14 | Confessions: invisible to a friend until `rpc_share_confession` runs |
| 15 | Social pings: per-day rate limit + `nudges` preference → `RECIPIENT_MUTED` |
| 16 | Inbox unread count / mark-all-read, title catalogue, friends leaderboard, weekly awards |
| 17 | Revenge round linked to the original match |
| 18 | Punishment reroll allowed only once (and not on an already-skipped row) |
| 19 | Block removes the friendship and stops new pair interactions |
| 20 | Reports are stored; no negative coin balance exists |

`test/unit/feature_domain_test.dart` checks the client-side state machines that
gate those screens (bluff guessing, court voting, contract signing, ping
helpers, unread badge, title flags).

Still manual (needs two phones): animations, Realtime feel, share cards, and the
Bengali copy review.
