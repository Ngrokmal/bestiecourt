# Architecture

Feature-first **Clean Architecture**. Dependency direction is enforced by imports:

```
Presentation  ->  Domain
Data          ->  Domain (implements contracts)
core/di       ->  wires concrete implementations (composition root)
Domain        ->  nothing (pure Dart, no Flutter/Supabase imports)
```

## Layers

| Layer | Location | Responsibility |
|---|---|---|
| Presentation | `lib/features/*/presentation` | Screens/widgets, Riverpod consumption, formatting |
| Domain | `lib/features/*/domain` | Entities, repository contracts, business rules |
| Data | `lib/features/*/data` | Supabase RPC/query calls, DTO mapping, error mapping |
| Core | `lib/core` | Config, failures, pagination, DI, shared widgets |
| App | `lib/app` | App widget, router, theme/design tokens |

## Rules actually enforced

* Domain files import only `equatable`/Dart core. No `supabase_flutter`, no
  `flutter/*` widget imports.
* Widgets never call Supabase directly; they call a repository via Riverpod.
* Every repository method returns either a typed entity / `Result<T>` or throws
  an `AppFailure` — raw `PostgrestException` never reaches the UI
  (`lib/core/errors/failure_mapper.dart`).
* Trusted business rules (results, coins, punishments, match state) live in
  PostgreSQL `SECURITY DEFINER` functions. The client only *requests* them.

## State management / DI

Riverpod 2 (`flutter_riverpod`). All providers live in `lib/core/di/providers.dart`
plus one feature-local provider (`battleStreamProvider`). Fakes can replace the
repository providers in tests.

## Backend boundary

Supabase is an implementation detail behind `*Repository` interfaces. Server
endpoints are RPC functions in `supabase/migrations`, not raw table writes, so
RLS bypasses are impossible from the client.

## Where does a new feature go?

```
lib/features/<feature>/
  domain/entities/, domain/repositories/
  data/<feature>_repository_impl.dart
  presentation/<screen>.dart
supabase/migrations/YYYYMMDDHHMMSS_<name>.sql
```
Then register the repository in `lib/core/di/providers.dart`.

## Match state machine

```
waiting --(invited player joins)--> voting --(both votes | deadline)--> completed
   \--(24h, nobody joined)--> expired
```
`completed` is terminal and idempotent: `fn_resolve_match` returns early on a
second call, and every reward uses a unique `idempotency_key`.
