import 'package:equatable/equatable.dart';

class Confession extends Equatable {
  const Confession({
    required this.id,
    required this.content,
    required this.isOwner,
    required this.createdAt,
    this.sharedWithId,
  });

  final String id;
  final String content;
  final bool isOwner;
  final DateTime? createdAt;
  final String? sharedWithId;

  bool get isShared => sharedWithId != null;

  @override
  List<Object?> get props =>
      <Object?>[id, content, isOwner, createdAt, sharedWithId];
}

abstract class ConfessionRepository {
  Future<List<Confession>> fetchConfessions();

  Future<void> create(String content);

  Future<void> updateContent({required String id, required String content});

  Future<void> share({required String id, required String? userId});

  Future<void> delete(String id);
}
