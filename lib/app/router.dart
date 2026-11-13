import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/auth_gate_screen.dart';
import '../features/awards/presentation/awards_screen.dart';
import '../features/bestie_court/presentation/bestie_court_screen.dart';
import '../features/bluff/domain/bluff_round.dart';
import '../features/bluff/presentation/bluff_screen.dart';
import '../features/coins/presentation/coin_history_screen.dart';
import '../features/confessions/presentation/confessions_screen.dart';
import '../features/contracts/presentation/contracts_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/roast_battle/presentation/battle_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/social/presentation/social_screen.dart';
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
        path: '/court',
        builder: (BuildContext context, GoRouterState state) =>
            const BestieCourtScreen(),
      ),
      GoRoute(
        path: '/bluff/:kind',
        builder: (BuildContext context, GoRouterState state) => BluffScreen(
          kind: bluffKindFromCode(
            state.pathParameters['kind'] ?? 'secret_accusation',
          ),
        ),
      ),
      GoRoute(
        path: '/contracts',
        builder: (BuildContext context, GoRouterState state) =>
            const ContractsScreen(),
      ),
      GoRoute(
        path: '/confessions',
        builder: (BuildContext context, GoRouterState state) =>
            const ConfessionsScreen(),
      ),
      GoRoute(
        path: '/social/:mode',
        builder: (BuildContext context, GoRouterState state) => SocialScreen(
          slapMode: state.pathParameters['mode'] == 'slap',
        ),
      ),
      GoRoute(
        path: '/awards',
        builder: (BuildContext context, GoRouterState state) =>
            const AwardsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (BuildContext context, GoRouterState state) =>
            const NotificationsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
      GoRoute(
        path: '/coins',
        builder: (BuildContext context, GoRouterState state) =>
            const CoinHistoryScreen(),
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
