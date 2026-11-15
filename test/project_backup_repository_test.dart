import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/project_backup_repository.dart';

void main() {
  const repository = ProjectBackupRepository();

  ProjectBackupSnapshot snapshot(String id, {int bytes = 10}) =>
      repository.createSnapshot(
        id: id,
        projectName: 'Demo',
        createdAt: DateTime.utc(2026, 1, 1),
        fileCount: 2,
        directoryCount: 1,
        totalBytes: bytes,
        manifestBytes: utf8.encode('manifest-$id'),
      );

  group('ProjectBackupRepository', () {
    test('round trips catalog and sorts newest first', () {
      final first = snapshot('snap_a');
      final second = repository.createSnapshot(
        id: 'snap_b', projectName: 'Demo',
        createdAt: DateTime.utc(2026, 2, 1), fileCount: 3,
        directoryCount: 2, totalBytes: 42,
        manifestBytes: utf8.encode('manifest-b'),
      );
      final encoded = repository.encodeCatalog([first, second]);
      final decoded = repository.decodeCatalog(encoded);
      expect(decoded.map((item) => item.id), ['snap_b', 'snap_a']);
      expect(decoded.first.totalBytes, 42);
    });

    test('rejects unsafe names, duplicate ids and unsupported catalog versions', () {
      expect(() => snapshot('../escape'), throwsArgumentError);
      expect(() => repository.encodeCatalog([snapshot('same'), snapshot('same')]),
          throwsFormatException);
      final source = jsonDecode(repository.encodeCatalog([snapshot('one')])) as Map<String, dynamic>;
      source['version'] = 99;
      expect(() => repository.decodeCatalog(jsonEncode(source)), throwsFormatException);
    });

    test('rejects a forged filename and duplicate catalog ids', () {
      final source = jsonDecode(repository.encodeCatalog([snapshot('one')])) as Map<String, dynamic>;
      final row = (source['snapshots'] as List).single as Map<String, dynamic>;
      row['fileName'] = '../other.json';
      expect(() => repository.decodeCatalog(jsonEncode(source)), throwsFormatException);
    });

    test('verifies immutable snapshot manifest bytes', () {
      final bytes = utf8.encode('immutable content');
      final item = repository.createSnapshot(
        id: 'snap_integrity', projectName: 'Demo',
        createdAt: DateTime.utc(2026), fileCount: 1,
        directoryCount: 0, totalBytes: bytes.length, manifestBytes: bytes,
      );
      expect(repository.verifyManifest(item, bytes), isTrue);
      expect(repository.verifyManifest(item, utf8.encode('tampered')), isFalse);
    });

    test('compares snapshot file sets and content checksums', () {
      final report = repository.compareFileChecksums(
        older: {'a.dart': '11111111', 'b.dart': '22222222', 'gone.txt': '33333333'},
        newer: {'a.dart': '11111111', 'b.dart': 'ffffffff', 'new.txt': '44444444'},
      );
      expect(report.added, ['new.txt']);
      expect(report.removed, ['gone.txt']);
      expect(report.changed, ['b.dart']);
      expect(report.unchanged, ['a.dart']);
    });

    test('enforces the snapshot retention limit', () {
      final snapshots = List.generate(
        ProjectBackupRepository.maxSnapshots + 1,
        (index) => snapshot('snap_$index'),
      );
      expect(() => repository.encodeCatalog(snapshots), throwsFormatException);
    });
  });
}
