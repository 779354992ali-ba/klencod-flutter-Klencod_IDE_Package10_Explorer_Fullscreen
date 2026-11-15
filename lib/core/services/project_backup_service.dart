import 'dart:convert';

/// Versioned, self-contained project backup format with per-file integrity checks.
/// The service is storage-agnostic; callers provide SAF or local file bytes.
class ProjectBackupFile {
  final String path;
  final List<int> bytes;
  final String checksum;

  ProjectBackupFile({required this.path, required List<int> bytes, required this.checksum})
      : bytes = List.unmodifiable(bytes);
}

class ProjectBackup {
  static const int currentVersion = 1;
  final String projectName;
  final DateTime createdAt;
  final Map<String, ProjectBackupFile> files;
  final List<String> directories;

  ProjectBackup({required this.projectName, required this.createdAt,
    required Map<String, ProjectBackupFile> files, required Iterable<String> directories})
      : files = Map.unmodifiable(files),
        directories = List.unmodifiable(directories);

  int get totalBytes => files.values.fold(0, (sum, file) => sum + file.bytes.length);
}

class ProjectBackupService {
  const ProjectBackupService();

  static const int maxEntries = 10000;
  static const int maxFileBytes = 64 * 1024 * 1024;
  static const int maxTotalBytes = 256 * 1024 * 1024;
  static const int maxManifestBytes = 384 * 1024 * 1024;

  String encode({required String projectName, required Map<String, List<int>> files,
      Iterable<String> directories = const [], DateTime? createdAt}) {
    final backup = _build(projectName: projectName, files: files,
        directories: directories, createdAt: createdAt ?? DateTime.now());
    final payload = <String, Object?>{
      'format': 'bisho-project-backup',
      'version': ProjectBackup.currentVersion,
      'projectName': backup.projectName,
      'createdAt': backup.createdAt.toUtc().toIso8601String(),
      'directories': backup.directories,
      'files': backup.files.values.map((file) => <String, Object?>{
        'path': file.path,
        'bytes': file.bytes.length,
        'checksum': file.checksum,
        'content': base64Encode(file.bytes),
      }).toList(),
    };
    return jsonEncode(payload);
  }

