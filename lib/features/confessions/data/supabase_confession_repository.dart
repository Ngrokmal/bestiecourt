import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/json_utils.dart';
import '../domain/confession.dart';

class SupabaseConfessionRepository implements ConfessionRepository {
  SupabaseConfessionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Confession>> fetchConfessions() async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('NOT_AUTHENTICATED');
    }
    final List<Map<String, dynamic>> rows = await _client
        .from('confessions')
        .select('id, owner_id, content, shared_with, created_at, deleted_at')
        .order('created_at', ascending: false)
        .limit(50);

    return rows
        .where((Map<String, dynamic> row) => row['deleted_at'] == null)
        .map(
          (Map<String, dynamic> row) => Confession(
            id: asString(row['id']),
            content: asString(row['content']),
            isOwner: asString(row['owner_id']) == userId,
            createdAt: asDateOrNull(row['created_at']),
            sharedWithId: asStringOrNull(row['shared_with']),
          ),
        )
        .where((Confession item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> create(String content) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('NOT_AUTHENTICATED');
    }
    await _client.from('confessions').insert(<String, dynamic>{
      'owner_id': userId,
      'content': content.trim(),
    });
  }

  @override
  Future<void> updateContent({
    required String id,
    required String content,
  }) async {
    await _client
        .from('confessions')
        .update(<String, dynamic>{'content': content.trim()}).eq('id', id);
  }

  @override
  Future<void> share({required String id, required String? userId}) async {
    await _client.rpc<dynamic>(
      'rpc_share_confession',
      params: <String, dynamic>{
        'p_confession_id': id,
        'p_user_id': userId,
      },
    );
  }

  @override
  Future<void> delete(String id) async {
    await _client
        .from('confessions')
        .update(<String, dynamic>{'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }
}
