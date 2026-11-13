import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/friend_picker.dart';
import '../../friends/domain/entities/friend_summary.dart';
import '../../profile/domain/entities/profile.dart';
import '../../roast_battle/domain/entities/battle_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Profile> profile = ref.watch(myProfileProvider);
    final AsyncValue<int> coins = ref.watch(myCoinBalanceProvider);
    final AsyncValue<int> unread = ref.watch(unreadNotificationsProvider);
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
          IconButton(
            tooltip: 'ইনবক্স',
            onPressed: () => context.push('/notifications'),
            icon: Badge(
              isLabelVisible: unread.maybeWhen(
                data: (int value) => value > 0,
                orElse: () => false,
              ),
              label: Text(
                unread.maybeWhen(
                  data: (int value) => '$value',
                  orElse: () => '0',
                ),
              ),
              child: const Icon(Icons.notifications_none),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
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
          ref.invalidate(unreadNotificationsProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            _DailyBattleCard(onStart: () => _startBattle(context, ref)),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: 'সব গেম',
              subtitle: 'মজার সব ফিচার এক জায়গায়',
            ),
            _GameGrid(),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'চলমান ম্যাচ',
              subtitle: 'বন্ধুর অপেক্ষায় বা ভোটের অপেক্ষায়',
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
            const SectionHeader(title: 'কীভাবে খেলবেন', subtitle: '৩ ধাপে মজা'),
            const AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _HowToStep(
                    number: '১',
                    text: 'বন্ধুকে ইনভাইট কোড দিয়ে যোগ করুন।',
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
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('সেটিংস'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/awards'),
                    icon: const Icon(Icons.emoji_events_outlined, size: 18),
                    label: const Text('লিডারবোর্ড'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Future<void> _startBattle(BuildContext context, WidgetRef ref) async {
    try {
      final FriendSummary? picked = await pickFriend(
        context,
        ref,
        title: 'কাকে চ্যালেঞ্জ করবেন?',
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

class _GameGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const List<_GameEntry> games = <_GameEntry>[
      _GameEntry('🎭', 'গোপন অভিযোগ', '/bluff/accusation'),
      _GameEntry('🤔', 'সত্যি নাকি মিথ্যা', '/bluff/truth_or_lie'),
      _GameEntry('⚖️', 'বেস্টি কোর্ট', '/court'),
      _GameEntry('🤝', 'বন্ধুত্বের চুক্তি', '/contracts'),
      _GameEntry('🔒', 'কনফেশন বক্স', '/confessions'),
      _GameEntry('😤', 'নাজ-নাজতি', '/social/nudge'),
      _GameEntry('🩴', 'চপ্পল ওয়াল', '/social/slap'),
      _GameEntry('🏆', 'টাইটেল ও অ্যাওয়ার্ড', '/awards'),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.1,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      children: games
          .map(
            (_GameEntry game) => AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              onTap: () => context.push(game.route),
              child: Row(
                children: <Widget>[
                  Text(game.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      game.label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _GameEntry {
  const _GameEntry(this.emoji, this.label, this.route);

  final String emoji;
  final String label;
  final String route;
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
                      ? 'অপেক্ষায়'
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
