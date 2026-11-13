import 'package:flutter_test/flutter_test.dart';
import 'package:roast_my_bestie/features/roast_battle/domain/entities/battle_view.dart';

void main() {
  group('MatchState', () {
    test('parses every server state code', () {
      expect(MatchState.fromCode('waiting'), MatchState.waiting);
      expect(MatchState.fromCode('voting'), MatchState.voting);
      expect(MatchState.fromCode('completed'), MatchState.completed);
      expect(MatchState.fromCode('expired'), MatchState.expired);
    });

    test('unknown server code never crashes the UI', () {
      expect(MatchState.fromCode('!!unknown!!'), MatchState.waiting);
    });

    test('isOpen only covers in-progress states', () {
      expect(MatchState.waiting.isOpen, isTrue);
      expect(MatchState.voting.isOpen, isTrue);
      expect(MatchState.completed.isOpen, isFalse);
      expect(MatchState.cancelled.isOpen, isFalse);
      expect(MatchState.expired.isOpen, isFalse);
    });
  });
}
