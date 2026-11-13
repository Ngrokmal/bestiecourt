import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/json_utils.dart';
import '../domain/awards.dart';

class SupabaseAwardsRepository implements AwardsRepository {
  SupabaseAwardsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<TitleInfo>> fetchMyTitles() async {
    final dynamic raw = await _client.rpc<dynamic>('rpc_my_titles');
    return asJsonList(raw)
        .map(
          (Map<String, dynamic> row) => TitleInfo(
            code: asString(row['code']),
            label: asString(row['label'], fallback: 'Title'),
            description: asString(row['description']),
            emoji: asString(row['emoji'], fallback: '🏅'),
            earned: asBool(row['earned']),
            active: asBool(row['active']),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> setActiveTitle(String? code) async {
    await _client.rpc<dynamic>(
      'rpc_set_active_title',
      params: <String, dynamic>{'p_code': code},
    );
  }

  @override
  Future<List<LeaderboardRow>> fetchLeaderboard() async {
    final dynamic raw = await _client.rpc<dynamic>('rpc_friends_leaderboard');
    return asJsonList(raw)
        .map(
          (Map<String, dynamic> row) => LeaderboardRow(
            userId: asString(row['user_id']),
            displayName: asString(row['display_name'], fallback: 'Bestie'),
            wins: asInt(row['wins']),
            played: asInt(row['played']),
            isMe: asBool(row['is_me']),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<WeeklyAward>> fetchWeeklyAwards() async {
    final dynamic raw = await _client.rpc<dynamic>('rpc_weekly_awards');
    return asJsonList(raw)
        .map(
          (Map<String, dynamic> row) => WeeklyAward(
            code: asString(row['award_code']),
            label: asString(row['label'], fallback: 'Award'),
            emoji: asString(row['emoji'], fallback: '🏆'),
            winnerName: asString(row['winner_name'], fallback: '—'),
            value: asInt(row['value']),
          ),
        )
        .toList(growable: false);
  }
}
