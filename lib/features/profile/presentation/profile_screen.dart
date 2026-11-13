import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/widgets/common_widgets.dart';
import '../domain/entities/profile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Profile> profileAsync = ref.watch(myProfileProvider);
    final AsyncValue<int> coinsAsync = ref.watch(myCoinBalanceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('প্রোফাইল')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myProfileProvider);
          ref.invalidate(myCoinBalanceProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            AsyncView<Profile>(
              value: profileAsync,
              onRetry: () async => ref.invalidate(myProfileProvider),
              loadingLabel: 'প্রোফাইল লোড হচ্ছে...',
              builder: (Profile profile) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppCard(
                    child: Row(
                      children: <Widget>[
                        BestieAvatar(
                          name: profile.displayName,
                          size: 56,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                profile.displayName,
                                style:
                                    Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'জয়: ${profile.wins}  •  '
                                'টাইটেল: ${_titleLabel(profile.activeTitleCode)}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'নাম বদলান',
                          onPressed: () => _editName(context, ref, profile),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'আমার ইনভাইট কোড',
                    subtitle: 'বন্ধুকে এই কোডটি দিন',
                  ),
                  AppCard(
                    child: Column(
                      children: <Widget>[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            profile.inviteCode,
                            style: const TextStyle(
                              fontSize: 24,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await Share.share(
                                    'Roast My Bestie-তে আমার সাথে খেলো! '
                                    'আমার ইনভাইট কোড: ${profile.inviteCode}',
                                    subject: 'Roast My Bestie',
                                  );
                                },
                                icon: const Icon(Icons.ios_share, size: 18),
                                label: const Text('শেয়ার'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'ফ্রেন্ডশিপ কয়েন',
                    subtitle: 'শুধু মজার জন্য, আসল টাকা নয়',
                  ),
                  AppCard(
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.card_giftcard,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'ব্যালেন্স: '
                            '${coinsAsync.maybeWhen(data: (int v) => v, orElse: () => 0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const StatusChip(
                          label: 'সার্ভার-নিয়ন্ত্রিত',
                          color: AppColors.teal,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/settings'),
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          label: const Text('সেটিংস'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/coins'),
                          icon: const Icon(Icons.card_giftcard, size: 18),
                          label: const Text('কয়েন হিস্ট্রি'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'গোপনীয়তা ও সুরক্ষা',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        Text(
                          '• অ্যাপে কোনো সার্ভার-সিক্রেট (service_role) কী নেই।\n'
                          '• সব ডেটা Row Level Security দিয়ে সুরক্ষিত।\n'
                          '• ভোট ও শাস্তি সার্ভারে যাচাই হয় — ক্লায়েন্ট '
                          'বদলাতে পারে না।',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(authRepositoryProvider).signOut();
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('লগ আউট'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${AppConfig.appName} v${AppConfig.appVersion}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final TextEditingController controller =
        TextEditingController(text: profile.displayName);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('নাম পরিবর্তন'),
        content: TextField(
          controller: controller,
          maxLength: 24,
          decoration: const InputDecoration(labelText: 'ডিসপ্লে নাম'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('সেভ'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null || result.length < 2) {
      return;
    }
    try {
      await ref.read(profileRepositoryProvider).updateDisplayName(result);
      ref.invalidate(myProfileProvider);
      if (context.mounted) {
        showAppSnack(context, 'নাম আপডেট হয়েছে।');
      }
    } on Object catch (error) {
      if (context.mounted) {
        showAppSnack(context, mapErrorToFailure(error).message);
      }
    }
  }

  String _titleLabel(String? code) {
    switch (code) {
      case 'roast_champion':
        return 'Roast Champion';
      case 'reply_ghost':
        return 'Reply Ghost';
      case 'drama_queen':
        return 'Drama Queen';
      default:
        return 'নতুন খেলোয়াড়';
    }
  }
}
