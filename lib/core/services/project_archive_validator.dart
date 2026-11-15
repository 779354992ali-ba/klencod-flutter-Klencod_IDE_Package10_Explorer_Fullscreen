/// Validation helpers for ZIP project import.
///
/// Limits protect the editor from malformed paths and oversized archives.
class ProjectArchiveValidator {
  ProjectArchiveValidator._();

  static const int maxEntries = 10000;
  static const int maxSingleFileBytes = 64 * 1024 * 1024;
  static const int maxTotalBytes = 256 * 1024 * 1024;

  static String normalizePath(String input) {
    if (input.isEmpty || input.contains('\u0000')) {
      throw FormatException('مسار فارغ أو يحتوي على محرف غير صالح');
    }
    final path = input.replaceAll('\\', '/');
    if (path.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(path)) {
      throw FormatException('المسارات المطلقة غير مسموحة داخل ZIP');
    }
    final parts = path.split('/');
    final meaningful = parts.where((part) => part.isNotEmpty).toList();
    if (meaningful.isEmpty || meaningful.any((part) => part == '.' || part == '..')) {
      throw FormatException('مسار غير آمن داخل ZIP');
    }
    return meaningful.join('/');
  }

  static void validateArchive({
    required int entryCount,
    required Iterable<MapEntry<String, int>> files,
  }) {
    if (entryCount == 0) throw FormatException('ملف ZIP فارغ');
    if (entryCount > maxEntries) {
      throw FormatException('الأرشيف يحتوي على عدد كبير جدًا من العناصر');
    }
    var total = 0;
    for (final file in files) {
      normalizePath(file.key);
      final size = file.value;
      if (size < 0 || size > maxSingleFileBytes) {
        throw FormatException('حجم ملف غير مسموح: ${file.key}');
      }
      total += size;
      if (total > maxTotalBytes) {
        throw FormatException('الحجم الإجمالي للأرشيف يتجاوز الحد المسموح');
      }
    }
  }
  /// Rejects duplicate file paths and file/directory prefix collisions.
  /// Directory entries are intentionally omitted by callers: implicit parent
  /// directories are valid, but a regular file cannot also be a parent path.
  static void validateFilePaths(Iterable<String> filePaths) {
    final paths = <String>{};
    final normalizedPaths = <String>[];
    for (final rawPath in filePaths) {
      final path = normalizePath(rawPath);
      if (!paths.add(path)) {
        throw FormatException('مسار مكرر داخل ZIP: $path');
      }
      normalizedPaths.add(path);
    }
    final files = paths;
    for (final path in normalizedPaths) {
      final parts = path.split('/');
      for (var i = 1; i < parts.length; i++) {
        final parent = parts.take(i).join('/');
        if (files.contains(parent)) {
          throw FormatException('تعارض ملف ومجلد داخل ZIP: $parent');
        }
      }
    }
  }

}

/// Tracks ZIP export resource limits while the SAF tree is being read.
/// Limits are enforced incrementally, before the full archive is assembled.
class ProjectArchiveBudget {
  int entryCount = 0;
  int totalBytes = 0;
  final Set<String> _registeredPaths = <String>{};

  void registerEntry(String rawPath, {required int byteCount}) {
    final path = ProjectArchiveValidator.normalizePath(rawPath);
    if (!_registeredPaths.add(path)) {
      throw FormatException('مسار مكرر أثناء تصدير المشروع: $path');
    }
    entryCount++;
    if (entryCount > ProjectArchiveValidator.maxEntries) {
      throw FormatException('المشروع يحتوي على عناصر أكثر من الحد المسموح للتصدير.');
    }
    if (byteCount < 0 || byteCount > ProjectArchiveValidator.maxSingleFileBytes) {
      throw FormatException('حجم الملف يتجاوز الحد المسموح للتصدير: $path');
    }
    totalBytes += byteCount;
    if (totalBytes > ProjectArchiveValidator.maxTotalBytes) {
      throw FormatException('الحجم الإجمالي للمشروع يتجاوز 256 ميجابايت.');
    }
  }
}
