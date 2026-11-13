import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/widgets/common_widgets.dart';
import '../domain/entities/friend_summary.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _addByCode() async {
    final String code = _codeController.text.trim().toUpperCase();
    if (code.length < 4) {
      showAppSnack(context, 'সঠিক ইনভাইট কোড দিন (কমপক্ষে ৪ অক্ষর)।');
      return;
    }
    setState(() => _busy = true);
    try {
      final FriendLookup? lookup =
          await ref.read(friendRepositoryProvider).lookupByInviteCode(code);
      if (!mounted) {
        return;
      }
      if (lookup == null) {
        showAppSnack(context, 'এই কোডে কোনো ইউজার পাওয়া যায়নি।');
        return;
      }
      if (lookup.alreadyFriends) {
        showAppSnack(context, '${lookup.displayName} ইতিমধ্যে আপনার বন্ধু।');
        return;
      }
      await ref.read(friendRepositoryProvider).sendRequestByCode(code);
      if (!mounted) {
        return;
      }
      _codeController.clear();
      ref.invalidate(friendsProvider);
      showAppSnack(context, '${lookup.displayName}-কে অনুরোধ পাঠানো হয়েছে।');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnack(context, mapErrorToFailure(error).message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _respond(FriendSummary friend, bool accept) async {
    setState(() => _busy = true);
    try {
      await ref.read(friendRepositoryProvider).respond(
            friendshipId: friend.friendshipId,
            accept: accept,
          );
      ref.invalidate(friendsProvider);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnack(context, mapErrorToFailure(error).message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _remove(FriendSummary friend) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(friendRepositoryProvider)
          .removeFriendship(friend.friendshipId);
      ref.invalidate(friendsProvider);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnack(context, mapErrorToFailure(error).message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<FriendSummary>> friendsAsync =
        ref.watch(friendsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('বন্ধুরা')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(friendsProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            const SectionHeader(
              title: 'বন্ধু যোগ করুন',
              subtitle: 'বন্ধুর ইনভাইট কোড লিখুন',
            ),
            AppCard(
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 12,
                    decoration: const InputDecoration(
                      labelText: 'ইনভাইট কোড',
                      hintText: 'যেমন: AB12CD34',
                      counterText: '',
                    ),
                    onSubmitted: (String value) => _addByCode(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _busy ? null : _addByCode,
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('অনুরোধ পাঠান'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AsyncView<List<FriendSummary>>(
              value: friendsAsync,
              onRetry: () async => ref.invalidate(friendsProvider),
              loadingLabel: 'বন্ধু তালিকা লোড হচ্ছে...',
              builder: (List<FriendSummary> friends) {
                final List<FriendSummary> incoming = friends
                    .where((FriendSummary f) => f.needsMyResponse)
                    .toList(growable: false);
                final List<FriendSummary> accepted = friends
                    .where((FriendSummary f) => f.isAccepted)
                    .toList(growable: false);
                final List<FriendSummary> outgoing = friends
                    .where(
                      (FriendSummary f) =>
                          f.status == FriendshipStatus.pending &&
                          f.direction == FriendDirection.outgoing,
                    )
                    .toList(growable: false);

                if (friends.isEmpty) {
                  return const AppCard(
                    child: Text(
                      'এখনো কোনো বন্ধু নেই। উপরে ইনভাইট কোড দিয়ে শুরু করুন, '
                      'অথবা প্রোফাইল ট্যাব থেকে নিজের কোড শেয়ার করুন।',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (incoming.isNotEmpty) ...<Widget>[
                      const SectionHeader(title: 'নতুন অনুরোধ'),
                      ...incoming.map(
                        (FriendSummary friend) => _FriendTile(
                          friend: friend,
                          onAccept: () => _respond(friend, true),
                          onReject: () => _respond(friend, false),
                          busy: _busy,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (accepted.isNotEmpty) ...<Widget>[
                      SectionHeader(
                        title: 'বন্ধু তালিকা (${accepted.length})',
                      ),
                      ...accepted.map(
                        (FriendSummary friend) => _FriendTile(
                          friend: friend,
                          onRemove: () => _remove(friend),
                          busy: _busy,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (outgoing.isNotEmpty) ...<Widget>[
                      const SectionHeader(title: 'পাঠানো অনুরোধ'),
                      ...outgoing.map(
                        (FriendSummary friend) => _FriendTile(
                          friend: friend,
                          onRemove: () => _remove(friend),
                          busy: _busy,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.busy,
    this.onAccept,
    this.onReject,
    this.onRemove,
  });

  final FriendSummary friend;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            BestieAvatar(name: friend.displayName),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    friend.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusLabel(friend),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (onAccept != null && onReject != null)
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'গ্রহণ',
                    onPressed: busy ? null : onAccept,
                    icon: const Icon(Icons.check, color: AppColors.teal),
                  ),
                  IconButton(
                    tooltip: 'বাতিল',
                    onPressed: busy ? null : onReject,
                    icon: const Icon(Icons.close, color: AppColors.danger),
                  ),
                ],
              )
            else if (onRemove != null)
              IconButton(
                tooltip: 'সরান',
                onPressed: busy ? null : onRemove,
                icon: const Icon(Icons.person_remove_outlined, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(FriendSummary friend) {
    switch (friend.status) {
      case FriendshipStatus.accepted:
        return 'বন্ধু — খেলার জন্য প্রস্তুত';
      case FriendshipStatus.pending:
        return friend.direction == FriendDirection.incoming
            ? 'আপনার অনুমোদনের অপেক্ষায়'
            : 'অনুরোধ পাঠানো হয়েছে';
      case FriendshipStatus.rejected:
        return 'অনুরোধ গ্রহণ করা হয়নি';
      case FriendshipStatus.blocked:
        return 'ব্লক করা হয়েছে';
    }
  }
}
