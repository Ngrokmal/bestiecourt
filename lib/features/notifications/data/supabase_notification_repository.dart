import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/json_utils.dart';
import '../domain/app_notification.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    final dynamic raw = await _client.rpc<dynamic>(
      'rpc_list_notifications',
      params: <String, dynamic>{'p_limit': 30},
    );
    return asJsonList(raw)
        .map(
          (Map<String, dynamic> row) => AppNotification(
            id: asString(row['id']),
            type: asString(row['type']),
            title: asString(row['title']),
            body: asString(row['body']),
            createdAt: asDateOrNull(row['created_at']),
            readAt: asDateOrNull(row['read_at']),
          ),
        )
        .where((AppNotification item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<int> fetchUnreadCount() async {
    final dynamic raw = await _client.rpc<dynamic>(
      'rpc_unread_notification_count',
    );
    return asInt(raw);
  }

  @override
  Future<void> markAllRead() async {
    await _client.rpc<dynamic>('rpc_mark_notifications_read');
  }
}
