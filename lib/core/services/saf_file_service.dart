
import 'dart:typed_data';

import 'package:saf/saf.dart';

class SafFileService {
  final Saf _saf = Saf();

  /// Validates a single Storage Access Framework child name.
  ///
  /// SAF accepts provider-specific names, but a path separator or a dot
  /// segment must never be treated as a child name by this service.
  static String validateChildName(String value) {
    final name = value.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(value, 'name', 'اسم الملف أو المجلد مطلوب.');
    }
    if (name == '.' || name == '..' ||
        name.contains('/') || name.contains('\\') ||
        name.contains('\u0000')) {
      throw ArgumentError.value(
        value,
        'name',
        'استخدم اسمًا واحدًا دون مسارات أو مقاطع نسبية.',
      );
    }
    if (RegExp(r'[<>:\"|?*]').hasMatch(name) ||
        name.endsWith('.') || name.endsWith(' ')) {
      throw ArgumentError.value(
        value,
        'name',
        'الاسم يحتوي محارف غير متوافقة مع أنظمة الملفات الشائعة.',
      );
    }
    final deviceName = name.split('.').first.toUpperCase();
    if (RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$')
        .hasMatch(deviceName)) {
      throw ArgumentError.value(
        value,
        'name',
        'هذا الاسم محجوز في أنظمة Windows.',
      );
    }
    return name;
  }

  /// Returns a useful MIME type for common source and document files.
  /// Unknown extensions intentionally fall back to binary data.
  static String mimeTypeForName(String fileName) {
    final normalized = fileName.toLowerCase();
    final dot = normalized.lastIndexOf('.');
    final extension = dot < 0 ? '' : normalized.substring(dot + 1);
    const types = <String, String>{
      'html': 'text/html', 'htm': 'text/html',
      'css': 'text/css', 'js': 'text/javascript',
      'mjs': 'text/javascript', 'json': 'application/json',
      'xml': 'application/xml', 'svg': 'image/svg+xml',
      'md': 'text/markdown', 'txt': 'text/plain',
      'dart': 'text/x-dart', 'py': 'text/x-python',
      'java': 'text/x-java-source', 'kt': 'text/x-kotlin',
      'yaml': 'application/yaml', 'yml': 'application/yaml',
      'pdf': 'application/pdf', 'png': 'image/png',
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
      // These extensions are frequently rewritten by Android document
      // providers when a text/* MIME type is supplied (for example .gradle
      // becoming .gradle.txt). Use a neutral MIME type and verify the name.
      'gradle': 'application/octet-stream',
      'properties': 'application/octet-stream',
      'bat': 'application/octet-stream',
      'sh': 'application/octet-stream',
    };
    return types[extension] ?? 'application/octet-stream';
  }

  // اختيار مجلد المشروع
  Future<SafDocumentFile?> pickProjectFolder() async {
    return _saf.pickDirectory(
      writePermission: true,
      persistablePermission: true,
    );
  }

  // اختيار ملف
  Future<SafDocumentFile?> pickFile() async {
    return _saf.pickFile(
      persistablePermission: true,
    );
  }

  // استرجاع جميع صلاحيات SAF المحفوظة
  Future<List<SafPersistedPermission>>
      getPersistedPermissions() async {
    return _saf.persistedPermissions();
  }

  // عرض محتويات مجلد
  Future<List<SafDocumentFile>> listDirectory(
    String directoryUri,
  ) async {
    return _saf.list(directoryUri);
  }

  // قراءة ملف
  Future<Uint8List> readFile(String fileUri) async {
    return _saf.readFileBytes(fileUri);
  }

  // حفظ ملف
  Future<SafDocumentFile> saveFile({
    required String parentUri,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    bool overwrite = true,
  }) async {
    final safeName = validateChildName(fileName);
    final extension = safeName.toLowerCase().split('.').last;
    const extensionSensitive = <String>{
      'gradle', 'properties', 'bat', 'sh',
    };

    // Never let a caller's generic text/plain MIME override the neutral
    // type for extensions that Android providers commonly rewrite.
    final effectiveMimeType = extensionSensitive.contains(extension)
        ? 'application/octet-stream'
        : (mimeType ?? mimeTypeForName(safeName));

    var saved = await _saf.writeFileBytes(
      parentUri,
      safeName,
      effectiveMimeType,
      bytes,
      overwrite: overwrite,
    );

    // Some SAF providers silently append an extension based on MIME type.
    // Repair the returned document name immediately so the project tree
    // contains the exact requested path, or fail visibly instead of
    // reporting a successful save under a different filename.
    if (!saved.isDir && saved.name != safeName) {
      saved = await _saf.rename(saved.uri, safeName);
      if (saved.name != safeName) {
        throw StateError(
          'تعذر حفظ الملف بالاسم الصحيح "$safeName"؛ '
          'قام مزود التخزين بإرجاع "${saved.name}".',
        );
      }
    }
    return saved;
  }

  // إنشاء مجلد
  Future<SafDocumentFile> createFolder({
    required String parentUri,
    required String folderName,
  }) async {
    return _saf.mkdirp(
      parentUri,
      [validateChildName(folderName)],
    );
  }

  // حذف ملف أو مجلد واحد.
  Future<void> deleteItem(String uri) async {
    await _saf.delete(uri);
  }

  /// Deletes a complete SAF subtree from leaves to root.
  /// Intended for rollback of a directory created by the current operation.
  Future<void> deleteTree(String rootUri, {int maxDepth = 64}) async {
    final visited = <String>{};

    Future<void> remove(String uri, int depth) async {
      if (depth > maxDepth) {
        throw StateError('تجاوز عمق المجلد الحد المسموح أثناء التنظيف.');
      }
      if (!visited.add(uri)) {
        throw StateError('تم اكتشاف تكرار URI أثناء تنظيف مجلد المشروع.');
      }
      final item = await getItem(uri);
      if (item == null) return;
      if (item.isDir) {
        final children = await listDirectory(uri);
        for (final child in children) {
          await remove(child.uri, depth + 1);
        }
      }
      await deleteItem(uri);
    }

    await remove(rootUri, 0);
  }

  // إعادة تسمية
  Future<SafDocumentFile> renameItem({
    required String uri,
    required String newName,
  }) async {
    return _saf.rename(uri, validateChildName(newName));
  }

  // البحث عن عنصر داخل مجلد
  Future<SafDocumentFile?> findChild({
    required String parentUri,
    required String name,
  }) async {
    return _saf.child(
      parentUri,
      [validateChildName(name)],
    );
  }

  // الحصول على معلومات ملف أو مجلد
  Future<SafDocumentFile?> getItem(String uri) async {
    return _saf.stat(uri);
  }
}