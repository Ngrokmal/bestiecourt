import 'package:equatable/equatable.dart';

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  @override
  List<Object?> get props => <Object?>[id, type, title, body, createdAt, readAt];
}

abstract class NotificationRepository {
  Future<List<AppNotification>> fetchNotifications();

  Future<int> fetchUnreadCount();

  Future<void> markAllRead();
}
