import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/json_utils.dart';
import '../domain/bluff_round.dart';

class SupabaseBluffRepository implements BluffRepository {
  SupabaseBluffRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<BluffRound>> fetchRounds(BluffKind kind) async {
    final dynamic raw = await _client.rpc<dynamic>(
      'rpc_list_bluff_rounds',
      params: <String, dynamic>{'p_kind': bluffKindCode(kind)},
    );
    return asJsonList(raw)
        .map((Map<String, dynamic> row) => _map(row, kind))
        .where((BluffRound round) => round.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> createRound({
    required BluffKind kind,
    required String targetId,
    required String body,
    required int answerValue,
  }) async {
    await _client.rpc<dynamic>(
      'rpc_create_bluff_round',
      params: <String, dynamic>{
        'p_kind': bluffKindCode(kind),
        'p_target_id': targetId,
        'p_body': body,
        'p_answer_value': answerValue,
      },
    );
  }

  @override
  Future<bool> guess({
    required String roundId,
    required int guessValue,
  }) async {
    final dynamic raw = await _client.rpc<dynamic>(
      'rpc_guess_bluff_round',
      params: <String, dynamic>{
        'p_id': roundId,
        'p_guess_value': guessValue,
      },
    );
    return asBool(asJsonMap(raw)['matched']);
  }

  BluffRound _map(Map<String, dynamic> row, BluffKind fallbackKind) {
    final List<String> options = (row['options'] is List<dynamic>)
        ? (row['options'] as List<dynamic>)
            .map((dynamic item) => item.toString())
            .toList(growable: false)
        : <String>[];
    return BluffRound(
      id: asString(row['id']),
      kind: bluffKindFromCode(
        asString(row['kind'], fallback: bluffKindCode(fallbackKind)),
      ),
      authorName: asString(row['author_name'], fallback: 'Bestie'),
      targetName: asString(row['target_name'], fallback: 'Bestie'),
      isAuthor: asString(row['my_role'], fallback: 'target') == 'author',
      options: options,
      status: asString(row['status'], fallback: 'waiting'),
      body: asStringOrNull(row['body']),
      myGuess: row['my_guess'] == null ? null : asInt(row['my_guess']),
      answerValue:
          row['answer_value'] == null ? null : asInt(row['answer_value']),
      isTrue: row['is_true'] == null ? null : asBool(row['is_true']),
      createdAt: asDateOrNull(row['created_at']),
    );
  }
}
