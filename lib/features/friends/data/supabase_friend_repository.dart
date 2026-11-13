import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/json_utils.dart';
import '../domain/entities/friend_summary.dart';
import '../domain/repositories/friend_repository.dart';

class SupabaseFriendRepository implements FriendRepository {
  SupabaseFriendRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<FriendSummary>> fetchFriends() async {
    final dynamic raw = await _client.rpc('rpc_list_friends');
    return asJsonList(raw)
        .map(_mapFriend)
        .where((FriendSummary friend) => friend.userId.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<FriendLookup?> lookupByInviteCode(String code) async {
    final String clean = code.trim().toUpperCase();
    if (clean.length < 4 || clean.length > 12) {
      return null;
    }
    final dynamic raw = await _client.rpc(
      'rpc_lookup_invite_code',
      params: <String, dynamic>{'p_code': clean},
    );
    final Map<String, dynamic> data = asJsonMap(raw);
    final String userId = asString(data['user_id']);
    if (userId.isEmpty) {
      return null;
    }
    return FriendLookup(
      userId: userId,
      displayName: asString(data['display_name'], fallback: 'Bestie'),
      alreadyFriends: asBool(data['already_friends']),
    );
  }

  @override
  Future<void> sendRequestByCode(String code) async {
    await _client.rpc(
      'rpc_send_friend_request_by_code',
      params: <String, dynamic>{'p_code': code.trim().toUpperCase()},
    );
  }

  @override
  Future<void> respond({
    required String friendshipId,
    required bool accept,
  }) async {
    await _client.rpc(
      'rpc_respond_friend_request',
      params: <String, dynamic>{
        'p_friendship_id': friendshipId,
        'p_accept': accept,
      },
    );
  }

  @override
  Future<void> removeFriendship(String friendshipId) async {
    await _client.rpc(
      'rpc_remove_friendship',
      params: <String, dynamic>{'p_friendship_id': friendshipId},
    );
  }

  FriendSummary _mapFriend(Map<String, dynamic> row) {
    final String direction = asString(row['direction'], fallback: 'mutual');
    return FriendSummary(
      friendshipId: asString(row['friendship_id']),
      userId: asString(row['user_id']),
      displayName: asString(row['display_name'], fallback: 'Bestie'),
      status: _status(asString(row['status'])),
      direction: _direction(direction),
    );
  }

  FriendshipStatus _status(String value) {
    switch (value) {
      case 'accepted':
        return FriendshipStatus.accepted;
      case 'rejected':
        return FriendshipStatus.rejected;
      case 'blocked':
        return FriendshipStatus.blocked;
      default:
        return FriendshipStatus.pending;
    }
  }

  FriendDirection _direction(String value) {
    switch (value) {
      case 'incoming':
        return FriendDirection.incoming;
      case 'outgoing':
        return FriendDirection.outgoing;
      default:
        return FriendDirection.mutual;
    }
  }
}
