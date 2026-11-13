import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/json_utils.dart';
import '../domain/court_case.dart';

class SupabaseCourtRepository implements CourtRepository {
  SupabaseCourtRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CourtCase>> fetchCases() async {
    final dynamic raw = await _client.rpc<dynamic>('rpc_list_court_cases');
    return asJsonList(raw)
        .map(_map)
        .where((CourtCase item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> createCase({
    required String defendantId,
    required String complaint,
  }) async {
    await _client.rpc<dynamic>(
      'rpc_create_court_case',
      params: <String, dynamic>{
        'p_defendant_id': defendantId,
        'p_complaint': complaint,
      },
    );
  }

  @override
  Future<void> respond({
    required String caseId,
    required String? response,
  }) async {
    await _client.rpc<dynamic>(
      'rpc_respond_court_case',
      params: <String, dynamic>{
        'p_case_id': caseId,
        'p_response': response,
      },
    );
  }

  @override
  Future<void> vote({required String caseId, required bool guilty}) async {
    await _client.rpc<dynamic>(
      'rpc_vote_court_case',
      params: <String, dynamic>{
        'p_case_id': caseId,
        'p_choice': guilty ? 'guilty' : 'not_guilty',
      },
    );
  }

  CourtCase _map(Map<String, dynamic> row) {
    return CourtCase(
      id: asString(row['id']),
      plaintiffName: asString(row['plaintiff_name'], fallback: 'Bestie'),
      defendantName: asString(row['defendant_name'], fallback: 'Bestie'),
      isPlaintiff: asString(row['my_role'], fallback: 'defendant') == 'plaintiff',
      complaint: asString(row['complaint']),
      state: asString(row['state'], fallback: 'awaiting_response'),
      response: asStringOrNull(row['response']),
      verdict: asStringOrNull(row['verdict']),
      myVote: asStringOrNull(row['my_vote']),
      createdAt: asDateOrNull(row['created_at']),
    );
  }
}
