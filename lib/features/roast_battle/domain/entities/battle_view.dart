import 'package:equatable/equatable.dart';

enum MatchState {
  waiting,
  active,
  voting,
  revealing,
  completed,
  cancelled,
  expired;

  static MatchState fromCode(String code) {
    switch (code) {
      case 'waiting':
        return MatchState.waiting;
      case 'active':
        return MatchState.active;
      case 'voting':
        return MatchState.voting;
      case 'revealing':
        return MatchState.revealing;
      case 'completed':
        return MatchState.completed;
      case 'cancelled':
        return MatchState.cancelled;
      case 'expired':
        return MatchState.expired;
      default:
        return MatchState.waiting;
    }
  }

  bool get isOpen =>
      this == MatchState.waiting ||
      this == MatchState.active ||
      this == MatchState.voting ||
      this == MatchState.revealing;

  bool get isFinished => this == MatchState.completed;
}

class PunishmentOffer extends Equatable {
  const PunishmentOffer({
    required this.id,
    required this.text,
    required this.status,
    required this.coinCost,
  });

  final String id;
  final String text;
  final String status;
  final int coinCost;

  bool get isOpen => status == 'offered' || status == 'accepted';

  @override
  List<Object?> get props => <Object?>[id, text, status, coinCost];
}

/// Full, server-filtered view of one match.
///
/// The opponent's vote is deliberately absent from this payload until the
/// server has resolved the match (state `completed`).
class BattleView extends Equatable {
  const BattleView({
    required this.id,
    required this.state,
    required this.questionPrompt,
    required this.playerOneId,
    required this.playerTwoId,
    required this.playerOneName,
    required this.playerTwoName,
    required this.myUserId,
    this.myVoteForId,
    this.opponentVoteForId,
    this.winnerId,
    this.isTie = false,
    this.votingDeadline,
    this.punishment,
  });

  final String id;
  final MatchState state;
  final String questionPrompt;
  final String playerOneId;
  final String playerTwoId;
  final String playerOneName;
  final String playerTwoName;
  final String myUserId;
  final String? myVoteForId;
  final String? opponentVoteForId;
  final String? winnerId;
  final bool isTie;
  final DateTime? votingDeadline;
  final PunishmentOffer? punishment;

  bool get iAmPlayerOne => myUserId == playerOneId;

  String get myName => iAmPlayerOne ? playerOneName : playerTwoName;

  String get opponentName => iAmPlayerOne ? playerTwoName : playerOneName;

  String? get opponentId => iAmPlayerOne ? playerTwoId : playerOneId;
  bool get iVoted => myVoteForId != null;
  bool get canVote =>
      (state == MatchState.voting || state == MatchState.active) && !iVoted;
  bool get isMyPunishment => punishment != null && punishment!.isOpen;

  @override
  List<Object?> get props => <Object?>[
        id,
        state,
        questionPrompt,
        playerOneId,
        playerTwoId,
        playerOneName,
        playerTwoName,
        myUserId,
        myVoteForId,
        opponentVoteForId,
        winnerId,
        isTie,
        votingDeadline,
        punishment,
      ];
}

class MatchSummary extends Equatable {
  const MatchSummary({
    required this.id,
    required this.state,
    required this.questionPrompt,
    required this.opponentName,
    required this.iAmPlayerOne,
    required this.createdAt,
    this.winnerId,
    this.isTie = false,
  });

  final String id;
  final MatchState state;
  final String questionPrompt;
  final String opponentName;
  final bool iAmPlayerOne;
  final DateTime? createdAt;
  final String? winnerId;
  final bool isTie;

  /// True when I am the invited player and the match has not started yet.
  bool get isJoinable =>
      state == MatchState.waiting && !iAmPlayerOne;

  @override
  List<Object?> get props => <Object?>[
        id,
        state,
        questionPrompt,
        opponentName,
        iAmPlayerOne,
        createdAt,
        winnerId,
        isTie,
      ];
}
