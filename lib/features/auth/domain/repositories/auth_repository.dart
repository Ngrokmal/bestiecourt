import '../../../../core/errors/failures.dart';
import '../entities/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<Result<bool>> signIn({
    required String email,
    required String password,
  });

  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<Result<bool>> signOut();
}
