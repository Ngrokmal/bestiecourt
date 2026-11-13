/// Centralized, immutable configuration for Roast My Bestie.
///
/// SECURITY BOUNDARY:
/// Only public/publishable client keys are allowed here. Row Level Security (RLS)
/// enforces access control on every exposed PostgreSQL table and Storage bucket.
class AppConfig {
  const AppConfig._();

  static const String appName = 'Roast My Bestie';
  static const String androidPackageId = 'com.bestiecourt.app';

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

  /// Supabase Storage Buckets
  static const String avatarsBucket = 'avatars';
  static const String verdictCardsBucket = 'verdict_cards';
  static const String stickersBucket = 'stickers';

  /// Pagination & Rate-Limit Clamps (Part 24)
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;
  static const Duration networkTimeout = Duration(seconds: 15);
  static const int maxRetryAttempts = 3;

  /// Validates that no privileged service_role secret was accidentally injected.
  static void assertClientKeySafety() {
    final lower = supabasePublishableKey.toLowerCase();
    if (lower.contains('service_role') || lower.startsWith('sb_secret_')) {
      throw StateError(
        'SECURITY VIOLATION: A privileged service_role/secret key must NEVER '
        'be embedded in the Flutter client application.',
      );
    }
  }
}
