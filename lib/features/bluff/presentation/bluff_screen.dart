import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/friend_picker.dart';
import '../../friends/domain/entities/friend_summary.dart';
import '../domain/bluff_round.dart';

/// Secret Accusation + Truth-or-Lie share one honest mechanic:
/// the answer is stored server-side and only revealed after the guess.
class BluffScreen extends ConsumerStatefulWidget {
  const BluffScreen({required this.kind, super.key});

  final BluffKind kind;

  @override
  ConsumerState<BluffScreen> createState() => _BluffScreenState();
}

class _BluffScreenState extends ConsumerState<BluffScreen> {
  List<BluffRound> _rounds = <BluffRound>[];
  bool _loading = true;
  String? _error;

  String get _title => widget.kind == BluffKind.secretAccusation
      ? 'গোপন অভিযোগ'
      : 'সত্যি নাকি মিথ্যা';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<BluffRound> rounds =
          await ref.read(bluffRepositoryProvider).fetchRounds(widget.kind);
      if (!mounted) {
        return;
      }
      setState(() {
        _rounds = rounds;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = mapErrorToFailure(error).message;
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    try {
      await action();
      if (!mounted) {
        return;
      }
      showAppSnack(context, message);
      await _load();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnack(context, mapErrorToFailure(error).message);
    }
  }

  Future<void> _createRound() async {
    final FriendSummary? friend =
        await pickFriend(context, ref, title: 'কাকে পাঠাবেন?');
    if (friend == null || !mounted) {
      return;
    }

    final bool isAccusation = widget.kind == BluffKind.secretAccusation;
    final TextEditingController controller = TextEditingController();
    int answer = 0;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: Text(isAccusation ? 'নতুন অভিযোগ' : 'নতুন সত্যি/মিথ্যা'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: controller,
                maxLength: 160,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: isAccusation
                      ? 'যেমন: সে লুকিয়ে আমার স্ন্যাকস খেয়েছে'
                      : 'যেমন: আমি কখনো পিৎজা শেয়ার করি না',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'আপনার উত্তর (সার্ভারে গোপন থাকবে):',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  for (int index = 0; index < (isAccusation ? 4 : 2); index++)
                    ChoiceChip(
                      label: Text(
                        isAccusation
                            ? <String>[
                                'একদম সত্যি',
                                'আধা সত্যি',
                                'একদম মিথ্যা',
                                'জানি না',
                              ][index]
                            : (index == 0 ? 'সত্যি' : 'মিথ্যা'),
                      ),
                      selected: answer == index,
                      onSelected: (bool value) =>
                          setDialogState(() => answer = index),
                    ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('বাতিল'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('পাঠান'),
            ),
          ],
        ),
      ),
    );

    final String body = controller.text.trim();
    controller.dispose();

    if (confirmed != true || body.length < 8) {
      if (mounted && confirmed == true) {
        showAppSnack(context, 'কমপক্ষে ৮ অক্ষরের একটি বাক্য লিখুন।');
      }
      return;
    }

    await _run(
      () => ref.read(bluffRepositoryProvider).createRound(
            kind: widget.kind,
            targetId: friend.userId,
            body: body,
            answerValue: answer,
          ),
      'পাঠানো হয়েছে — বন্ধুর অনুমানের অপেক্ষায়।',
    );
  }

  Future<void> _guess(BluffRound round, int value) async {
    try {
      final bool matched = await ref.read(bluffRepositoryProvider).guess(
            roundId: round.id,
            guessValue: value,
          );
      if (!mounted) {
        return;
      }
      showAppSnack(context, matched ? 'একদম মিলে গেছে! 🎯' : 'মিস! 😅');
      await _load();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnack(context, mapErrorToFailure(error).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRound,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('নতুন'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            AppCard(
              child: Text(
                widget.kind == BluffKind.secretAccusation
                    ? 'একটি মজার অভিযোগ লিখুন। বন্ধু অনুমান করার পরেই '
                        'সেটি দেখতে পাবে — সার্ভারই গোপন রাখে।'
                    : 'একটি বাক্য লিখে সত্যি/মিথ্যা বলে দিন। বন্ধু অনুমান '
                        'করার আগে উত্তর কেউ দেখতে পাবে না।',
                style: const TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const LoadingView(label: 'লোড হচ্ছে...')
            else if (_error != null)
              ErrorBanner(message: _error!, onRetry: _load)
            else if (_rounds.isEmpty)
              EmptyStateView(
                icon: widget.kind == BluffKind.secretAccusation
                    ? Icons.visibility_off
                    : Icons.help_outline,
                title: 'এখনো কোনো রাউন্ড নেই',
                message: 'নিচের বাটনে চেপে প্রথম রাউন্ড শুরু করুন।',
              )
            else
              ..._rounds.map(
                (BluffRound round) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _RoundCard(
                    round: round,
                    onGuess: (int value) => _guess(round, value),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _RoundCard extends StatelessWidget {
  const _RoundCard({required this.round, required this.onGuess});

  final BluffRound round;
  final void Function(int value) onGuess;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              BestieAvatar(name: round.authorName, size: AppSizes.avatarSm),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  round.isAuthor
                      ? 'আপনি → ${round.targetName}'
                      : '${round.authorName} → আপনি',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip(
                label: round.isAuthor
                    ? 'পাঠানো হয়েছে'
                    : (round.isWaiting ? 'অনুমান করুন' : 'রিভিল'),
                color: round.isWaiting ? AppColors.accent : AppColors.teal,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (round.body != null)
            Text(
              round.body!,
              style: const TextStyle(fontSize: 14, height: 1.4),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Text(
                '🤫 বিষয়বস্তু গোপন — অনুমান করার পরেই দেখা যাবে।',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          if (round.canGuess) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (int index = 0; index < round.options.length; index++)
                  ActionChip(
                    label: Text(round.options[index]),
                    onPressed: () => onGuess(index),
                  ),
              ],
            ),
          ] else if (round.isRevealed) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    round.answerValue != null &&
                            round.answerValue! < round.options.length
                        ? 'উত্তর: ${round.options[round.answerValue!]}'
                        : 'উত্তর প্রকাশিত',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (round.isAuthor)
                  const StatusChip(label: 'সম্পন্ন', color: AppColors.teal)
                else
                  StatusChip(
                    label: round.matched ? 'মিলেছে 🎯' : 'মিস 😅',
                    color: round.matched ? AppColors.teal : AppColors.secondary,
                  ),
              ],
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'বন্ধুর অনুমানের অপেক্ষায়...',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}
