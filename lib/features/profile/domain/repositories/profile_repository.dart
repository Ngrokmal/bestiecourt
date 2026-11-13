import '../entities/profile.dart';

abstract class ProfileRepository {
  Future<Profile> fetchMyProfile();

  Future<int> fetchMyCoinBalance();

  Future<void> updateDisplayName(String displayName);

  /// Registers this app installation (random, app-scoped id — NOT a hardware id).
  /// Best-effort: failures must never block the user.
  Future<void> registerInstallation();
}
