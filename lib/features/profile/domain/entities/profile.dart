import 'package:equatable/equatable.dart';

class Profile extends Equatable {
  const Profile({
    required this.id,
    required this.displayName,
    required this.inviteCode,
    required this.wins,
    this.activeTitleCode,
    this.nudgesEnabled = true,
    this.slapsEnabled = true,
    this.humor = 'playful',
  });

  final String id;
  final String displayName;
  final String inviteCode;
  final int wins;
  final String? activeTitleCode;
  final bool nudgesEnabled;
  final bool slapsEnabled;
  final String humor;

  @override
  List<Object?> get props =>
      <Object?>[
        id,
        displayName,
        inviteCode,
        wins,
        activeTitleCode,
        nudgesEnabled,
        slapsEnabled,
        humor,
      ];
}

class CoinEntry extends Equatable {
  const CoinEntry({
    required this.amount,
    required this.kind,
    required this.createdAt,
  });

  final int amount;
  final String kind;
  final DateTime? createdAt;

  String get label {
    switch (kind) {
      case 'signup_bonus':
        return 'সাইনআপ বোনাস';
      case 'match_reward':
        return 'ম্যাচ রিওয়ার্ড';
      case 'punishment_skip':
        return 'শাস্তি স্কিপ';
      case 'weekly_award':
        return 'সাপ্তাহিক অ্যাওয়ার্ড';
      default:
        return kind;
    }
  }

  @override
  List<Object?> get props => <Object?>[amount, kind, createdAt];
}