  ProjectBackup decode(String source) {
    if (utf8.encode(source).length > maxManifestBytes) {
      throw const FormatException('حجم ملف النسخة الاحتياطية أكبر من الحد المسموح.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('ملف النسخة الاحتياطية ليس JSON صالحًا.');
    }
    if (decoded is! Map<String, dynamic> || decoded['format'] != 'bisho-project-backup') {
      throw const FormatException('صيغة ملف النسخة الاحتياطية غير معروفة.');
    }
    if (decoded['version'] != ProjectBackup.currentVersion) {
      throw FormatException('إصدار النسخة الاحتياطية غير مدعوم: ${decoded['version']}');
    }
    final name = decoded['projectName'];
    final dateText = decoded['createdAt'];
    final rawFiles = decoded['files'];
    final rawDirectories = decoded['directories'];
    if (name is! String || name.trim().isEmpty || dateText is! String ||
        rawFiles is! List || rawDirectories is! List) {
      throw const FormatException('بيانات النسخة الاحتياطية الأساسية ناقصة أو غير صالحة.');
    }
    final date = DateTime.tryParse(dateText);
    if (date == null) throw const FormatException('تاريخ النسخة الاحتياطية غير صالح.');

    final fileBytes = <String, List<int>>{};
    for (final item in rawFiles) {
      if (item is! Map<String, dynamic> || item['path'] is! String ||
          item['bytes'] is! int || item['checksum'] is! String || item['content'] is! String) {
        throw const FormatException('سجل ملف غير صالح داخل النسخة الاحتياطية.');
      }
      final path = _normalizePath(item['path'] as String);
      final List<int> bytes;
      try {
        bytes = base64Decode(item['content'] as String);
      } catch (_) {
        throw FormatException('محتوى الملف غير صالح: $path');
      }
      if (bytes.length != item['bytes']) throw FormatException('حجم الملف لا يطابق بياناته: $path');
      if (_checksum(bytes) != item['checksum']) throw FormatException('فشل التحقق من سلامة الملف: $path');
      if (fileBytes.containsKey(path)) throw FormatException('مسار ملف مكرر: $path');
      fileBytes[path] = bytes;
    }
    final dirs = <String>[];
    for (final item in rawDirectories) {
      if (item is! String) throw const FormatException('مسار مجلد غير صالح في النسخة الاحتياطية.');
      dirs.add(_normalizePath(item));
    }
    return _build(projectName: name, files: fileBytes, directories: dirs, createdAt: date);
  }

  ProjectBackup _build({required String projectName, required Map<String, List<int>> files,
      required Iterable<String> directories, required DateTime createdAt}) {
    final normalizedFiles = <String, ProjectBackupFile>{};
    final normalizedDirs = <String>{};
    var total = 0;
    for (final raw in directories) {
      final path = _normalizePath(raw);
      if (!normalizedDirs.add(path)) throw FormatException('مسار مجلد مكرر: $path');
    }
    for (final entry in files.entries) {
      final path = _normalizePath(entry.key);
      if (normalizedFiles.containsKey(path)) throw FormatException('مسار ملف مكرر: $path');
      if (entry.value.length > maxFileBytes) throw FormatException('الملف يتجاوز 64 ميجابايت: $path');
      total += entry.value.length;
      if (total > maxTotalBytes) throw const FormatException('الحجم الإجمالي للنسخة يتجاوز 256 ميجابايت.');
      normalizedFiles[path] = ProjectBackupFile(path: path, bytes: entry.value,
          checksum: _checksum(entry.value));
    }
    if (normalizedFiles.length + normalizedDirs.length > maxEntries) {
      throw const FormatException('عدد عناصر النسخة يتجاوز الحد المسموح.');
    }
    final all = <String>{...normalizedFiles.keys, ...normalizedDirs};
    for (final dir in normalizedDirs) {
      if (normalizedFiles.containsKey(dir)) throw FormatException('المسار مستخدم كملف ومجلد: $dir');
    }
    final folded = <String, String>{};
    for (final path in all) {
      final parts = path.split('/');
      for (var i = 1; i <= parts.length; i++) {
        final prefix = parts.take(i).join('/');
        final key = prefix.toLowerCase();
        final previous = folded[key];
        if (previous != null && previous != prefix) {
          throw FormatException('تعارض أسماء باختلاف حالة الأحرف: $previous و $prefix');
        }
        folded[key] = prefix;
        if (i < parts.length && normalizedFiles.containsKey(prefix)) {
          throw FormatException('تعارض ملف ومجلد: $prefix');
        }
      }
      for (final segment in parts) {
        if (segment.endsWith('.') || segment.endsWith(' ') ||
            RegExp(r'[<>:"|?*]').hasMatch(segment) ||
            RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$', caseSensitive: false).hasMatch(segment)) {
          throw FormatException('اسم ملف أو مجلد غير محمول: $segment');
        }
      }
    }
    return ProjectBackup(projectName: projectName.trim(), createdAt: createdAt,
      files: normalizedFiles, directories: normalizedDirs.toList()..sort());
  }

  String _normalizePath(String raw) {
    final path = raw.replaceAll('\\', '/').trim();
    if (path.isEmpty || path.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(path) || path.contains('\u0000')) {
      throw FormatException('مسار غير آمن في النسخة الاحتياطية: $raw');
    }
    final parts = path.split('/');
    if (parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw FormatException('المسار يحتوي على اجتياز للمجلدات: $raw');
    }
    return parts.join('/');
  }

  // FNV-1a 32-bit checksum detects accidental corruption; it is not cryptographic.
  String _checksum(List<int> bytes) {
    const mask = 0xFFFFFFFF;
    var hash = 0x811C9DC5;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & mask;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
