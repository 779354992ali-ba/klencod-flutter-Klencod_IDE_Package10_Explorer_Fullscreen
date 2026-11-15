import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/preview_project_guard.dart';

void main() {
  group('PreviewProjectGuard', () {
    test('accepts entries within depth and count limits', () {
      final guard = PreviewProjectGuard(maxDepth: 2, maxEntries: 2);
      guard.registerEntry();
      guard.checkDepth(2);
      guard.registerEntry();
      expect(guard.entries, 2);
    });

    test('rejects excessive directory depth and entry count', () {
      final depthGuard = PreviewProjectGuard(maxDepth: 1);
      expect(() => depthGuard.checkDepth(2), throwsStateError);

      final countGuard = PreviewProjectGuard(maxEntries: 1);
      countGuard.registerEntry();
      expect(() => countGuard.registerEntry(), throwsStateError);
    });

    test('enforces per-file and aggregate byte limits', () {
      final guard = PreviewProjectGuard(
        maxFileBytes: 8,
        maxTotalBytes: 10,
      );
      guard.registerFileBytes(6);
      expect(guard.totalBytes, 6);
      expect(() => guard.registerFileBytes(9), throwsStateError);
      expect(() => guard.registerFileBytes(5), throwsStateError);
    });

    test('rejects negative byte counts', () {
      final guard = PreviewProjectGuard();
      expect(() => guard.registerFileBytes(-1), throwsArgumentError);
    });
  });
}
