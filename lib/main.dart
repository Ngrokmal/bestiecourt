import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';

/// Application entrypoint.
///
/// Only the PUBLIC publishable/anon Supabase key is ever used here.
/// Privileged secrets live exclusively in Supabase Edge Function secrets.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.assertClientKeySafety();

  if (AppConfig.isBackendConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabasePublishableKey,
    );
  }

  runApp(const ProviderScope(child: RoastMyBestieApp()));
}
