import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/pagination/cursor_page.dart';
import '../../../core/supabase/json_utils.dart';
import '../domain/entities/battle_view.dart';
import '../domain/repositories/roast_battle_repository.dart';

class SupabaseRoastBattleRepository implements RoastBattleRepository {
  SupabaseRoastBattleRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<BattleView> fetchMatch(String matchId) async {
    final dynamic raw = await _client.rpc<dynamic>(
      'rpc_get_match',
      params: <String, dynamic>{'p_match_id': matchId},
    );
    final Map<String, dynamic> data = asJsonMap(raw);
    if (data.isEmpty) {
      throw StateError('MATCH_NOT_FOUND');
    }
    return _mapBattle(data);
  }

  @override
  Stream<BattleView> watchMatch(String matchId) {
    final StreamController<BattleView> controller =
        StreamController<BattleView>();
    RealtimeChannel? channel;

    Future<void> refresh() async {
      try {
        final BattleView view = await fetchMatch(matchId);
        if (!controller.isClosed) {
          controller.add(view);
        }
      } on Object catch (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      }
    }

    controller.onListen = () {
      unawaited(refresh());
      channel = _client
          .channel('match:$matchId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'matches',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: matchId,
            ),
            callback: (PostgresChangePayload payload) {
              unawaited(refresh());
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'match_punishments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'match_id',
              value: matchId,
            ),
            callback: (PostgresChangePayload payload) {
              unawaited(refresh());
            },
          )
          .subscribe();
    };

    controller.onCancel = () async {
      final RealtimeChannel? active = channel;
      channel = null;
      if (active != null) {
        await active.unsubscribe();
      }
      await controller.close();
    };

    return controller.stream;
  }

  @override
  Future<List<MatchSummary>> fetchOpenMatches() async {
    final dynamic raw = await _client.rpc<dynamic>(
      'rpc_list_matches',
      params: <String, dynamic>{
        'p_limit': 20,
        'p_only_open': true,
        'p_before_created_at': null,
        'p_before_id': null,
      },
    );
    return asJsonList(raw)
        .map(_mapSummary)
        .where((MatchSummary item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<CursorPage<MatchSummary>> fetchHistory(
    CursorPageRequest request,
  ) async {
    final dynamic raw = await _client.rpc<dynamic>(
      'rpc_list_matches',
      params: <String, dynamic>{
        'p_limit': request.limit + 1,
        'p_only_open': false,
        'p_before_created_at': request.cursor?.createdAtIso,
        'p_before_id': request.cursor?.id,
      },
    );
    final List<Map<String, dynamic>> rows = asJsonList(raw);
    final bool hasMore = rows.length > request.limit;
    final List<Map<String, dynamic>> pageRows =
        hasMore ? rows.sublist(0, request.limit) : rows;
    final List<MatchSummary> items =
        pageRows.map(_mapSummary).toList(growable: false);

    KeysetCursor? nextCursor;
    if (hasMore && pageRows.isNotEmpty) {
      final Map<String, dynamic> last = pageRows.last;
      final DateTime? created = asDateOrNull(last['created_at']);
      if (created != null) {
        nextCursor = KeysetCursor(
          createdAtIso: asString(last['created_at']),
          id: asString(last['id']),
        );
      }
    }

    return CursorPage<MatchSummary>(
      items: items,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<String> createMatch(String friendId) async {
    final dynamic raw = await _client.rpc<dynamic>(
      'rpc_create_match',
      params: <String, dynamic>{'p_friend_id': friendId},
    );
    final Map<String, dynamic> data = asJsonMap(raw);
    final String matchId = asString(data['match_id']);
    if (matchId.isEmpty) {
      throw StateError('MATCH_NOT_FOUND');
    }
    return matchId;
  }

  @override
  Future<void> joinMatch(String matchId) async {
    await _client.rpc<dynamic>(
      'rpc_join_match',
      params: <String, dynamic>{'p_match_id': matchId},
    );
  }

  @override
  Future<void> submitVote({
    required String matchId,
    required String votedForId,
  }) async {
    await _client.rpc<dynamic>(
      'rpc_submit_vote',
      params: <String, dynamic>{
        'p_match_id': matchId,
        'p_voted_for_id': votedForId,
      },
    );
  }

  @override
  Future<void> setPunishmentStatus({
    required String punishmentId,
    required String status,
  }) async {
    await _client.rpc<dynamic>(
      'rpc_set_punishment_status',
      params: <String, dynamic>{
        'p_punishment_id': punishmentId,
        'p_status': status,
      },
    );
  }

  BattleView _mapBattle(Map<String, dynamic> data) {
    final Map<String, dynamic> punishment = asJsonMap(data['punishment']);
    return BattleView(
      id: asString(data['id']),
      state: MatchState.fromCode(asString(data['state'], fallback: 'waiting')),
      questionPrompt: asString(data['question_prompt']),
      playerOneId: asString(data['player_one_id']),
      playerTwoId: asString(data['player_two_id']),
      playerOneName: asString(data['player_one_name'], fallback: 'Bestie 1'),
      playerTwoName: asString(data['player_two_name'], fallback: 'Bestie 2'),
      myUserId: asString(data['my_user_id']),
      myVoteForId: asStringOrNull(data['my_vote_for_id']),
      opponentVoteForId: asStringOrNull(data['opponent_vote_for_id']),
      winnerId: asStringOrNull(data['winner_id']),
      isTie: asBool(data['is_tie']),
      votingDeadline: asDateOrNull(data['voting_deadline']),
      punishment: punishment.isEmpty
          ? null
          : PunishmentOffer(
              id: asString(punishment['id']),
              text: asString(punishment['display_text']),
              status: asString(punishment['status'], fallback: 'offered'),
              coinCost: asInt(punishment['coin_cost']),
            ),
    );
  }

  MatchSummary _mapSummary(Map<String, dynamic> row) {
    return MatchSummary(
      id: asString(row['id']),
      state: MatchState.fromCode(asString(row['state'], fallback: 'waiting')),
      questionPrompt: asString(row['question_prompt']),
      opponentName: asString(row['opponent_name'], fallback: 'Bestie'),
      iAmPlayerOne: asBool(row['i_am_player_one']),
      createdAt: asDateOrNull(row['created_at']),
      winnerId: asStringOrNull(row['winner_id']),
      isTie: asBool(row['is_tie']),
    );
  }
}
