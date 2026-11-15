import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/project_change_tracker.dart';

void main() {
  const tracker = ProjectChangeTracker();

  group('ProjectChangeTracker', () {
    test('classifies added, modified, deleted and unchanged files', () {
      final before = tracker.createSnapshot({
        'lib/main.dart': 'void main() {}',
        'README.md': 'old',
        'assets/logo.txt': 'same',
      });
      final after = tracker.createSnapshot({
        'lib/main.dart': 'void main() { print(1); }',
        'assets/logo.txt': 'same',
        'test/new_test.dart': 'test',
      });
      final report = tracker.compare(before, after);
      expect(report.addedCount, 1);
      expect(report.modifiedCount, 1);
      expect(report.deletedCount, 1);
      expect(report.count(ProjectChangeKind.unchanged), 1);
      expect(report.changedCount, 3);
    });

    test('produces deterministic hashes and UTF-8 byte lengths', () {
      final one = tracker.createSnapshot({'مرحبا.txt': 'مرحبا'});
      final two = tracker.createSnapshot({'مرحبا.txt': 'مرحبا'});
      expect(one.files['مرحبا.txt']!.contentHash, two.files['مرحبا.txt']!.contentHash);
      expect(one.files['مرحبا.txt']!.byteLength, 10);
    });

    test('rejects traversal, absolute and duplicate paths', () {
      expect(() => tracker.createSnapshot({'../secret': 'x'}), throwsFormatException);
      expect(() => tracker.createSnapshot({'/root/file': 'x'}), throwsFormatException);
      expect(() => tracker.createSnapshot({'a\\b': 'x', 'a/b': 'y'}), throwsFormatException);
    });

    test('rejects case-folded collisions and file-directory prefix conflicts', () {
      expect(() => tracker.createSnapshot({'Lib/a.dart': 'a', 'lib/b.dart': 'b'}),
          throwsFormatException);
      expect(() => tracker.createSnapshot({'assets': 'file', 'assets/logo.png': 'image'}),
          throwsFormatException);
    });

    test('empty snapshots compare without changes', () {
      final empty = tracker.createSnapshot(const {});
      expect(tracker.compare(empty, empty).changes, isEmpty);
    });
  });
}
