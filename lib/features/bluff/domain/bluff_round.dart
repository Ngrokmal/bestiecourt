import 'package:equatable/equatable.dart';

enum BluffKind { secretAccusation, truthOrLie }

String bluffKindCode(BluffKind kind) =>
    kind == BluffKind.secretAccusation ? 'secret_accusation' : 'truth_or_lie';

BluffKind bluffKindFromCode(String code) =>
    code == 'secret_accusation' ? BluffKind.secretAccusation : BluffKind.truthOrLie;

class BluffRound extends Equatable {
  const BluffRound({
    required this.id,
    required this.kind,
    required this.authorName,
    required this.targetName,
    required this.isAuthor,
    required this.options,
    required this.status,
    required this.createdAt,
    this.body,
    this.myGuess,
    this.answerValue,
    this.isTrue,
  });

  final String id;
  final BluffKind kind;
  final String authorName;
  final String targetName;
  final bool isAuthor;
  final List<String> options;
  final String status;
  final DateTime? createdAt;

  /// Hidden from the target until the round is revealed by the server.
  final String? body;
  final int? myGuess;
  final int? answerValue;
  final bool? isTrue;

  bool get isWaiting => status == 'waiting';
  bool get isRevealed => status != 'waiting';
  bool get canGuess => isWaiting && !isAuthor;
  bool get matched =>
      myGuess != null && answerValue != null && myGuess == answerValue;

  @override
  List<Object?> get props => <Object?>[
        id,
        kind,
        authorName,
        targetName,
        isAuthor,
        options,
        status,
        body,
        myGuess,
        answerValue,
        isTrue,
      ];
}

abstract class BluffRepository {
  Future<List<BluffRound>> fetchRounds(BluffKind kind);

  Future<void> createRound({
    required BluffKind kind,
    required String targetId,
    required String body,
    required int answerValue,
  });

  Future<bool> guess({required String roundId, required int guessValue});
}
