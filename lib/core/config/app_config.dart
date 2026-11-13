/// Centralized, immutable configuration for Roast My Bestie.
///
/// SECURITY BOUNDARY:
/// Only public/publishable client keys are allowed here. Row Level Security (RLS)
/// enforces access control on every exposed PostgreSQL table and Storage bucket.
///
/// Values are resolved in this order:
///   1. `--dart-define=SUPABASE_URL=...` (CI/local override)
///   2. The compile-time default below (public client credentials only)
class AppConfig {
  const AppConfig._();

  static const String appName = 'Roast My Bestie';
  static const String androidPackageId = 'com.bestiecourt.app';
  static const String appVersion = '1.0.0';

  /// Public Supabase URL (can be overridden via --dart-define=SUPABASE_URL=...)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://filrqvmfujnewoxstrgp.supabase.co',
  );

  /// Public/Publishable Supabase Client Key (safe for client use with RLS enabled).
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_bXwhEY6Roffym_1q6z6qSw_nTprGTew',
  );

  /// Feature flag: Firebase Cloud Messaging stays OFF until the owner adds a
  /// real google-services.json. The app must build and run without it.
  static const bool fcmEnabled = bool.fromEnvironment(
    'ENABLE_FCM',
    defaultValue: false,
  );

  /// Supabase Storage Buckets
  static const String avatarsBucket = 'avatars';
  static const String verdictCardsBucket = 'verdict_cards';

  /// Pagination & Retry clamps (server clamps these again; never trusted).
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;
  static const Duration networkTimeout = Duration(seconds: 15);
  static const int maxRetryAttempts = 3;

  /// Match rules mirrored from the server (display only — server is authority).
  static const Duration votingWindow = Duration(minutes: 10);

  static bool get isBackendConfigured =>
      supabaseUrl.trim().isNotEmpty &&
      supabasePublishableKey.trim().isNotEmpty;

  /// Validates that no privileged service_role secret was accidentally injected.
  static void assertClientKeySafety() {
    final String lower = supabasePublishableKey.toLowerCase();
    if (lower.contains('service_role') || lower.startsWith('sb_secret_')) {
      throw StateError(
        'SECURITY VIOLATION: A privileged service_role/secret key must NEVER '
        'be embedded in the Flutter client application.',
      );
    }
  }
}
