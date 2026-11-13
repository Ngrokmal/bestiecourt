import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/friend_picker.dart';
import '../../friends/domain/entities/friend_summary.dart';
import '../domain/confession.dart';

class ConfessionsScreen extends ConsumerStatefulWidget {
  const ConfessionsScreen({super.key});

  @override
  ConsumerState<ConfessionsScreen> createState() => _ConfessionsScreenState();
}

class _ConfessionsScreenState extends ConsumerState<ConfessionsScreen> {
  List<Confession> _items = <Confession>[];
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
      final List<Confession> items =
          await ref.read(confessionRepositoryProvider).fetchConfessions();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
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

  Future<void> _add() async {
    final TextEditingController controller = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('নতুন কনফেশন'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'শুধু মজার কথা লিখুন — ব্যক্তিগত/সংবেদনশীল তথ্য নয়। '
              'ডিফল্টভাবে এটি সম্পূর্ণ প্রাইভেট।',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller,
              maxLength: 240,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'যেমন: আমি লুকিয়ে বন্ধুর ফ্রাইস খেয়েছি',
              ),
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
            child: const Text('সেভ'),
          ),
        ],
      ),
    );
    final String text = controller.text.trim();
    controller.dispose();
    if (confirmed != true || text.length < 4) {
      return;
    }
    await _run(
      () => ref.read(confessionRepositoryProvider).create(text),
      'কনফেশন সেভ হয়েছে (প্রাইভেট)।',
    );
  }

  Future<void> _share(Confession item) async {
    final FriendSummary? friend =
        await pickFriend(context, ref, title: 'কাকে দেখাবেন?');
    if (friend == null) {
      return;
    }
    await _run(
      () => ref
          .read(confessionRepositoryProvider)
          .share(id: item.id, userId: friend.userId),
      'শেয়ার করা হয়েছে।',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('কনফেশন বক্স')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.lock_outline),
        label: const Text('নতুন'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            const AppCard(
              child: Text(
                '🔒 ডিফল্টভাবে শুধু আপনি দেখতে পান। শেয়ার করলে কেবল সেই বন্ধু '
                'দেখবে — Row Level Security এটি নিশ্চিত করে।',
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const LoadingView(label: 'লোড হচ্ছে...')
            else if (_error != null)
              ErrorBanner(message: _error!, onRetry: _load)
            else if (_items.isEmpty)
              const EmptyStateView(
                icon: Icons.lock_outline,
                title: 'বক্স খালি',
                message: 'নিচের বাটনে চেপে প্রথম মজার কনফেশন লিখুন।',
              )
            else
              ..._items.map(
                (Confession item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                item.isOwner ? 'আপনার কনফেশন' : 'বন্ধুর শেয়ার',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            StatusChip(
                              label: item.isShared ? 'শেয়ার করা' : 'প্রাইভেট',
                              color: item.isShared
                                  ? AppColors.accent
                                  : AppColors.teal,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          item.content,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                        if (item.isOwner) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: <Widget>[
                              TextButton(
                                onPressed: () => _share(item),
                                child: const Text('শেয়ার'),
                              ),
                              TextButton(
                                onPressed: () => _run(
                                  () => ref
                                      .read(confessionRepositoryProvider)
                                      .share(id: item.id, userId: null),
                                  'শেয়ার বন্ধ করা হয়েছে।',
                                ),
                                child: const Text('আনশেয়ার'),
                              ),
                              TextButton(
                                onPressed: () => _run(
                                  () => ref
                                      .read(confessionRepositoryProvider)
                                      .delete(item.id),
                                  'মুছে ফেলা হয়েছে।',
                                ),
                                child: const Text('ডিলিট'),
                              ),
                            ],
                          ),
                        ],
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
