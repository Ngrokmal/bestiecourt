import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/widgets/common_widgets.dart';
import '../domain/entities/battle_view.dart';

/// Realtime-backed view of one match. The stream emits authoritative server
/// state; Realtime events only trigger a re-fetch.
final StreamProviderFamily<BattleView, String> battleStreamProvider =
    StreamProvider.autoDispose.family<BattleView, String>(
  (Ref ref, String matchId) =>
      ref.watch(roastBattleRepositoryProvider).watchMatch(matchId),
);

class BattleScreen extends ConsumerWidget {
  const BattleScreen({required this.matchId, super.key});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<BattleView> battleAsync =
        ref.watch(battleStreamProvider(matchId));

    return Scaffold(
      appBar: AppBar(title: const Text('Roast Battle')),
      body: AsyncView<BattleView>(
        value: battleAsync,
        onRetry: () async => ref.invalidate(battleStreamProvider(matchId)),
        loadingLabel: 'ম্যাচ লোড হচ্ছে...',
        builder: (BattleView battle) => _BattleBody(battle: battle),
      ),
    );
  }
}

class _BattleBody extends ConsumerWidget {
  const _BattleBody({required this.battle});

  final BattleView battle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        _VersusHeader(battle: battle),
        const SizedBox(height: AppSpacing.lg),
        if (battle.state == MatchState.waiting)
          _WaitingPanel(
            battle: battle,
            onJoin: () => _run(
              context,
              () => ref
                  .read(roastBattleRepositoryProvider)
                  .joinMatch(battle.id),
              successMessage: 'ম্যাচ শুরু হয়েছে!',
            ),
          )
        else if (battle.state == MatchState.active ||
            battle.state == MatchState.voting)
          _VotingPanel(
            battle: battle,
            onVote: (String votedForId) => _run(
              context,
              () => ref.read(roastBattleRepositoryProvider).submitVote(
                    matchId: battle.id,
                    votedForId: votedForId,
                  ),
              successMessage: 'ভোট জমা হয়েছে।',
            ),
          )
        else if (battle.state == MatchState.revealing)
          const AppCard(
            child: Column(
              children: <Widget>[
                LoadingView(label: 'ফলাফল ঘোষণা হচ্ছে...'),
              ],
            ),
          )
        else if (battle.state.isFinished)
          _ResultPanel(
            battle: battle,
            onPunishmentStatus: (String status) => _run(
              context,
              () => ref
                  .read(roastBattleRepositoryProvider)
                  .setPunishmentStatus(
                    punishmentId: battle.punishment?.id ?? '',
                    status: status,
                  ),
              successMessage: 'শাস্তির স্ট্যাটাস আপডেট হয়েছে।',
            ),
          )
        else
          AppCard(
            child: Text(
              battle.state == MatchState.expired
                  ? 'এই ম্যাচের সময় শেষ হয়ে গেছে।'
                  : 'এই ম্যাচ বাতিল হয়েছে।',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _VersusHeader extends StatelessWidget {
  const _VersusHeader({required this.battle});

  final BattleView battle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.surfaceCard, AppColors.surfaceRaised],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _PlayerChip(name: battle.myName, label: 'আপনি'),
              const Text(
                'VS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.accent,
                ),
              ),
              _PlayerChip(name: battle.opponentName, label: 'প্রতিপক্ষ'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            battle.questionPrompt.isEmpty
                ? 'আজকের প্রশ্ন লোড হচ্ছে...'
                : battle.questionPrompt,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.name, required this.label});

  final String name;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        BestieAvatar(name: name, size: 48),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: 96,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _WaitingPanel extends StatelessWidget {
  const _WaitingPanel({required this.battle, required this.onJoin});

  final BattleView battle;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    if (battle.iAmPlayerOne) {
      return const AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'বন্ধুর অপেক্ষায়',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'আপনার বন্ধু অ্যাপ খুলে "চলমান ম্যাচ" থেকে এই ম্যাচে যোগ দিলে '
              'খেলা শুরু হবে। অ্যাপ বন্ধ করলেও ম্যাচ থাকবে।',
              style: TextStyle(color: AppColors.textMuted, height: 1.4),
            ),
          ],
        ),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${battle.opponentName} আপনাকে চ্যালেঞ্জ করেছে!',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'যোগ দিলে ১০ মিনিটের মধ্যে দুজনকেই ভোট দিতে হবে।',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: onJoin,
            child: const Text('ম্যাচে যোগ দিন'),
          ),
        ],
      ),
    );
  }
}

