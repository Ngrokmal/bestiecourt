import 'package:equatable/equatable.dart';

class TitleInfo extends Equatable {
  const TitleInfo({
    required this.code,
    required this.label,
    required this.description,
    required this.emoji,
    required this.earned,
    required this.active,
  });

  final String code;
  final String label;
  final String description;
  final String emoji;
  final bool earned;
  final bool active;

  @override
  List<Object?> get props =>
      <Object?>[code, label, description, emoji, earned, active];
}

class LeaderboardRow extends Equatable {
  const LeaderboardRow({
    required this.userId,
    required this.displayName,
    required this.wins,
    required this.played,
    required this.isMe,
  });

  final String userId;
  final String displayName;
  final int wins;
  final int played;
  final bool isMe;

  @override
  List<Object?> get props =>
      <Object?>[userId, displayName, wins, played, isMe];
}

class WeeklyAward extends Equatable {
  const WeeklyAward({
    required this.code,
    required this.label,
    required this.emoji,
    required this.winnerName,
    required this.value,
  });

  final String code;
  final String label;
  final String emoji;
  final String winnerName;
  final int value;

  @override
  List<Object?> get props => <Object?>[code, label, emoji, winnerName, value];
}

abstract class AwardsRepository {
  Future<List<TitleInfo>> fetchMyTitles();

  Future<void> setActiveTitle(String? code);

  Future<List<LeaderboardRow>> fetchLeaderboard();

  Future<List<WeeklyAward>> fetchWeeklyAwards();
}
