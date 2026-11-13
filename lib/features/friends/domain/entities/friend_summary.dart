import 'package:equatable/equatable.dart';

enum FriendshipStatus { pending, accepted, rejected, blocked }

enum FriendDirection {
  /// The other user sent me a request (I must respond).
  incoming,

  /// I sent the request; waiting for the other user.
  outgoing,

  /// Already friends.
  mutual,
}

class FriendSummary extends Equatable {
  const FriendSummary({
    required this.friendshipId,
    required this.userId,
    required this.displayName,
    required this.status,
    required this.direction,
  });

  final String friendshipId;
  final String userId;
  final String displayName;
  final FriendshipStatus status;
  final FriendDirection direction;

  bool get isAccepted => status == FriendshipStatus.accepted;

  bool get needsMyResponse =>
      status == FriendshipStatus.pending && direction == FriendDirection.incoming;

  @override
  List<Object?> get props =>
      <Object?>[friendshipId, userId, displayName, status, direction];
}

class FriendLookup extends Equatable {
  const FriendLookup({
    required this.userId,
    required this.displayName,
    required this.alreadyFriends,
  });

  final String userId;
  final String displayName;
  final bool alreadyFriends;

  @override
  List<Object?> get props => <Object?>[userId, displayName, alreadyFriends];
}
