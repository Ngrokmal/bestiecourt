import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/providers.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../shell/presentation/app_shell.dart';
import 'sign_in_screen.dart';

/// Single decision point for authenticated vs anonymous UI.
class AuthGateScreen extends ConsumerWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AuthState> authState =
        ref.watch(authStateChangesProvider);

    return authState.when(
      data: (AuthState state) {
        final bool signedIn = state.session != null;
        return signedIn ? const AppShell() : const SignInScreen();
      },
      loading: () => const Scaffold(body: LoadingView()),
      error: (Object error, StackTrace stackTrace) => const Scaffold(
        body: EmptyStateView(
          icon: Icons.cloud_off_rounded,
          title: 'সার্ভারের সাথে সংযোগ করা যাচ্ছে না',
          message: 'ইন্টারনেট সংযোগ পরীক্ষা করে অ্যাপটি আবার খুলুন।',
        ),
      ),
    );
  }
}
