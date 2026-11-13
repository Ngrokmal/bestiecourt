import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../features/friends/domain/entities/friend_summary.dart';
import '../di/providers.dart';
import 'common_widgets.dart';

/// Shared friend picker used by every pair-based game.
/// Returns null when the user cancels or has no accepted friend yet.
Future<FriendSummary?> pickFriend(
  BuildContext context,
  WidgetRef ref, {
  String title = 'কাকে বেছে নেবেন?',
}) async {
  final List<FriendSummary> all = await ref.read(friendRepositoryProvider)
      .fetchFriends()
      .catchError((Object error) => <FriendSummary>[]);
  final List<FriendSummary> accepted = all
      .where((FriendSummary friend) => friend.isAccepted)
      .toList(growable: false);

  if (accepted.isEmpty) {
    if (context.mounted) {
      showAppSnack(context, 'আগে বন্ধু ট্যাব থেকে একজন বন্ধু যোগ করুন।');
    }
    return null;
  }
  if (!context.mounted) {
    return null;
  }

  return showModalBottomSheet<FriendSummary>(
    context: context,
    backgroundColor: AppColors.surfaceRaised,
    builder: (BuildContext sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          ...accepted.map(
            (FriendSummary friend) => ListTile(
              leading: BestieAvatar(name: friend.displayName),
              title: Text(friend.displayName),
              onTap: () => Navigator.of(sheetContext).pop(friend),
            ),
          ),
        ],
      ),
    ),
  );
}
