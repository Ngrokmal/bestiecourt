import 'package:equatable/equatable.dart';

/// Pure-Dart authenticated identity. No Supabase SDK types leak into Domain.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.email,
  });

  final String id;
  final String? email;

  @override
  List<Object?> get props => <Object?>[id, email];
}

/// Result of a sign-up attempt.
enum SignUpOutcome {
  /// Session is active immediately.
  signedIn,

  /// Project requires email confirmation before a session exists.
  emailConfirmationRequired,
}
