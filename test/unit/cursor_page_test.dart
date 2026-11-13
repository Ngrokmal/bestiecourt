import 'package:flutter_test/flutter_test.dart';
import 'package:roast_my_bestie/core/config/app_config.dart';
import 'package:roast_my_bestie/core/pagination/cursor_page.dart';

void main() {
  group('CursorPageRequest', () {
    test('defaults to the configured page size', () {
      const CursorPageRequest request = CursorPageRequest();
      expect(request.limit, AppConfig.defaultPageSize);
    });

    test('clamps oversized limits to the hard maximum', () {
      const CursorPageRequest request = CursorPageRequest(requestedLimit: 5000);
      expect(request.limit, AppConfig.maxPageSize);
    });

    test('clamps zero/negative limits to 1', () {
      expect(const CursorPageRequest(requestedLimit: 0).limit, 1);
      expect(const CursorPageRequest(requestedLimit: -9).limit, 1);
    });
  });

  group('KeysetCursor', () {
    test('equality is based on timestamp + id tie-breaker', () {
      const KeysetCursor a = KeysetCursor(
        createdAtIso: '2026-11-13T05:00:00Z',
        id: 'aaa',
      );
      const KeysetCursor b = KeysetCursor(
        createdAtIso: '2026-11-13T05:00:00Z',
        id: 'aaa',
      );
      expect(a, b);
    });
  });
}
