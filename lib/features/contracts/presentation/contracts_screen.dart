import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/friend_picker.dart';
import '../../friends/domain/entities/friend_summary.dart';
import '../domain/friendship_contract.dart';

class ContractsScreen extends ConsumerStatefulWidget {
  const ContractsScreen({super.key});

  @override
  ConsumerState<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends ConsumerState<ContractsScreen> {
  List<FriendshipContract> _contracts = <FriendshipContract>[];
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
      final List<FriendshipContract> items =
          await ref.read(contractRepositoryProvider).fetchContracts();
      if (!mounted) {
        return;
      }
      setState(() {
        _contracts = items;
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

  Future<void> _createContract() async {
    final FriendSummary? friend =
        await pickFriend(context, ref, title: 'কার সাথে চুক্তি?');
    if (friend == null || !mounted) {
      return;
    }
    final List<ContractTemplate> templates = await ref
        .read(contractRepositoryProvider)
        .fetchTemplates()
        .catchError((Object error) => <ContractTemplate>[]);
    if (!mounted) {
      return;
    }
    if (templates.isEmpty) {
      showAppSnack(context, 'চুক্তির টেমপ্লেট পাওয়া যায়নি (seed চালান)।');
      return;
    }

    final ContractTemplate? picked = await showModalBottomSheet<ContractTemplate>(
      context: context,
      backgroundColor: AppColors.surfaceRaised,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'কোন চুক্তি পাঠাবেন?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            ...templates.map(
              (ContractTemplate template) => ListTile(
                title: Text(template.title),
                subtitle: Text('${template.clauses.length}টি ধারা'),
                onTap: () => Navigator.of(sheetContext).pop(template),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null) {
      return;
    }
    await _run(
      () => ref.read(contractRepositoryProvider).createContract(
            participantId: friend.userId,
            templateCode: picked.code,
          ),
      'চুক্তি পাঠানো হয়েছে — সইয়ের অপেক্ষা।',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('বন্ধুত্বের চুক্তি')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createContract,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.handshake),
        label: const Text('নতুন চুক্তি'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            const AppCard(
              child: Text(
                '⚠️ এটি শুধু মজার জন্য — কোনো আইনি চুক্তি নয়। দুই পক্ষের সম্মতি '
                'ছাড়া চুক্তি সক্রিয় হয় না, আর যেকোনো পক্ষ যেকোনো সময় বাতিল করতে পারে।',
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const LoadingView(label: 'চুক্তি লোড হচ্ছে...')
            else if (_error != null)
              ErrorBanner(message: _error!, onRetry: _load)
            else if (_contracts.isEmpty)
              const EmptyStateView(
                icon: Icons.handshake,
                title: 'কোনো চুক্তি নেই',
                message: 'বন্ধুর সাথে একটি মজার চুক্তি করুন।',
              )
            else
              ..._contracts.map(
                (FriendshipContract item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _ContractCard(
                    item: item,
                    onAccept: () => _run(
                      () => ref
                          .read(contractRepositoryProvider)
                          .respond(contractId: item.id, accept: true),
                      'চুক্তি সই হয়েছে!',
                    ),
                    onDecline: () => _run(
                      () => ref
                          .read(contractRepositoryProvider)
                          .respond(contractId: item.id, accept: false),
                      'চুক্তি গ্রহণ করা হয়নি।',
                    ),
                    onCancel: () => _run(
                      () => ref
                          .read(contractRepositoryProvider)
                          .cancel(item.id),
                      'চুক্তি বাতিল হয়েছে।',
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

class _ContractCard extends StatelessWidget {
  const _ContractCard({
    required this.item,
    required this.onAccept,
    required this.onDecline,
    required this.onCancel,
  });

  final FriendshipContract item;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('🤝', style: TextStyle(fontSize: 18)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip(
                label: item.stateLabel,
                color: item.isActive ? AppColors.teal : AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${item.creatorName} ↔ ${item.participantName}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          ...item.clauses.map(
            (String clause) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('• ', style: TextStyle(color: AppColors.accent)),
                  Expanded(
                    child: Text(
                      clause,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (item.needsMySignature) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept,
                    child: const Text('সই করুন'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    child: const Text('না'),
                  ),
                ),
              ],
            ),
          ] else if (item.isActive || item.isPending) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    item.isPending ? 'সইয়ের অপেক্ষায়...' : 'চুক্তি সক্রিয়',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                TextButton(onPressed: onCancel, child: const Text('বাতিল')),
                TextButton.icon(
                  onPressed: () async {
                    await Share.share(
                      '🤝 ${item.title}\n'
                      '${item.clauses.map((String c) => '• $c').join('\n')}\n'
                      '(Roast My Bestie — শুধু মজার জন্য, আইনি নয়)',
                      subject: 'Friendship Contract',
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
