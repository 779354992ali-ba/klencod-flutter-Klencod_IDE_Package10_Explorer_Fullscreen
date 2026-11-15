import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/project_backup_service.dart';

void main() {
  const service = ProjectBackupService();

  group('ProjectBackupService', () {
    test('round trips binary files, unicode paths and empty directories', () {
      final encoded = service.encode(
        projectName: 'تطبيقي',
        files: {'lib/main.dart': utf8.encode('void main() {}'), 'assets/raw.bin': [0, 1, 2, 255]},
        directories: ['assets/empty'],
        createdAt: DateTime.utc(2026, 1, 2),
      );
      final backup = service.decode(encoded);
      expect(backup.projectName, 'تطبيقي');
      expect(backup.files['assets/raw.bin']!.bytes, [0, 1, 2, 255]);
      expect(backup.directories, ['assets/empty']);
      expect(backup.totalBytes, 18);
    });

    test('rejects path traversal, absolute paths and case collisions', () {
      expect(() => service.encode(projectName: 'x', files: {'../escape': [1]}), throwsFormatException);
      expect(() => service.encode(projectName: 'x', files: {'/absolute': [1]}), throwsFormatException);
      expect(() => service.encode(projectName: 'x', files: {'Lib/a.dart': [1], 'lib/A.dart': [2]}), throwsFormatException);
    });

    test('detects modified base64 payload using per-file checksum', () {
      final map = jsonDecode(service.encode(projectName: 'x', files: {'a.txt': [1, 2, 3]})) as Map<String, dynamic>;
      final file = (map['files'] as List).single as Map<String, dynamic>;
      file['content'] = base64Encode([9, 9, 9]);
      expect(() => service.decode(jsonEncode(map)), throwsFormatException);
    });

    test('rejects unsupported format versions and malformed manifests', () {
      expect(() => service.decode('{"format":"other"}'), throwsFormatException);
      final encoded = service.encode(projectName: 'x', files: {'a': [1]});
      final map = jsonDecode(encoded) as Map<String, dynamic>;
      map['version'] = 999;
      expect(() => service.decode(jsonEncode(map)), throwsFormatException);
    });

    test('rejects case-only directory collisions and non-portable names', () {
      expect(() => service.encode(projectName: 'x', files: {
        'Lib/a.dart': [1], 'lib/b.dart': [2],
      }), throwsFormatException);
      expect(() => service.encode(projectName: 'x', files: {'CON.txt': [1]}),
          throwsFormatException);
      expect(() => service.encode(projectName: 'x', files: {'trailing./file': [1]}),
          throwsFormatException);
    });

    test('rejects file-directory prefix conflicts', () {
      expect(() => service.encode(projectName: 'x', files: {'src': [1]}, directories: ['src/nested']), throwsFormatException);
      expect(() => service.encode(projectName: 'x', files: {'same': [1]}, directories: ['same']), throwsFormatException);
      expect(() => service.encode(projectName: 'x', files: {'folder': [1], 'folder/file': [2]}), throwsFormatException);
    });
  });
}
