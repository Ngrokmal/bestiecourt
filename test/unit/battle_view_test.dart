import 'package:flutter_test/flutter_test.dart';
import 'package:roast_my_bestie/features/roast_battle/domain/entities/battle_view.dart';

BattleView build({
  required String state,
  required String? myVote,
  MatchState? parsed,
}) {
  return BattleView(
    id: 'm1',
    state: parsed ?? MatchState.fromCode(state),
    questionPrompt: 'কে বেশি অজুহাত দেয়?',
    playerOneId: 'u1',
    playerTwoId: 'u2',
    playerOneName: 'Rafi',
    playerTwoName: 'Nadia',
    myUserId: 'u1',
    myVoteForId: myVote,
  );
}

void main() {
  group('BattleView vote rules', () {
    test('cannot vote twice on the same match', () {
      final BattleView view = build(state: 'voting', myVote: 'u2');
      expect(view.iVoted, isTrue);
      expect(view.canVote, isFalse);
    });

    test('can vote while the match is open and no vote exists', () {
      final BattleView view = build(state: 'voting', myVote: null);
      expect(view.canVote, isTrue);
    });

    test('cannot vote on a completed match', () {
      final BattleView view = build(state: 'completed', myVote: null);
      expect(view.canVote, isFalse);
    });

    test('opponent name resolves from the viewer perspective', () {
      final BattleView view = build(state: 'voting', myVote: null);
      expect(view.iAmPlayerOne, isTrue);
      expect(view.myName, 'Rafi');
      expect(view.opponentName, 'Nadia');
      expect(view.opponentId, 'u2');
    });
  });
}