class _VotingPanel extends StatelessWidget {
  const _VotingPanel({required this.battle, required this.onVote});

  final BattleView battle;
  final void Function(String votedForId) onVote;

  @override
  Widget build(BuildContext context) {
    if (battle.iVoted) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.lock_clock, color: AppColors.teal, size: 18),
                const SizedBox(width: AppSpacing.sm),
                const Text(
                  'ভোট জমা হয়েছে',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'আপনার ভোট গোপন আছে। বন্ধু ভোট দেওয়ার পরেই ফলাফল দেখা যাবে।',
              style: TextStyle(color: AppColors.textMuted, height: 1.4),
            ),
            if (battle.votingDeadline != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  'সময়সীমা: ${_formatTime(battle.votingDeadline!)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            const LoadingView(label: 'বন্ধুর ভোটের অপেক্ষায়...'),
          ],
        ),
      );
    }

    if (!battle.canVote) {
      return const AppCard(
        child: Text(
          'এই মুহূর্তে ভোট দেওয়া যাচ্ছে না।',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'আপনার ভোট দিন',
          subtitle: 'একবারই ভোট দেওয়া যাবে — ভোট গোপন থাকবে',
        ),
        _VoteOption(
          name: battle.myName,
          emoji: '🙋',
          onTap: () => onVote(battle.myUserId),
        ),
        const SizedBox(height: AppSpacing.md),
        _VoteOption(
          name: battle.opponentName,
          emoji: '😈',
          onTap: () => onVote(battle.opponentId ?? ''),
        ),
      ],
    );
  }

  String _formatTime(DateTime value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _VoteOption extends StatelessWidget {
  const _VoteOption({
    required this.name,
    required this.emoji,
    required this.onTap,
  });

  final String name;
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const Icon(Icons.how_to_vote, color: AppColors.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultPanel extends ConsumerWidget {
  const _ResultPanel({
    required this.battle,
    required this.onPunishmentStatus,
  });

  final BattleView battle;
  final void Function(String status) onPunishmentStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool iWon = battle.winnerId != null &&
        battle.winnerId == battle.myUserId;
    final String headline = battle.isTie
        ? 'ড্র! দুজনেই সমান 😅'
        : iWon
            ? 'আপনি জিতেছেন! 🏆'
            : '${battle.opponentName} জিতেছেন 😬';

    return Column(
      children: <Widget>[
        AppCard(
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 96,
                child: Lottie.asset(
                  'assets/animations/reveal_pulse.json',
                  repeat: true,
                  errorBuilder: (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) =>
                      const Icon(
                    Icons.celebration,
                    size: 48,
                    color: AppColors.accent,
                  ),
                ),
              ),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _VoteSummary(
                    name: 'আপনার ভোট',
                    value: _nameFor(battle.myVoteForId),
                  ),
                  _VoteSummary(
                    name: '${battle.opponentName}-এর ভোট',
                    value: _nameFor(battle.opponentVoteForId),
                  ),
                ],
              ),
              if (battle.isTie)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    'ড্র হলে কোনো শাস্তি নেই — রিম্যাচ চালিয়ে দাও!',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (battle.punishment != null && battle.isMyPunishment)
          AppCard(
            gradient: const LinearGradient(
              colors: <Color>[AppColors.surfaceCard, Color(0xFF3A2154)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text('🎯', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'আপনার শাস্তি',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  battle.punishment!.text,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onPunishmentStatus('completed'),
                        child: const Text('সম্পন্ন করেছি'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onPunishmentStatus('skipped'),
                        child: Text(
                          'স্কিপ (${battle.punishment!.coinCost} কয়েন)',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'স্কিপ করতে চাইলে কয়েন কাটা হবে — সার্ভারেই হিসাব হয়।',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _nameFor(String? userId) {
    if (userId == null) {
      return '—';
    }
    if (userId == battle.myUserId) {
      return battle.myName;
    }
    return battle.opponentName;
  }
}

class _VoteSummary extends StatelessWidget {
  const _VoteSummary({required this.name, required this.value});

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          name,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

Future<void> _run(
  BuildContext context,
  Future<void> Function() action, {
  String? successMessage,
}) async {
  try {
    await action();
    if (!context.mounted) {
      return;
    }
    if (successMessage != null) {
      showAppSnack(context, successMessage);
    }
  } on Object catch (error) {
    if (!context.mounted) {
      return;
    }
    showAppSnack(context, mapErrorToFailure(error).message);
  }
}
