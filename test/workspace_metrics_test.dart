import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/workspace_metrics.dart';

void main() {
  group('WorkspaceMetrics', () {
    test('counts multiple sources without scanning disk', () {
      final result = WorkspaceMetrics.fromSources([
        'void main() {\n  print("Hi");\n}',
        'hello world',
      ]);

      expect(result.fileCount, 2);
      expect(result.lineCount, 4);
      expect(result.wordCount, 7);
      expect(result.characterCount, 41);
    });

    test('counts an empty source as one editable line', () {
      final result = WorkspaceMetrics.fromSources(['']);

      expect(result.fileCount, 1);
      expect(result.lineCount, 1);
      expect(result.wordCount, 0);
      expect(result.characterCount, 0);
    });

    test('handles no open tabs', () {
      final result = WorkspaceMetrics.fromSources(const []);

      expect(result.fileCount, 0);
      expect(result.lineCount, 0);
      expect(result.wordCount, 0);
      expect(result.characterCount, 0);
    });
  });
}
