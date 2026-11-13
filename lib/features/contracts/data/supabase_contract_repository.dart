import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/json_utils.dart';
import '../domain/friendship_contract.dart';

class SupabaseContractRepository implements ContractRepository {
  SupabaseContractRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ContractTemplate>> fetchTemplates() async {
    final List<Map<String, dynamic>> rows = await _client
        .from('contract_templates')
        .select('code, title, clauses')
        .limit(20);
    return rows
        .map(
          (Map<String, dynamic> row) => ContractTemplate(
            code: asString(row['code']),
            title: asString(row['title'], fallback: 'চুক্তি'),
            clauses: (row['clauses'] is List<dynamic>)
                ? (row['clauses'] as List<dynamic>)
                    .map((dynamic item) => item.toString())
                    .toList(growable: false)
                : <String>[],
          ),
        )
        .where((ContractTemplate item) => item.code.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<FriendshipContract>> fetchContracts() async {
    final dynamic raw = await _client.rpc<dynamic>('rpc_list_contracts');
    return asJsonList(raw)
        .map(_map)
        .where((FriendshipContract item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> createContract({
    required String participantId,
    required String templateCode,
  }) async {
    await _client.rpc<dynamic>(
      'rpc_create_contract',
      params: <String, dynamic>{
        'p_participant_id': participantId,
        'p_template_code': templateCode,
      },
    );
  }

  @override
  Future<void> respond({
    required String contractId,
    required bool accept,
  }) async {
    await _client.rpc<dynamic>(
      'rpc_respond_contract',
      params: <String, dynamic>{
        'p_contract_id': contractId,
        'p_accept': accept,
      },
    );
  }

  @override
  Future<void> cancel(String contractId) async {
    await _client.rpc<dynamic>(
      'rpc_cancel_contract',
      params: <String, dynamic>{'p_contract_id': contractId},
    );
  }

  FriendshipContract _map(Map<String, dynamic> row) {
    return FriendshipContract(
      id: asString(row['id']),
      title: asString(row['title'], fallback: 'চুক্তি'),
      clauses: (row['clauses'] is List<dynamic>)
          ? (row['clauses'] as List<dynamic>)
              .map((dynamic item) => item.toString())
              .toList(growable: false)
          : <String>[],
      state: asString(row['state'], fallback: 'pending'),
      isCreator: asString(row['my_role'], fallback: 'participant') == 'creator',
      creatorName: asString(row['creator_name'], fallback: 'Bestie'),
      participantName: asString(row['participant_name'], fallback: 'Bestie'),
      expiresAt: asDateOrNull(row['expires_at']),
    );
  }
}
