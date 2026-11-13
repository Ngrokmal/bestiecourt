import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/pagination/cursor_page.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../roast_battle/domain/entities/battle_view.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final List<MatchSummary> _items = <MatchSummary>[];
  KeysetCursor? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMore(reset: true);
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _cursor = null;
        _hasMore = true;
      }
    });

    try {
      final CursorPage<MatchSummary> page =
          await ref.read(roastBattleRepositoryProvider).fetchHistory(
                CursorPageRequest(cursor: _cursor),
              );
      if (!mounted) {
        return;
      }
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore && page.nextCursor != null;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = mapErrorToFailure(error).message;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ম্যাচ ইতিহাস'),
        actions: <Widget>[
          IconButton(
            tooltip: 'রিফ্রেশ',
            onPressed: () => _loadMore(reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadMore(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _loadMore(reset: true),
                        child: const Text('আবার'),
                      ),
                    ],
                  ),
                ),
              ),
            if (_items.isEmpty && !_loading)
              const EmptyStateView(
                icon: Icons.history_toggle_off,
                title: 'এখনো কোনো ম্যাচ নেই',
                message: 'হোম ট্যাব থেকে বন্ধুকে চ্যালেঞ্জ করে প্রথম ম্যাচ '
                    'শুরু করুন।',
              ),
            ..._items.map(
              (MatchSummary match) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _HistoryTile(match: match),
              ),
            ),
            if (_loading) const LoadingView(label: 'লোড হচ্ছে...'),
            if (!_loading && _hasMore && _items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: OutlinedButton(
                  onPressed: _loadMore,
                  child: const Text('আরও দেখুন'),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.match});

  final MatchSummary match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String outcome;
    final Color color;
    if (match.isJoinable || match.state.isOpen) {
      outcome = 'চলমান';
      color = AppColors.accent;
    } else if (match.isTie) {
      outcome = 'ড্র';
      color = AppColors.teal;
    } else if (match.winnerId != null &&
        match.winnerId == ref.watch(currentUserProvider)?.id) {
      outcome = 'আপনি জিতেছেন';
      color = AppColors.teal;
    } else {
      outcome = '${match.opponentName} জিতেছেন';
      color = AppColors.secondary;
    }

    return AppCard(
      onTap: () async {
        await context.push('/battle/${match.id}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              BestieAvatar(name: match.opponentName, size: AppSizes.avatarSm),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  match.opponentName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip(label: outcome, color: color),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            match.questionPrompt,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          if (match.createdAt != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                _formatDate(match.createdAt!),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final String two = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$two-$day  $hour:$minute';
  }
}
