import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/design_tokens.dart';

class RoastMyBestieApp extends StatefulWidget {
  const RoastMyBestieApp({super.key});

  @override
  State<RoastMyBestieApp> createState() => _RoastMyBestieAppState();
}

class _RoastMyBestieAppState extends State<RoastMyBestieApp> {
  final _RouterRefreshNotifier _refresh = _RouterRefreshNotifier();
  GoRouter? _router;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (AppConfig.isBackendConfigured) {
      _router = buildRouter(refresh: _refresh);
      _authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen(
        (AuthState state) => _refresh.ping(),
      );
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isBackendConfigured) {
      return const _BackendNotConfiguredApp();
    }
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: _router,
    );
  }
}

class _RouterRefreshNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

class _BackendNotConfiguredApp extends StatelessWidget {
  const _BackendNotConfiguredApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const <Widget>[
                Icon(Icons.settings_suggest, size: 44, color: AppColors.accent),
                SizedBox(height: AppSpacing.lg),
                Text(
                  'ব্যাকএন্ড কনফিগার করা নেই',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'SUPABASE_URL এবং SUPABASE_PUBLISHABLE_KEY সেট করুন '
                  '(--dart-define) অথবা lib/core/config/app_config.dart '
                  'এর ডিফল্ট মান যাচাই করুন।',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
