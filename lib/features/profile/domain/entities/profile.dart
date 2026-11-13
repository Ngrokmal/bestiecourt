import 'package:equatable/equatable.dart';

class Profile extends Equatable {
  const Profile({
    required this.id,
    required this.displayName,
    required this.inviteCode,
    required this.wins,
    this.activeTitleCode,
  });

  final String id;
  final String displayName;
  final String inviteCode;
  final int wins;
  final String? activeTitleCode;

  @override
  List<Object?> get props =>
      <Object?>[id, displayName, inviteCode, wins, activeTitleCode];
}
