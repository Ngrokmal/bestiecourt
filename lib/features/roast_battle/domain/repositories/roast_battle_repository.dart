import '../../../../core/pagination/cursor_page.dart';
import '../entities/battle_view.dart';

abstract class RoastBattleRepository {
  Future<BattleView> fetchMatch(String matchId);

  /// Initial fetch + Realtime updates for one match. Realtime is only a
  /// notification channel: every event re-fetches authoritative server state.
  Stream<BattleView> watchMatch(String matchId);

  Future<List<MatchSummary>> fetchOpenMatches();

  Future<CursorPage<MatchSummary>> fetchHistory(CursorPageRequest request);

  Future<String> createMatch(String friendId);

  Future<void> joinMatch(String matchId);

  Future<void> submitVote({
    required String matchId,
    required String votedForId,
  });

  Future<void> setPunishmentStatus({
    required String punishmentId,
    required String status,
  });
}
