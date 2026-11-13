import 'package:equatable/equatable.dart';

enum PingKind { angry, sorry, reminder, tomato, slipper }

String pingKindCode(PingKind kind) {
  switch (kind) {
    case PingKind.angry:
      return 'angry';
    case PingKind.sorry:
      return 'sorry';
    case PingKind.reminder:
      return 'reminder';
    case PingKind.tomato:
      return 'tomato';
    case PingKind.slipper:
      return 'slipper';
  }
}

PingKind pingKindFromCode(String code) {
  switch (code) {
    case 'angry':
      return PingKind.angry;
    case 'sorry':
      return PingKind.sorry;
    case 'reminder':
      return PingKind.reminder;
    case 'tomato':
      return PingKind.tomato;
    default:
      return PingKind.slipper;
  }
}

String pingEmoji(PingKind kind) {
  switch (kind) {
    case PingKind.angry:
      return '😤';
    case PingKind.sorry:
      return '🥺';
    case PingKind.reminder:
      return '⏰';
    case PingKind.tomato:
      return '🍅';
    case PingKind.slipper:
      return '🩴';
  }
}

String pingLabel(PingKind kind) {
  switch (kind) {
    case PingKind.angry:
      return 'রাগ করে আছি';
    case PingKind.sorry:
      return 'সখ্যতা-প্রস্তাব';
    case PingKind.reminder:
      return 'মজার রিমাইন্ডার';
    case PingKind.tomato:
      return 'টমেটো মারা';
    case PingKind.slipper:
      return 'চপ্পল মারা';
  }
}

class SocialPing extends Equatable {
  const SocialPing({
    required this.id,
    required this.kind,
    required this.senderId,
    required this.senderName,
    required this.isIncoming,
    required this.createdAt,
    this.dismissedAt,
  });

  final String id;
  final PingKind kind;
  final String senderId;
  final String senderName;
  final bool isIncoming;
  final DateTime? createdAt;
  final DateTime? dismissedAt;

  bool get isDismissed => dismissedAt != null;

  @override
  List<Object?> get props =>
      <Object?>[id, kind, senderId, senderName, isIncoming, createdAt, dismissedAt];
}

abstract class SocialRepository {
  Future<List<SocialPing>> fetchPings();

  Future<void> send({required String recipientId, required PingKind kind});

  Future<void> dismiss(String pingId);

  Future<void> block({required String userId, required bool blocked});

  Future<void> report({
    required String userId,
    required String reason,
    String? note,
  });
}
