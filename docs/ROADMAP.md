# Roadmap

## MVP (in progress)

- [x] Clean Architecture foundation + design tokens + router
- [x] Supabase auth (email/password) with real error states
- [x] Friends: invite code, request, accept/reject, remove
- [x] Daily Roast Battle: create → join → hidden votes → server resolution
- [x] Coin ledger + harmless punishment catalogue + skip cost
- [x] History with keyset pagination
- [x] RLS + server-authoritative RPCs
- [x] GitHub Actions APK pipeline
- [ ] Verified end-to-end on two real devices (owner action)
- [ ] `pgTAP` RLS tests, widget tests

## Next feature packs (one at a time, each with migration + RLS + tests)

1. Bestie Court + shareable verdict card
2. Secret Accusation
3. Truth or Lie
4. Titles / weekly awards & friends-only leaderboard
5. Silent Treatment War, Virtual Slap Wall, Confessions box (privacy-first)
6. FCM push (needs a real Firebase project, `AppConfig.fcmEnabled`)
7. Share cards (share_plus is already wired for the invite code)

## Explicitly out of scope for now

* MongoDB, AdMob/monetization, Rive, contact upload, cross-app “ghosting
  detection”, any leaderboard that shames a real person.
