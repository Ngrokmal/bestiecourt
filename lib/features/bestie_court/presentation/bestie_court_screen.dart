import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/friend_picker.dart';
import '../../friends/domain/entities/friend_summary.dart';
import '../domain/court_case.dart';

class BestieCourtScreen extends ConsumerStatefulWidget {
  const BestieCourtScreen({super.key});

  @override
  ConsumerState<BestieCourtScreen> createState() => _BestieCourtScreenState();
}

class _BestieCourtScreenState extends ConsumerState<BestieCourtScreen> {
  List<CourtCase> _cases = <CourtCase>[];
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
      final List<CourtCase> cases =
          await ref.read(courtRepositoryProvider).fetchCases();
      if (!mounted) {
        return;
      }
      setState(() {
        _cases = cases;
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

  Future<void> _fileCase() async {
    final FriendSummary? friend =
        await pickFriend(context, ref, title: 'কার বিরুদ্ধে মামলা?');
    if (friend == null || !mounted) {
      return;
    }
    final TextEditingController controller = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('অভিযোগ লিখুন'),
        content: TextField(
          controller: controller,
          maxLength: 220,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'যেমন: শেষ পিৎজা স্লাইস সে-ই খেয়েছে',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('দায়ের করুন'),
          ),
        ],
      ),
    );
    final String complaint = controller.text.trim();
    controller.dispose();
    if (confirmed != true || complaint.length < 8) {
      return;
    }
    await _run(
      () => ref.read(courtRepositoryProvider).createCase(
            defendantId: friend.userId,
            complaint: complaint,
          ),
      'মামলা দায়ের হয়েছে। প্রতিবাদীর উত্তরের অপেক্ষা।',
    );
  }

  Future<void> _respond(CourtCase item) async {
    final TextEditingController controller = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('আপনার জবাব'),
        content: TextField(
          controller: controller,
          maxLength: 220,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'মজার ভাষায় নিজের পক্ষে বলুন (খালি রাখলে এড়িয়ে যাবেন)',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('জমা দিন'),
          ),
        ],
      ),
    );
    final String text = controller.text.trim();
    controller.dispose();
    if (confirmed != true) {
      return;
    }
    await _run(
      () => ref.read(courtRepositoryProvider).respond(
            caseId: item.id,
            response: text.isEmpty ? null : text,
          ),
      'জবাব জমা হয়েছে — এখন জুরির ভোট।',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('বেস্টি কোর্ট')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _fileCase,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.gavel),
        label: const Text('মামলা করুন'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            const AppCard(
              child: Text(
                'জুরির নিয়ম: দুজনের দুটি ভোট (দোষী / নির্দোষ)। দুজন একমত হলে '
                'সেই রায়, ভোট সমান হলে মামলা খারিজ। সার্ভারই রায় ঘোষণা করে।',
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const LoadingView(label: 'মামলা লোড হচ্ছে...')
            else if (_error != null)
              ErrorBanner(message: _error!, onRetry: _load)
            else if (_cases.isEmpty)
              const EmptyStateView(
                icon: Icons.gavel,
                title: 'আদালত খালি',
                message: 'নিচের বাটনে চেপে বন্ধুর বিরুদ্ধে একটি মজার মামলা '
                    'দায়ের করুন।',
              )
            else
              ..._cases.map(
                (CourtCase item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _CaseCard(
                    item: item,
                    onRespond: () => _respond(item),
                    onVote: (bool guilty) => _run(
                      () => ref
                          .read(courtRepositoryProvider)
                          .vote(caseId: item.id, guilty: guilty),
                      'ভোট জমা হয়েছে।',
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

class _CaseCard extends StatelessWidget {
  const _CaseCard({
    required this.item,
    required this.onRespond,
    required this.onVote,
  });

  final CourtCase item;
  final VoidCallback onRespond;
  final void Function(bool guilty) onVote;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.gavel, size: 18, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${item.plaintiffName} বনাম ${item.defendantName}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip(
                label: item.decided ? item.verdictLabel : 'চলমান',
                color: item.decided ? AppColors.teal : AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            item.complaint,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          if (item.response != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'জবাব: ${item.response}',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
          if (item.needsMyResponse) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onRespond,
              child: const Text('জবাব দিন'),
            ),
          ],
          if (item.canVote) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: () => onVote(true),
                    child: const Text('দোষী'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onVote(false),
                    child: const Text('নির্দোষ'),
                  ),
                ),
              ],
            ),
          ],
          if (item.decided) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'রায়: ${item.verdictLabel}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Share.share(
                      '⚖️ বেস্টি কোর্টের রায়\n'
                      '${item.plaintiffName} বনাম ${item.defendantName}\n'
                      'অভিযোগ: ${item.complaint}\n'
                      'রায়: ${item.verdictLabel}\n'
                      '(Roast My Bestie — শুধু মজার জন্য)',
                      subject: 'Bestie Court',
                    );
                  },
                  icon: const Icon(Icons.ios_share, size: 16),
                  label: const Text('শেয়ার'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
