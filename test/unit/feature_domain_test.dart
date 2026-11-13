import 'package:roast_my_bestie/features/awards/domain/awards.dart';
import 'package:roast_my_bestie/features/bestie_court/domain/court_case.dart';
import 'package:roast_my_bestie/features/bluff/domain/bluff_round.dart';
import 'package:roast_my_bestie/features/contracts/domain/friendship_contract.dart';
import 'package:roast_my_bestie/features/notifications/domain/app_notification.dart';
import 'package:roast_my_bestie/features/social/domain/social_ping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bluff round visibility', () {
    test('target cannot guess when the round is already revealed', () {
      final BluffRound round = BluffRound(
        id: 'r1',
        kind: BluffKind.secretAccusation,
        authorName: 'Rafi',
        targetName: 'Nadia',
        isAuthor: false,
        options: const <String>['a', 'b', 'c', 'd'],
        status: 'guessed',
        createdAt: DateTime(2026),
        body: 'আমি জানি তুমি খেয়েছ',
      );

      expect(round.isWaiting, isFalse);
      expect(round.isRevealed, isTrue);
      expect(round.canGuess, isFalse);
    });

    test('author never guesses their own round', () {
      final BluffRound round = BluffRound(
        id: 'r2',
        kind: BluffKind.truthOrLie,
        authorName: 'Rafi',
        targetName: 'Nadia',
        isAuthor: true,
        options: const <String>['সত্যি', 'মিথ্যা'],
        status: 'waiting',
        createdAt: DateTime(2026),
      );

      expect(round.canGuess, isFalse);
      expect(round.body, isNull);
    });

    test('match detection needs both the guess and the answer', () {
      BluffRound build({int? guess, int? answer}) => BluffRound(
            id: 'r3',
            kind: BluffKind.secretAccusation,
            authorName: 'Rafi',
            targetName: 'Nadia',
            isAuthor: false,
            options: const <String>['a', 'b', 'c', 'd'],
            status: 'guessed',
            createdAt: DateTime(2026),
            myGuess: guess,
            answerValue: answer,
          );

      expect(build(guess: 2, answer: 2).matched, isTrue);
      expect(build(guess: 2, answer: 1).matched, isFalse);
      expect(build(guess: null, answer: 2).matched, isFalse);
    });

    test('kind codes round-trip', () {
      expect(bluffKindCode(BluffKind.secretAccusation), 'secret_accusation');
      expect(bluffKindCode(BluffKind.truthOrLie), 'truth_or_lie');
      expect(
        bluffKindFromCode('secret_accusation'),
        BluffKind.secretAccusation,
      );
      expect(bluffKindFromCode('truth_or_lie'), BluffKind.truthOrLie);
    });
  });

  group('court case state machine', () {
    CourtCase build({
      required String state,
      bool isPlaintiff = true,
      String? verdict,
      String? myVote,
    }) =>
        CourtCase(
          id: 'c1',
          plaintiffName: 'Rafi',
          defendantName: 'Nadia',
          isPlaintiff: isPlaintiff,
          complaint: 'শেষ পিৎজা সে খেয়েছে',
          state: state,
          createdAt: DateTime(2026),
          verdict: verdict,
          myVote: myVote,
        );

    test('only the defendant can answer a fresh complaint', () {
      expect(build(state: 'awaiting_response').needsMyResponse, isFalse);
      expect(
        build(state: 'awaiting_response', isPlaintiff: false).needsMyResponse,
        isTrue,
      );
    });

    test('voting is offered once and only while voting', () {
      expect(build(state: 'voting').canVote, isTrue);
      expect(build(state: 'voting', myVote: 'guilty').canVote, isFalse);
      expect(build(state: 'awaiting_response').canVote, isFalse);
    });

    test('verdict labels cover every server verdict', () {
      expect(build(state: 'decided', verdict: 'guilty').verdictLabel,
          contains('দোষী'));
      expect(build(state: 'decided', verdict: 'not_guilty').verdictLabel,
          contains('নির্দোষ'));
      expect(build(state: 'decided', verdict: 'split').verdictLabel,
          contains('খারিজ'));
      expect(build(state: 'decided', verdict: 'dismissed').verdictLabel,
          contains('খারিজ'));
      expect(build(state: 'decided').decided, isTrue);
    });
  });

  group('friendship contract', () {
    FriendshipContract build({required String state, required bool mine}) =>
        FriendshipContract(
          id: 'k1',
          title: 'Fries শান্তি চুক্তি',
          clauses: const <String>['শেষ bite ভাগ করা হবে'],
          state: state,
          isCreator: mine,
          creatorName: 'Rafi',
          participantName: 'Nadia',
          expiresAt: DateTime(2026, 12, 30),
        );

    test('the receiver of a pending contract must sign it', () {
      expect(build(state: 'pending', mine: false).needsMySignature, isTrue);
      expect(build(state: 'pending', mine: true).needsMySignature, isFalse);
      expect(build(state: 'active', mine: false).needsMySignature, isFalse);
    });

    test('state labels are user facing', () {
      expect(build(state: 'active', mine: true).stateLabel, contains('সক্রিয়'));
      expect(build(state: 'pending', mine: true).stateLabel, contains('সই'));
      expect(build(state: 'expired', mine: true).isActive, isFalse);
    });
  });

  group('social ping helpers', () {
    test('every kind has code, emoji and label', () {
      for (final PingKind kind in PingKind.values) {
        final String code = pingKindCode(kind);
        expect(code, isNotEmpty);
        expect(pingKindFromCode(code), kind);
        expect(pingEmoji(kind), isNotEmpty);
        expect(pingLabel(kind), isNotEmpty);
      }
    });

    test('incoming dismissed ping is flagged', () {
      final SocialPing ping = SocialPing(
        id: 'p1',
        kind: PingKind.tomato,
        senderId: 'u1',
        senderName: 'Rafi',
        isIncoming: true,
        createdAt: DateTime(2026),
        dismissedAt: DateTime(2026),
      );
      expect(ping.isDismissed, isTrue);
      expect(ping.isIncoming, isTrue);
    });
  });

  group('awards and inbox', () {
    test('unread notification has no read timestamp', () {
      final AppNotification unread = AppNotification(
        id: 'n1',
        type: 'court',
        title: 'রায় ঘোষণা',
        body: 'জুরি বলেছে: দোষী',
        createdAt: DateTime(2026),
      );
      final AppNotification read = AppNotification(
        id: 'n2',
        type: 'court',
        title: 'রায় ঘোষণা',
        body: 'জুরি বলেছে: দোষী',
        createdAt: DateTime(2026),
        readAt: DateTime(2026),
      );
      expect(unread.isUnread, isTrue);
      expect(read.isUnread, isFalse);
    });

    test('title info keeps earned and active flags separate', () {
      const TitleInfo title = TitleInfo(
        code: 'roast_champion',
        label: 'Roast Champion',
        description: '৩টি ম্যাচ জিতেছেন',
        emoji: '🏆',
        earned: true,
        active: false,
      );
      expect(title.earned, isTrue);
      expect(title.active, isFalse);
    });
  });
}
