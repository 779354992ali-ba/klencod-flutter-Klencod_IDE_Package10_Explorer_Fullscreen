import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/project_text_diff.dart';

void main() {
  const diff = ProjectTextDiff();

  group('ProjectTextDiff', () {
    test('reports additions, removals and unchanged lines with line numbers', () {
      final report = diff.compare('alpha\nbeta\ngamma', 'alpha\nnew\ngamma');
      expect(report.addedCount, 1);
      expect(report.removedCount, 1);
      expect(report.unchangedCount, 2);
      expect(report.lines.first.oldLine, 1);
      expect(report.lines.first.newLine, 1);
      expect(report.lines[1].kind, TextDiffKind.removed);
      expect(report.lines[2].kind, TextDiffKind.added);
      expect(report.lines.last.oldLine, 3);
      expect(report.lines.last.newLine, 3);
    });

    test('normalizes Windows and classic Mac line endings', () {
      final report = diff.compare('a\r\nb\r', 'a\nb\n');
      expect(report.hasChanges, isFalse);
      expect(report.unchangedCount, 3);
    });

    test('handles empty input and identical text', () {
      expect(diff.compare('', '').lines, isEmpty);
      final same = diff.compare('one\ntwo', 'one\ntwo');
      expect(same.hasChanges, isFalse);
      expect(same.unchangedCount, 2);
    });

    test('uses bounded fallback for very large comparisons', () {
      final oldText = List<String>.generate(600, (i) => 'line-$i').join('\n');
      final newText = '$oldText\ninserted';
      final report = diff.compare(oldText, newText);
      expect(report.usedFallback, isTrue);
      expect(report.addedCount, 1);
      expect(report.removedCount, 0);
    });

    test('does not treat whitespace changes as equal', () {
      final report = diff.compare('value = 1;', 'value=1;');
      expect(report.addedCount, 1);
      expect(report.removedCount, 1);
    });

    test('exposes an immutable result line list', () {
      final report = diff.compare('before', 'after');
      expect(
        () => report.lines.add(
          const TextDiffLine(kind: TextDiffKind.added, text: 'extra'),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
