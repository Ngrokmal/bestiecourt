import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/widgets/common_widgets.dart';
import '../domain/awards.dart';

class AwardsScreen extends ConsumerStatefulWidget {
  const AwardsScreen({super.key});

  @override
  ConsumerState<AwardsScreen> createState() => _AwardsScreenState();
}

class _AwardsScreenState extends ConsumerState<AwardsScreen> {
  List<TitleInfo> _titles = <TitleInfo>[];
  List<LeaderboardRow> _board = <LeaderboardRow>[];
  List<WeeklyAward> _awards = <WeeklyAward>[];
  bool _loading = true;
  String? _error;

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
      final repository = ref.read(awardsRepositoryProvider);
      final List<TitleInfo> titles = await repository.fetchMyTitles();
      final List<LeaderboardRow> board = await repository.fetchLeaderboard();
      final List<WeeklyAward> awards = await repository.fetchWeeklyAwards();
      if (!mounted) {
        return;
      }
      setState(() {
        _titles = titles;
        _board = board;
        _awards = awards;
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

  Future<void> _setTitle(String? code) async {
    try {
      await ref.read(awardsRepositoryProvider).setActiveTitle(code);
      if (!mounted) {
        return;
      }
      ref.invalidate(myProfileProvider);
      showAppSnack(context, code == null ? 'টাইটেল লুকানো হয়েছে।' : 'টাইটেল সেট হয়েছে।');
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('টাইটেল ও অ্যাওয়ার্ড'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'টাইটেল'),
              Tab(text: 'লিডারবোর্ড'),
              Tab(text: 'অ্যাওয়ার্ড'),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const LoadingView(label: 'লোড হচ্ছে...')
              : _error != null
                  ? ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: <Widget>[
                        ErrorBanner(message: _error!, onRetry: _load),
                      ],
                    )
                  : TabBarView(
                      children: <Widget>[
                        _TitlesTab(titles: _titles, onSet: _setTitle),
                        _BoardTab(rows: _board),
                        _AwardsTab(awards: _awards),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _TitlesTab extends StatelessWidget {
  const _TitlesTab({required this.titles, required this.onSet});

  final List<TitleInfo> titles;
  final Future<void> Function(String? code) onSet;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        const AppCard(
          child: Text(
            'টাইটেল সার্ভার-যাচাই করা পরিসংখ্যান থেকে পাওয়া যায়। '
            'চাইলে টাইটেল লুকিয়ে রাখতে পারেন।',
            style: TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...titles.map(
          (TitleInfo title) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(
              child: Row(
                children: <Widget>[
                  Text(title.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          title.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!title.earned)
                    const StatusChip(label: 'লকড', color: AppColors.textMuted)
                  else if (title.active)
                    TextButton(
                      onPressed: () => onSet(null),
                      child: const Text('লুকান'),
                    )
                  else
                    TextButton(
                      onPressed: () => onSet(title.code),
                      child: const Text('সেট করুন'),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _BoardTab extends StatelessWidget {
  const _BoardTab({required this.rows});

  final List<LeaderboardRow> rows;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        const AppCard(
          child: Text(
            'এই সপ্তাহের (সোমবার থেকে) শুধু আপনার বন্ধুদের মধ্যে র‍্যাঙ্কিং। '
            'স্কোর সার্ভার হিসাব করে — কেউ বদলাতে পারে না।',
            style: TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...rows.asMap().entries.map(
          (MapEntry<int, LeaderboardRow> entry) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(
              child: Row(
                children: <Widget>[
                  Text(
                    '#${entry.key + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  BestieAvatar(name: entry.value.displayName, size: 32),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      entry.value.isMe
                          ? '${entry.value.displayName} (আপনি)'
                          : entry.value.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${entry.value.wins} জয় · ${entry.value.played} ম্যাচ',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _AwardsTab extends StatelessWidget {
  const _AwardsTab({required this.awards});

  final List<WeeklyAward> awards;

  @override
  Widget build(BuildContext context) {
    if (awards.isEmpty) {
      return const EmptyStateView(
        icon: Icons.emoji_events_outlined,
        title: 'এই সপ্তাহে এখনো কোনো অ্যাওয়ার্ড নেই',
        message: 'একটি ম্যাচ খেললেই এখানে ফলাফল দেখা যাবে।',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        ...awards.map(
          (WeeklyAward award) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(
              child: Row(
                children: <Widget>[
                  Text(award.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          award.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${award.winnerName} · ${award.value}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Share.share(
                        '${award.emoji} ${award.label}: ${award.winnerName} '
                        '(${award.value})\n(Roast My Bestie)',
                        subject: 'Bestie Award',
                      );
                    },
                    icon: const Icon(Icons.ios_share, size: 16),
                    label: const Text('শেয়ার'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}
