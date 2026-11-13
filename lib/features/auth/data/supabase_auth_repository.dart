import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/errors/failures.dart';
import '../domain/entities/app_user.dart';
import '../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  AppUser? get currentUser => _map(_client.auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() {
    return _client.auth.onAuthStateChange
        .map((AuthState state) => _map(state.session?.user));
  }

  @override
  Future<Result<bool>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return const Success<bool>(true);
    } on Object catch (error) {
      return FailureResult<bool>(mapErrorToFailure(error));
    }
  }

  @override
  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final AuthResponse response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: <String, dynamic>{'display_name': displayName.trim()},
      );
      if (response.session == null) {
        return const Success<SignUpOutcome>(
          SignUpOutcome.emailConfirmationRequired,
        );
      }
      return const Success<SignUpOutcome>(SignUpOutcome.signedIn);
    } on Object catch (error) {
      return FailureResult<SignUpOutcome>(mapErrorToFailure(error));
    }
  }

  @override
  Future<Result<bool>> signOut() async {
    try {
      await _client.auth.signOut();
      return const Success<bool>(true);
    } on Object catch (error) {
      return FailureResult<bool>(mapErrorToFailure(error));
    }
  }

  AppUser? _map(User? user) {
    if (user == null) {
      return null;
    }
    return AppUser(id: user.id, email: user.email);
  }
}
