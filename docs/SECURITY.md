# Security model

## Trust boundaries

* The Flutter APK is **public software**: anything inside it can be extracted.
  Only the publishable/anon Supabase key is present, and
  `AppConfig.assertClientKeySafety()` throws if a `service_role`/`sb_secret_`
  key is ever injected.
* The client is **untrusted input**. Every trusted rule runs in PostgreSQL
  `SECURITY DEFINER` functions that re-derive `auth.uid()`.

## What the client cannot do

| Action | Enforced by |
|---|---|
| Read someone else's profile/confession data | RLS `profiles_select` (self or accepted friend) |
| Vote twice, vote after deadline, vote for a non-participant | `rpc_submit_vote` (row lock + unique constraint + deadline check) |
| See the opponent's vote early | `rpc_get_match` only returns it when `state = 'completed'` |
| Pick the winner | `fn_resolve_match` computes it from stored votes |
| Edit coin balance / ledger | no INSERT/UPDATE grants on `coin_wallets`, `coin_transactions` |
| Force a cheap skip price | price read from `punishments.coin_cost` server-side |
| Call internal helpers directly | `EXECUTE` revoked from `public/anon/authenticated` |
| Read risk/installation internals | `abuse_risk_events` has no grants; `user_installations` exposes 5 safe columns only |

## Idempotency & concurrency

* `match_votes_one_per_player`, `match_results` PK, `coin_transactions`
  `unique (user_id, idempotency_key)`.
* `SELECT ... FOR UPDATE` in `rpc_submit_vote`, `rpc_join_match`,
  `rpc_set_punishment_status`, `fn_resolve_match` serialises concurrent calls.
* Resolution is a no-op on a second call → no double rewards.

## Rate limits (server side, not client side)

* friend requests: 10 / minute, matches: 5 / 10 minutes,
  invite lookups: 20 / minute, installations: 10 / day per user.

## Privacy

* No raw IP addresses, no MAC address, no IMEI/serial, no contacts, no location.
* Installation id = random UUID stored in app-private `SharedPreferences`
  (app-scoped, resets on reinstall). Treated as a weak signal only.
* Nothing sensitive (votes before reveal, confession text) is ever placed in a
  push payload, log line, or analytics event.

## Reporting

If a secret is ever committed: rotate it in the dashboard first, then rewrite
history. Do not paste it into chat or a new commit.
