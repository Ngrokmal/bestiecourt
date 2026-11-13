import '../entities/profile.dart';

abstract class ProfileRepository {
  Future<Profile> fetchMyProfile();

  Future<int> fetchMyCoinBalance();

  Future<void> updateDisplayName(String displayName);

  Future<List<CoinEntry>> fetchCoinHistory();

  Future<void> updatePreferences({
    required bool nudges,
    required bool slaps,
    required String humor,
  });

  /// Registers this app installation (random, app-scoped id — NOT a hardware id).
  /// Best-effort: failures must never block the user.
  Future<void> registerInstallation();
}
