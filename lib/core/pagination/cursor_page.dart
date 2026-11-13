import 'package:equatable/equatable.dart';
import 'package:roast_my_bestie/core/config/app_config.dart';

/// Deterministic keyset cursor using (createdAt, id) tie-breaker.
/// Prevents duplicate or skipped records on rapidly changing feeds.
class KeysetCursor extends Equatable {
  const KeysetCursor({
    required this.createdAtIso,
    required this.id,
  });

  final String createdAtIso;
  final String id;

  @override
  List<Object?> get props => <Object?>[createdAtIso, id];
}

/// Standardized paginated request with enforced page-size clamping.
class CursorPageRequest extends Equatable {
  const CursorPageRequest({
    this.cursor,
    int requestedLimit = AppConfig.defaultPageSize,
  }) : limit = requestedLimit < 1
            ? 1
            : (requestedLimit > AppConfig.maxPageSize
                ? AppConfig.maxPageSize
                : requestedLimit);

  final KeysetCursor? cursor;
  final int limit;

  @override
  List<Object?> get props => <Object?>[cursor, limit];
}

/// Immutable paginated response returned by repositories.
class CursorPage<T> extends Equatable {
  const CursorPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<T> items;
  final bool hasMore;
  final KeysetCursor? nextCursor;

  @override
  List<Object?> get props => <Object?>[items, hasMore, nextCursor];
}
