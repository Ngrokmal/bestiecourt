import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../profile/domain/entities/profile.dart';

class CoinHistoryScreen extends ConsumerStatefulWidget {
  const CoinHistoryScreen({super.key});

  @override
  ConsumerState<CoinHistoryScreen> createState() => _CoinHistoryScreenState();
}

class _CoinHistoryScreenState extends ConsumerState<CoinHistoryScreen> {
  List<CoinEntry> _entries = <CoinEntry>[];
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
      final List<CoinEntry> entries =
          await ref.read(profileRepositoryProvider).fetchCoinHistory();
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('কয়েন হিস্ট্রি')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            const AppCard(
              child: Text(
                'ফ্রেন্ডশিপ কয়েন শুধু মজার জন্য — আসল টাকার কোনো মূল্য নেই। '
                'প্রতিটি এন্ট্রি সার্ভারে অপরিবর্তনীয় (immutable ledger)।',
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const LoadingView(label: 'লোড হচ্ছে...')
            else if (_error != null)
              ErrorBanner(message: _error!, onRetry: _load)
            else if (_entries.isEmpty)
              const EmptyStateView(
                icon: Icons.card_giftcard,
                title: 'কোনো লেনদেন নেই',
              )
            else
              ..._entries.map(
                (CoinEntry entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            entry.label,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          '${entry.amount > 0 ? '+' : ''}${entry.amount}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: entry.amount >= 0
                                ? AppColors.teal
                                : AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
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
