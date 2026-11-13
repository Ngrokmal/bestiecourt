import '../entities/friend_summary.dart';

abstract class FriendRepository {
  Future<List<FriendSummary>> fetchFriends();

  Future<FriendLookup?> lookupByInviteCode(String code);

  Future<void> sendRequestByCode(String code);

  Future<void> respond({
    required String friendshipId,
    required bool accept,
  });

  Future<void> removeFriendship(String friendshipId);
}
