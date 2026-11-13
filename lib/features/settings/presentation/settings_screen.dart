import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../profile/domain/entities/profile.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _nudges;
  bool? _slaps;
  String? _humor;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Profile> profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('সেটিংস ও প্রাইভেসি')),
      body: AsyncView<Profile>(
        value: profileAsync,
        onRetry: () async => ref.invalidate(myProfileProvider),
        loadingLabel: 'লোড হচ্ছে...',
        builder: (Profile profile) {
          final bool nudges = _nudges ?? profile.nudgesEnabled;
          final bool slaps = _slaps ?? profile.slapsEnabled;
          final String humor = _humor ?? profile.humor;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              const SectionHeader(
                title: 'নোটিফিকেশন ও ইন্টার‍্যাকশন',
                subtitle: 'আপনি নিয়ন্ত্রণ করেন — বন্ধু নয়',
              ),
              AppCard(
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      value: nudges,
                      onChanged: (bool value) =>
                          setState(() => _nudges = value),
                      title: const Text('নাজ-নাজতি অনুমোদন'),
                      subtitle: const Text(
                        'রাগ/সখ্যতা-প্রস্তাব/রিমাইন্ডার পেতে চাইলে চালু রাখুন',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    SwitchListTile(
                      value: slaps,
                      onChanged: (bool value) =>
                          setState(() => _slaps = value),
                      title: const Text('চপ্পল-টমেটো অনুমোদন'),
                      subtitle: const Text(
                        'ভার্চুয়াল চপ্পল ওয়াল বন্ধ করতে এটা বন্ধ করুন',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(
                title: 'হাস্যরসের মাত্রা',
                subtitle: 'প্রশ্ন ও কপি এই অনুযায়ী বাছাই হবে',
              ),
              AppCard(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final String option in <String>[
                      'gentle',
                      'playful',
                      'spicy',
                    ])
                      ChoiceChip(
                        label: Text(
                          option == 'gentle'
                              ? 'নরম'
                              : option == 'playful'
                                  ? 'মজার'
                                  : 'ঝাল (নিরাপদ)',
                        ),
                        selected: humor == option,
                        onSelected: (bool value) =>
                            setState(() => _humor = option),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          await ref
                              .read(profileRepositoryProvider)
                              .updatePreferences(
                                nudges: nudges,
                                slaps: slaps,
                                humor: humor,
                              );
                          if (!mounted) {
                            return;
                          }
                          ref.invalidate(myProfileProvider);
                          showAppSnack(context, 'সেটিংস সেভ হয়েছে।');
                        } on Object catch (error) {
                          if (!mounted) {
                            return;
                          }
                          showAppSnack(
                            context,
                            mapErrorToFailure(error).message,
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _saving = false);
                          }
                        }
                      },
                child: Text(_saving ? 'সেভ হচ্ছে...' : 'সেভ করুন'),
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(title: 'আরও'),
              AppCard(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.card_giftcard),
                      title: const Text('কয়েন হিস্ট্রি'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/coins'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.emoji_events_outlined),
                      title: const Text('টাইটেল ও লিডারবোর্ড'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/awards'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.notifications_none),
                      title: const Text('ইনবক্স'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/notifications'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppCard(
                child: Text(
                  'প্রাইভেসি: আমরা কোনো ঠিকানা (IP), contacts, location বা '
                  'হার্ডওয়্যার আইডি সংগ্রহ করি না। ইনস্টলেশন আইডি একটি র‍্যান্ডম '
                  'UUID যা শুধু অ্যাপ-স্কোপড। পুশ নোটিফিকেশনে কখনো গোপন ভোট বা '
                  'কনফেশনের লেখা যায় না।',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }
}
