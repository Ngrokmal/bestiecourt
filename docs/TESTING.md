# Testing

## What runs today

| Check | Where | Status |
|---|---|---|
| `dart format --set-exit-if-changed` | GitHub Actions (report-only) | runs |
| `flutter analyze --no-fatal-infos` | GitHub Actions | blocking |
| `flutter test` (unit) | GitHub Actions | blocking |
| `flutter build apk --release` | GitHub Actions | blocking |
| SQL migration validation | needs a Supabase project | **NOT RUN** — no local Postgres/psql in the dev sandbox |
| Instrumented/device tests | needs two Android devices | **NOT RUN** — owner action |

`dart format` is report-only because the AI workspace has no Dart SDK; the owner
should run `dart format lib test` locally once and commit the result.

## Unit coverage today (`test/unit`)

* `MatchState.fromCode` for every state + unknown input (no UI crash).
* `isOpen` classification.
* `CursorPageRequest` clamps (default 20, max 50, min 1).
* `BattleView` vote rules: no double vote, no vote when closed, opponent name
  resolution from viewer perspective.

## Manual QA checklist (two devices)

1. Sign up / sign in / sign out / relaunch (session restores).
2. Wrong password shows a Bengali error (no raw backend text).
3. Invite code: invalid, self, duplicate, happy path.
4. Accept/reject request; both lists update after pull-to-refresh.
5. Create match → opponent sees it under “চলমান ম্যাচ” → joins.
6. Vote on both phones → result appears on both within ~1s (Realtime).
7. Double-tap vote → server rejects with “আপনি ইতিমধ্যে ভোট দিয়েছেন” message.
8. Kill the app mid-vote, reopen → state is restored from the server.
9. Leave one phone on the vote screen 10+ minutes → match resolves by timeout.
10. Lose a match → punishment card → complete / skip (coins decrease by 15).
11. Skip twice → “পর্যাপ্ত কয়েন নেই”.
12. Check coin balance is read-only (no client write path exists).
13. Airplane mode → error + retry state (no infinite spinner).

## Known gaps

* No widget/integration tests yet (needs a mocked Supabase client).
* RLS is verified by review, not by automated policy tests; a `pgTAP` suite is
  the next step once a test project exists.
