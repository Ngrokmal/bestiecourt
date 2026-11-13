import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/json_utils.dart';
import '../domain/entities/profile.dart';
import '../domain/repositories/profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const String _installationKey = 'bestie_installation_id';

  @override
  Future<Profile> fetchMyProfile() async {
    final String userId = _requireUserId();
    final List<Map<String, dynamic>> rows = await _client
        .from('profiles')
        .select('id, display_name, invite_code, wins, active_title_code')
        .eq('id', userId)
        .limit(1);

    if (rows.isEmpty) {
      throw StateError('PROFILE_NOT_FOUND');
    }
    final Map<String, dynamic> row = rows.first;
    return Profile(
      id: asString(row['id']),
      displayName: asString(row['display_name'], fallback: 'Bestie'),
      inviteCode: asString(row['invite_code']),
      wins: asInt(row['wins']),
      activeTitleCode: asStringOrNull(row['active_title_code']),
    );
  }

  @override
  Future<int> fetchMyCoinBalance() async {
    final String userId = _requireUserId();
    final List<Map<String, dynamic>> rows = await _client
        .from('coin_wallets')
        .select('balance')
        .eq('user_id', userId)
        .limit(1);
    if (rows.isEmpty) {
      return 0;
    }
    return asInt(rows.first['balance']);
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final String userId = _requireUserId();
    final String clean = displayName.trim();
    if (clean.length < 2 || clean.length > 24) {
      throw ArgumentError('DISPLAY_NAME_INVALID');
    }
    await _client
        .from('profiles')
        .update(<String, dynamic>{'display_name': clean})
        .eq('id', userId);
  }

  @override
  Future<void> registerInstallation() async {
    // Best-effort telemetry for abuse defence. Never blocks or breaks the UI.
    try {
      _requireUserId();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? installationId = prefs.getString(_installationKey);
      if (installationId == null) {
        installationId = const Uuid().v4();
        await prefs.setString(_installationKey, installationId);
      }

      String androidVersion = '';
      int sdkInt = 0;
      String manufacturer = '';
      String modelName = '';
      try {
        final AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
        androidVersion = info.version.release;
        sdkInt = info.version.sdkInt;
        manufacturer = info.manufacturer;
        modelName = info.model;
      } on Object {
        // Denominations are optional; missing values are recorded as empty.
      }

      String appVersion = '';
      try {
        final PackageInfo packageInfo = await PackageInfo.fromPlatform();
        appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      } on Object {
        appVersion = '';
      }

      await _client.rpc(
        'rpc_register_installation',
        params: <String, dynamic>{
          'p_installation_id': installationId,
          'p_platform': 'android',
          'p_android_version': androidVersion,
          'p_sdk_int': sdkInt,
          'p_manufacturer': manufacturer,
          'p_model_name': modelName,
          'p_app_version': appVersion,
        },
      );
    } on Object {
      // Ignored on purpose: installation registration is non-critical.
    }
  }

  String _requireUserId() {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('NOT_AUTHENTICATED');
    }
    return userId;
  }
}
