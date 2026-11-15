import 'dart:convert';

/// Deterministic in-memory snapshot and comparison for project files.
/// This is intentionally storage-agnostic so callers can feed SAF or local files.
class ProjectFileFingerprint {
  final String path;
  final int byteLength;
  final String contentHash;

  const ProjectFileFingerprint({required this.path, required this.byteLength,
    required this.contentHash});
}

enum ProjectChangeKind { added, modified, deleted, unchanged }

class ProjectFileChange {
  final String path;
  final ProjectChangeKind kind;
  final int beforeBytes;
  final int afterBytes;

  const ProjectFileChange({required this.path, required this.kind,
    this.beforeBytes = 0, this.afterBytes = 0});
}

class ProjectSnapshot {
  final Map<String, ProjectFileFingerprint> files;
  final DateTime createdAt;
  final String label;

  ProjectSnapshot({required Map<String, ProjectFileFingerprint> files,
    required this.createdAt, this.label = ''}) : files = Map.unmodifiable(files);

  int get totalBytes => files.values.fold(0, (sum, file) => sum + file.byteLength);
}

class ProjectChangeReport {
  final List<ProjectFileChange> changes;
  ProjectChangeReport(Iterable<ProjectFileChange> changes)
      : changes = List.unmodifiable(changes);

  int count(ProjectChangeKind kind) => changes.where((c) => c.kind == kind).length;
  int get changedCount => count(ProjectChangeKind.added) + count(ProjectChangeKind.modified) + count(ProjectChangeKind.deleted);
  int get addedCount => count(ProjectChangeKind.added);
  int get modifiedCount => count(ProjectChangeKind.modified);
  int get deletedCount => count(ProjectChangeKind.deleted);
}

class ProjectChangeTracker {
  const ProjectChangeTracker();

  ProjectSnapshot createSnapshot(Map<String, String> contents, {
    DateTime? createdAt, String label = ''}) {
    final files = <String, ProjectFileFingerprint>{};
    final caseFolded = <String, String>{};
    for (final entry in contents.entries) {
      final path = _safePath(entry.key);
      if (path == null) throw FormatException('مسار غير صالح في لقطة المشروع: ${entry.key}');
      if (files.containsKey(path)) throw FormatException('مسار مكرر في لقطة المشروع: $path');
      final parts = path.split('/');
      for (var i = 1; i <= parts.length; i++) {
        final prefix = parts.take(i).join('/');
        final key = prefix.toLowerCase();
        final previous = caseFolded[key];
        if (previous != null && previous != prefix) {
          throw FormatException('تعارض أسماء باختلاف حالة الأحرف: $previous و $prefix');
        }
        caseFolded[key] = prefix;
        if (i < parts.length && files.containsKey(prefix)) {
          throw FormatException('تعارض ملف ومجلد في لقطة المشروع: $prefix');
        }
      }
      final bytes = utf8.encode(entry.value);
      files[path] = ProjectFileFingerprint(path: path, byteLength: bytes.length,
          contentHash: _hash(bytes));
    }
    for (final path in files.keys) {
      final parts = path.split('/');
      for (var i = 1; i < parts.length; i++) {
        if (files.containsKey(parts.take(i).join('/'))) {
          throw FormatException('تعارض ملف ومجلد في لقطة المشروع: ${parts.take(i).join('/')}');
        }
      }
    }
    return ProjectSnapshot(files: files, createdAt: createdAt ?? DateTime.now(), label: label);
  }

  ProjectChangeReport compare(ProjectSnapshot before, ProjectSnapshot after) {
    final paths = <String>{...before.files.keys, ...after.files.keys}.toList()..sort();
    final changes = <ProjectFileChange>[];
    for (final path in paths) {
      final oldFile = before.files[path];
      final newFile = after.files[path];
      if (oldFile == null) {
        changes.add(ProjectFileChange(path: path, kind: ProjectChangeKind.added,
            afterBytes: newFile!.byteLength));
      } else if (newFile == null) {
        changes.add(ProjectFileChange(path: path, kind: ProjectChangeKind.deleted,
            beforeBytes: oldFile.byteLength));
      } else if (oldFile.contentHash != newFile.contentHash || oldFile.byteLength != newFile.byteLength) {
        changes.add(ProjectFileChange(path: path, kind: ProjectChangeKind.modified,
            beforeBytes: oldFile.byteLength, afterBytes: newFile.byteLength));
      } else {
        changes.add(ProjectFileChange(path: path, kind: ProjectChangeKind.unchanged,
            beforeBytes: oldFile.byteLength, afterBytes: newFile.byteLength));
      }
    }
    return ProjectChangeReport(changes);
  }

  String? _safePath(String raw) {
    final path = raw.replaceAll('\\', '/').trim();
    if (path.isEmpty || path.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(path) ||
        path.contains('\u0000')) return null;
    final segments = path.split('/');
    if (segments.any((s) => s.isEmpty || s == '.' || s == '..')) return null;
    return segments.join('/');
  }

  // FNV-1a 32-bit: deterministic and dependency-free; not a cryptographic hash.
  String _hash(List<int> bytes) {
    const mask = 0xFFFFFFFF;
    var hash = 0x811C9DC5;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & mask;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
