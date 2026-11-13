# Roast My Bestie 😂 (`com.bestiecourt.app`)

Funny, consent-based, harmless multiplayer social game for friends — built with **Flutter (Material 3 + Lottie)**, **Supabase (Auth, PostgreSQL, Realtime, Edge Functions, Storage)**, and **Firebase Cloud Messaging (FCM)** following strict **Feature-First Clean Architecture**.

## Security & Architecture Rules
- **Clean Architecture Dependency Rule:** `Presentation -> Domain <- Data`. Domain is 100% pure Dart.
- **Public Key Only in Client:** Only `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` are used in the Flutter client. Privileged `service_role` keys are strictly prohibited in client code and exist only in Supabase Edge Function secrets.
- **Row Level Security (RLS):** Every exposed PostgreSQL table and Storage bucket enforces strict RLS policies.
- **No Local Heavy Artifacts:** APK builds run exclusively via **GitHub Actions**.
- **Keyset Pagination:** All feeds enforce bounded limits (`default: 20`, `max: 50`) using deterministic `(created_at, id)` cursors.
