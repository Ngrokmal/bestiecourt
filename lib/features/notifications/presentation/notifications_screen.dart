import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/widgets/common_widgets.dart';
import '../domain/app_notification.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<AppNotification> _items = <AppNotification>[];
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
      final List<AppNotification> items =
          await ref.read(notificationRepositoryProvider).fetchNotifications();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
      });
      ref.invalidate(unreadNotificationsProvider);
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
      appBar: AppBar(
        title: const Text('ইনবক্স'),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              try {
                await ref.read(notificationRepositoryProvider).markAllRead();
                if (!mounted) {
                  return;
                }
                ref.invalidate(unreadNotificationsProvider);
                await _load();
              } on Object catch (error) {
                if (!mounted) {
                  return;
                }
                showAppSnack(context, mapErrorToFailure(error).message);
              }
            },
            child: const Text('সব পড়া হয়েছে'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            if (_loading)
              const LoadingView(label: 'লোড হচ্ছে...')
            else if (_error != null)
              ErrorBanner(message: _error!, onRetry: _load)
            else if (_items.isEmpty)
              const EmptyStateView(
                icon: Icons.notifications_none,
                title: 'ইনবক্স খালি',
                message: 'বন্ধুর অনুরোধ, ম্যাচ বা অ্যাওয়ার্ড এলে এখানে দেখতে পাবেন।',
              )
            else
              ..._items.map(
                (AppNotification item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (item.isUnread)
                          const Padding(
                            padding: EdgeInsets.only(top: 6, right: 8),
                            child: Icon(
                              Icons.circle,
                              size: 8,
                              color: AppColors.accent,
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.body,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
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
