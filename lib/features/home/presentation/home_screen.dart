import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../friends/domain/entities/friend_summary.dart';
import '../../profile/domain/entities/profile.dart';
import '../../roast_battle/domain/entities/battle_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Profile> profile = ref.watch(myProfileProvider);
    final AsyncValue<int> coins = ref.watch(myCoinBalanceProvider);
    final AsyncValue<List<MatchSummary>> openMatches =
        ref.watch(openMatchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Roast My Bestie',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            profile.maybeWhen(
              data: (Profile data) => Text(
                'হ্যালো, ${data.displayName}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Center(
              child: CoinBadge(
                balance: coins.maybeWhen(
                  data: (int value) => value,
                  orElse: () => 0,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myProfileProvider);
          ref.invalidate(myCoinBalanceProvider);
          ref.invalidate(friendsProvider);
          ref.invalidate(openMatchesProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            _DailyBattleCard(onStart: () => _startBattle(context, ref)),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'চলমান ম্যাচ',
              subtitle: 'বন্ধুর অপেক্ষায় বা ভোটের অপেক্ষায়',
              trailing: IconButton(
                tooltip: 'রিফ্রেশ',
                onPressed: () => ref.invalidate(openMatchesProvider),
                icon: const Icon(Icons.refresh, size: 20),
              ),
            ),
            AsyncView<List<MatchSummary>>(
              value: openMatches,
              onRetry: () async => ref.invalidate(openMatchesProvider),
              loadingLabel: 'ম্যাচ লোড হচ্ছে...',
              builder: (List<MatchSummary> matches) {
                if (matches.isEmpty) {
                  return const AppCard(
                    child: Text(
                      'এখন কোনো চলমান ম্যাচ নেই। উপরের বাটনে চেপে বন্ধুকে '
                      'চ্যালেঞ্জ করুন!',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                return Column(
                  children: matches
                      .map(
                        (MatchSummary match) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _OpenMatchTile(match: match),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: 'কীভাবে খেলবেন',
              subtitle: '৩ ধাপে মজা',
            ),
            const AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _HowToStep(
                    number: '১',
                    text: 'বন্ধুকে ইনভাইট কোড দিয়ে যোগ করুন।',
                  ),
                  SizedBox(height: AppSpacing.md),
                  _HowToStep(
                    number: '২',
                    text: 'আজকের প্রশ্নে ভোট দিন। দুজনের ভোট গোপন থাকে।',
                  ),
                  SizedBox(height: AppSpacing.md),
                  _HowToStep(
                    number: '৩',
                    text: 'সার্ভার ফলাফল ঘোষণা করবে — তারপর মজার শাস্তি!',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Future<void> _startBattle(BuildContext context, WidgetRef ref) async {
    try {
      final AsyncValue<List<FriendSummary>> friendsAsync =
          ref.read(friendsProvider);
      final List<FriendSummary> all = friendsAsync.maybeWhen(
        data: (List<FriendSummary> data) => data,
        orElse: () => <FriendSummary>[],
      );
      final List<FriendSummary> accepted = all
          .where((FriendSummary friend) => friend.isAccepted)
          .toList(growable: false);

      if (accepted.isEmpty) {
        showAppSnack(
          context,
          'আগে অন্তত একজন বন্ধু যোগ করুন (বন্ধু ট্যাব দেখুন)।',
        );
        return;
      }

      final FriendSummary? picked = await showModalBottomSheet<FriendSummary>(
        context: context,
        backgroundColor: AppColors.surfaceRaised,
        builder: (BuildContext sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'কাকে চ্যালেঞ্জ করবেন?',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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

      if (picked == null || !context.mounted) {
        return;
      }

      final String matchId =
          await ref.read(roastBattleRepositoryProvider).createMatch(
                picked.userId,
              );
      ref.invalidate(openMatchesProvider);
      if (!context.mounted) {
        return;
      }
      await context.push('/battle/$matchId');
      ref.invalidate(openMatchesProvider);
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      showAppSnack(context, mapErrorToFailure(error).message);
    }
  }
}

class _DailyBattleCard extends StatelessWidget {
  const _DailyBattleCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'আজকের Roast Battle',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'একটি মজার প্রশ্ন, দুজনের গোপন ভোট, তারপর বিস্ফোরক ফলাফল।',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.tonal(
            onPressed: onStart,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.surface,
            ),
            child: const Text('বন্ধুকে চ্যালেঞ্জ করুন'),
          ),
        ],
      ),
    );
  }
}

class _OpenMatchTile extends ConsumerWidget {
  const _OpenMatchTile({required this.match});

  final MatchSummary match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: () async {
        await context.push('/battle/${match.id}');
        ref.invalidate(openMatchesProvider);
      },
      child: Row(
        children: <Widget>[
          BestieAvatar(name: match.opponentName),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  match.opponentName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  match.questionPrompt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          match.isJoinable
              ? const StatusChip(label: 'যোগ দিন', color: AppColors.accent)
              : StatusChip(
                  label: match.state == MatchState.waiting
                      ? 'অপেক্ষায়'
                      : 'ভোট চলছে',
                  color: AppColors.teal,
                ),
        ],
      ),
    );
  }
}

class _HowToStep extends StatelessWidget {
  const _HowToStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
