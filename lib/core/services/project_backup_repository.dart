import 'dart:convert';

/// Metadata for one immutable backup snapshot stored beside a SAF project.
class ProjectBackupSnapshot {
  final String id;
  final String fileName;
  final String projectName;
  final DateTime createdAt;
  final int fileCount;
  final int directoryCount;
  final int totalBytes;
  final String checksum;

  const ProjectBackupSnapshot({
    required this.id,
    required this.fileName,
    required this.projectName,
    required this.createdAt,
    required this.fileCount,
    required this.directoryCount,
    required this.totalBytes,
    required this.checksum,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'fileName': fileName,
    'projectName': projectName,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'fileCount': fileCount,
    'directoryCount': directoryCount,
    'totalBytes': totalBytes,
    'checksum': checksum,
  };
}

class ProjectBackupRepository {
  const ProjectBackupRepository();

  static const int schemaVersion = 1;
  static const int maxSnapshots = 20;
  static const String directoryName = '.bisho-backups';
  static const String catalogFileName = 'catalog.json';

  List<ProjectBackupSnapshot> decodeCatalog(String source) {
    final Object? value;
    try {
      value = jsonDecode(source);
    } catch (_) {
      throw const FormatException('فهرس النسخ الاحتياطية تالف أو ليس JSON صالحًا.');
    }
    if (value is! Map<String, dynamic> ||
        value['format'] != 'bisho-backup-catalog' ||
        value['version'] != schemaVersion || value['snapshots'] is! List) {
      throw const FormatException('صيغة فهرس النسخ الاحتياطية غير مدعومة.');
    }
    final snapshots = <ProjectBackupSnapshot>[];
    final ids = <String>{};
    final names = <String>{};
    for (final item in value['snapshots'] as List) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('سجل نسخة احتياطية غير صالح.');
      }
      final id = item['id'];
      final fileName = item['fileName'];
      final projectName = item['projectName'];
      final createdAt = item['createdAt'];
      final fileCount = item['fileCount'];
      final directoryCount = item['directoryCount'];
      final totalBytes = item['totalBytes'];
      final checksum = item['checksum'];
      if (id is! String || !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id) ||
          fileName is! String || fileName != '$id.json' ||
          projectName is! String || createdAt is! String ||
          fileCount is! int || fileCount < 0 || directoryCount is! int || directoryCount < 0 ||
          totalBytes is! int || totalBytes < 0 || checksum is! String ||
          !RegExp(r'^[0-9a-f]{8}$').hasMatch(checksum)) {
        throw const FormatException('بيانات سجل النسخة غير مكتملة أو غير آمنة.');
      }
      final date = DateTime.tryParse(createdAt);
      if (date == null || !ids.add(id) || !names.add(fileName)) {
        throw const FormatException('تاريخ أو معرّف نسخة مكرر/غير صالح.');
      }
      snapshots.add(ProjectBackupSnapshot(
        id: id, fileName: fileName, projectName: projectName,
        createdAt: date, fileCount: fileCount, directoryCount: directoryCount,
        totalBytes: totalBytes, checksum: checksum,
      ));
    }
    if (snapshots.length > maxSnapshots) {
      throw const FormatException('الفهرس يتجاوز الحد الأقصى لعدد النسخ.');
    }
    snapshots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(snapshots);
  }

  String encodeCatalog(Iterable<ProjectBackupSnapshot> snapshots) {
    final ordered = snapshots.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (ordered.length > maxSnapshots) {
      throw const FormatException('لا يمكن حفظ أكثر من 20 نسخة في الفهرس.');
    }
    final ids = <String>{};
    for (final snapshot in ordered) {
      if (!ids.add(snapshot.id) || snapshot.fileName != '${snapshot.id}.json' ||
          !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(snapshot.id)) {
        throw const FormatException('معرّف أو اسم ملف نسخة مكرر/غير آمن.');
      }
    }
    return jsonEncode({
      'format': 'bisho-backup-catalog',
      'version': schemaVersion,
      'snapshots': ordered.map((item) => item.toJson()).toList(),
    });
  }

  ProjectBackupSnapshot createSnapshot({
    required String id,
    required String projectName,
    required DateTime createdAt,
    required int fileCount,
    required int directoryCount,
    required int totalBytes,
    required List<int> manifestBytes,
  }) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'معرّف النسخة غير آمن.');
    }
    return ProjectBackupSnapshot(
      id: id, fileName: '$id.json', projectName: projectName,
      createdAt: createdAt, fileCount: fileCount, directoryCount: directoryCount,
      totalBytes: totalBytes, checksum: checksum(manifestBytes),
    );
  }

  bool verifyManifest(ProjectBackupSnapshot snapshot, List<int> bytes) =>
      checksum(bytes) == snapshot.checksum;

  ProjectBackupComparison compareFileChecksums({
    required Map<String, String> older,
    required Map<String, String> newer,
  }) {
    final oldPaths = older.keys.toSet();
    final newPaths = newer.keys.toSet();
    final added = newPaths.difference(oldPaths).toList()..sort();
    final removed = oldPaths.difference(newPaths).toList()..sort();
    final shared = oldPaths.intersection(newPaths);
    final changed = shared.where((path) => older[path] != newer[path]).toList()..sort();
    final unchanged = shared.where((path) => older[path] == newer[path]).toList()..sort();
    return ProjectBackupComparison(
      added: List.unmodifiable(added), removed: List.unmodifiable(removed),
      changed: List.unmodifiable(changed), unchanged: List.unmodifiable(unchanged),
    );
  }

  /// FNV-1a 32-bit detects accidental corruption; it is not cryptographic.
  String checksum(List<int> bytes) {
    const mask = 0xFFFFFFFF;
    var hash = 0x811C9DC5;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & mask;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class ProjectBackupComparison {
  final List<String> added;
  final List<String> removed;
  final List<String> changed;
  final List<String> unchanged;

  const ProjectBackupComparison({required this.added, required this.removed,
    required this.changed, required this.unchanged});
}
