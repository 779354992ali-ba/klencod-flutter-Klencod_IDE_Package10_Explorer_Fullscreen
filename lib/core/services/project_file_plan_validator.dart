import 'dart:convert';

/// Preflights a generated project before any SAF directory or file is created.
///
/// Paths are checked for traversal, portable filename rules, collisions across
/// case-insensitive file systems, file/directory conflicts and payload limits.
class ProjectFilePlanValidator {
  ProjectFilePlanValidator._();

  static const int maxFiles = 10000;
  static const int maxSingleFileBytes = 16 * 1024 * 1024;
  static const int maxTotalBytes = 64 * 1024 * 1024;

  static void validate({
    required Map<String, String> files,
    required String entryFile,
  }) {
    if (files.isEmpty) {
      throw const FormatException('لا توجد ملفات لإنشاء المشروع.');
    }
    if (files.length > maxFiles) {
      throw const FormatException('عدد ملفات المشروع يتجاوز الحد المسموح.');
    }

    final normalized = <String>[];
    final portableNames = <String, String>{};
    final portableDirectories = <String, String>{};
    var totalBytes = 0;

    for (final entry in files.entries) {
      final path = _normalizeRelativePath(entry.key);
      normalized.add(path);

      // Git checkouts and common development machines may use a
      // case-insensitive file system even when Android's provider does not.
      final portableKey = path.toLowerCase();
      final previousSpelling = portableNames[portableKey];
      if (previousSpelling != null) {
        throw FormatException(
          'مساران يتعارضان عند التشغيل على أنظمة الملفات غير الحساسة لحالة الأحرف: '
          '$previousSpelling و $path',
        );
      }
      portableNames[portableKey] = path;

      final segments = path.split('/');
      for (var i = 1; i < segments.length; i++) {
        final directory = segments.take(i).join('/');
        final directoryKey = directory.toLowerCase();
        final previousDirectory = portableDirectories[directoryKey];
        if (previousDirectory != null && previousDirectory != directory) {
          throw FormatException(
            'مسارا مجلدين يختلفان في حالة الأحرف فقط: '
            '$previousDirectory و $directory',
          );
        }
        portableDirectories[directoryKey] = directory;
      }

      final bytes = utf8.encode(entry.value).length;
      if (bytes > maxSingleFileBytes) {
        throw FormatException('حجم الملف يتجاوز الحد المسموح: $path');
      }
      totalBytes += bytes;
      if (totalBytes > maxTotalBytes) {
        throw const FormatException(
          'الحجم الإجمالي لملفات المشروع يتجاوز الحد المسموح.',
        );
      }
    }

    final unique = normalized.map((path) => path.toLowerCase()).toSet();
    for (final directory in portableDirectories.keys) {
      if (unique.contains(directory)) {
        throw FormatException(
          'تعارض بين ملف ومجلد في مسار المشروع: $directory',
        );
      }
    }
    for (final path in normalized) {
      final segments = path.split('/');
      for (var i = 1; i < segments.length; i++) {
        final parent = segments.take(i).join('/');
        if (unique.contains(parent.toLowerCase())) {
          throw FormatException(
            'تعارض بين ملف ومجلد في مسار المشروع: $parent',
          );
        }
      }
    }

    final normalizedEntry = _normalizeRelativePath(entryFile);
    if (!unique.contains(normalizedEntry.toLowerCase())) {
      throw FormatException(
        'ملف البداية غير موجود ضمن ملفات المشروع: $normalizedEntry',
      );
    }
  }

  static String _normalizeRelativePath(String rawPath) {
    if (rawPath.isEmpty ||
        rawPath.startsWith('/') ||
        rawPath.startsWith('\\') ||
        rawPath.contains('\\') ||
        rawPath.contains('\u0000')) {
      throw FormatException('مسار ملف غير صالح: $rawPath');
    }

    final segments = rawPath.split('/');
    if (segments.any((segment) =>
        segment.isEmpty || segment == '.' || segment == '..')) {
      throw FormatException('مسار ملف غير آمن: $rawPath');
    }
    if (RegExp(r'^[A-Za-z]:').hasMatch(segments.first)) {
      throw FormatException('المسارات المطلقة غير مسموحة: $rawPath');
    }

    for (final segment in segments) {
      if (RegExp(r'[<>:"|?*]').hasMatch(segment) ||
          segment.endsWith('.') ||
          segment.endsWith(' ')) {
        throw FormatException(
          'اسم ملف غير متوافق مع أنظمة الملفات الشائعة: $rawPath',
        );
      }
      final deviceName = segment.split('.').first.toUpperCase();
      if (RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$')
          .hasMatch(deviceName)) {
        throw FormatException('اسم محجوز في أنظمة Windows: $rawPath');
      }
    }
    return segments.join('/');
  }
}
