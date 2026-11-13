import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/friend_picker.dart';
import '../../friends/domain/entities/friend_summary.dart';
import '../domain/social_ping.dart';

/// Silent Treatment War + Ghosting reminder (nudge mode)
/// Virtual slap wall (slap mode). Everything is in-app only.
class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({required this.slapMode, super.key});

  final bool slapMode;

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> {
  List<SocialPing> _pings = <SocialPing>[];
  bool _loading = true;
  String? _error;

  List<PingKind> get _kinds => widget.slapMode
      ? <PingKind>[PingKind.tomato, PingKind.slipper]
      : <PingKind>[PingKind.angry, PingKind.sorry, PingKind.reminder];

  String get _title => widget.slapMode ? 'ভার্চুয়াল চপ্পল ওয়াল' : 'নাজ-নাজতি';

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
      final List<SocialPing> pings =
          await ref.read(socialRepositoryProvider).fetchPings();
      if (!mounted) {
        return;
      }
      setState(() {
        _pings = pings
            .where((SocialPing ping) => _kinds.contains(ping.kind))
            .toList(growable: false);
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

  Future<void> _send(PingKind kind) async {
    final FriendSummary? friend =
        await pickFriend(context, ref, title: 'কাকে পাঠাবেন?');
    if (friend == null) {
      return;
    }
    await _run(
      () => ref
          .read(socialRepositoryProvider)
          .send(recipientId: friend.userId, kind: kind),
      'পাঠানো হয়েছে (দিনে সীমিত সংখ্যকবার)।',
    );
  }

  Future<void> _menu(SocialPing ping) async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceRaised,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.report_gmailerrorred),
              title: const Text('রিপোর্ট করুন'),
              onTap: () => Navigator.of(sheetContext).pop('report'),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('ব্লক করুন'),
              onTap: () => Navigator.of(sheetContext).pop('block'),
            ),
          ],
        ),
      ),
    );
    if (action == 'report') {
      await _run(
        () => ref.read(socialRepositoryProvider).report(
              userId: ping.senderId,
              reason: 'harassment',
              note: 'In-app ${pingKindCode(ping.kind)} ping',
            ),
        'রিপোর্ট জমা হয়েছে — আমরা পর্যালোচনা করব।',
      );
    } else if (action == 'block') {
      await _run(
        () => ref
            .read(socialRepositoryProvider)
            .block(userId: ping.senderId, blocked: true),
        'ব্লক করা হয়েছে — এখন আর কোনো পিং আসবে না।',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            AppCard(
              child: Text(
                widget.slapMode
                    ? '🍅🩴 শুধু অ্যাপের ভেতরের মজার অ্যানিমেশন — বাস্তবে কিছুই '
                        'হয় না। দিনে সর্বোচ্চ ৫টি, আর বন্ধু চাইলে বন্ধ করতে পারে।'
                    : '😤 রাগ বা 🥺 সখ্যতা-প্রস্তাব শুধু অ্যাপের ভেতরে পাঠানো যায় — '
                        'এটি WhatsApp/Messenger দেখতে পায় না। দিনে সর্বোচ্চ ৩টি।',
                style: const TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'পাঠান',
              subtitle: _kinds.map((PingKind k) => pingLabel(k)).join(' · '),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final PingKind kind in _kinds)
                  ActionChip(
                    avatar: Text(pingEmoji(kind)),
                    label: Text(pingLabel(kind)),
                    onPressed: () => _send(kind),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'সাম্প্রতিক'),
            if (_loading)
              const LoadingView(label: 'লোড হচ্ছে...')
            else if (_error != null)
              ErrorBanner(message: _error!, onRetry: _load)
            else if (_pings.isEmpty)
              EmptyStateView(
                icon: widget.slapMode ? Icons.local_dining : Icons.sentiment_satisfied,
                title: 'এখনো কিছু নেই',
                message: 'উপরের বাটন থেকে প্রথম পিং পাঠান।',
              )
            else
              ..._pings.map(
                (SocialPing ping) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppCard(
                    onTap: ping.isIncoming ? () => _menu(ping) : null,
                    child: Row(
                      children: <Widget>[
                        Text(
                          pingEmoji(ping.kind),
                          style: const TextStyle(fontSize: 26),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                ping.isIncoming
                                    ? '${ping.senderName} → আপনি'
                                    : 'আপনি → ${ping.senderName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                pingLabel(ping.kind),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (ping.isIncoming && !ping.isDismissed)
                          IconButton(
                            tooltip: 'বাদ দিন',
                            onPressed: () => _run(
                              () => ref
                                  .read(socialRepositoryProvider)
                                  .dismiss(ping.id),
                              'বাদ দেওয়া হয়েছে।',
                            ),
                            icon: const Icon(Icons.close, size: 18),
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
