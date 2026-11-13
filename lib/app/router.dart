import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/auth_gate_screen.dart';
import '../features/roast_battle/presentation/battle_screen.dart';
import 'theme/design_tokens.dart';

/// Route table. Auth gating is handled here so a signed-out user can never
/// reach an authenticated screen (defence in depth: RLS still enforces access).
GoRouter buildRouter({required Listenable refresh}) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final bool signedIn =
          Supabase.instance.client.auth.currentSession != null;
      final bool atRoot = state.matchedLocation == '/';
      if (!signedIn && !atRoot) {
        return '/';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const AuthGateScreen(),
      ),
      GoRoute(
        path: '/battle/:matchId',
        builder: (BuildContext context, GoRouterState state) {
          final String matchId = state.pathParameters['matchId'] ?? '';
          if (matchId.isEmpty) {
            return const _RouteErrorScreen();
          }
          return BattleScreen(matchId: matchId);
        },
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) =>
        const _RouteErrorScreen(),
  );
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.explore_off, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            const Text('এই পেজটি পাওয়া যায়নি'),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('হোমে ফিরুন'),
            ),
          ],
        ),
      ),
    );
  }
}
