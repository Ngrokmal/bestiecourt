import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/json_utils.dart';
import '../domain/social_ping.dart';

class SupabaseSocialRepository implements SocialRepository {
  SupabaseSocialRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SocialPing>> fetchPings() async {
    final dynamic raw = await _client.rpc<dynamic>('rpc_list_pings');
    return asJsonList(raw)
        .map(
          (Map<String, dynamic> row) => SocialPing(
            id: asString(row['id']),
            kind: pingKindFromCode(asString(row['kind'], fallback: 'tomato')),
            senderId: asString(row['sender_id']),
            senderName: asString(row['sender_name'], fallback: 'Bestie'),
            isIncoming: asString(row['direction'], fallback: 'in') == 'in',
            createdAt: asDateOrNull(row['created_at']),
            dismissedAt: asDateOrNull(row['dismissed_at']),
          ),
        )
        .where((SocialPing item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> send({
    required String recipientId,
    required PingKind kind,
  }) async {
    await _client.rpc<dynamic>(
      'rpc_send_ping',
      params: <String, dynamic>{
        'p_recipient_id': recipientId,
        'p_kind': pingKindCode(kind),
      },
    );
  }

  @override
  Future<void> dismiss(String pingId) async {
    await _client.rpc<dynamic>(
      'rpc_dismiss_ping',
      params: <String, dynamic>{'p_ping_id': pingId},
    );
  }

  @override
  Future<void> block({required String userId, required bool blocked}) async {
    await _client.rpc<dynamic>(
      'rpc_block_user',
      params: <String, dynamic>{
        'p_user_id': userId,
        'p_blocked': blocked,
      },
    );
  }

  @override
  Future<void> report({
    required String userId,
    required String reason,
    String? note,
  }) async {
    await _client.rpc<dynamic>(
      'rpc_report_user',
      params: <String, dynamic>{
        'p_user_id': userId,
        'p_reason': reason,
        'p_note': note,
      },
    );
  }
}
