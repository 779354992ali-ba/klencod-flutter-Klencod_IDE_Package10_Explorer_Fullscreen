import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saf/saf.dart';

import '../../core/services/saf_file_service.dart';

/// A project-scoped command interpreter backed by Android Storage Access Framework.
/// It intentionally does not execute arbitrary operating-system processes.
class BishoTerminalPanel extends StatefulWidget {
  final SafFileService files;
  final String? projectUri;
  final String projectName;
  final Future<void> Function(SafDocumentFile file, String parentUri) onOpenFile;

  const BishoTerminalPanel({
    super.key,
    required this.files,
    required this.projectUri,
    required this.projectName,
    required this.onOpenFile,
  });

  @override
  State<BishoTerminalPanel> createState() => _BishoTerminalPanelState();
}

class _TerminalLine {
  final String text;
  final Color color;
  const _TerminalLine(this.text, this.color);
}

class _ResolvedPath {
  final SafDocumentFile item;
  final String parentUri;
  const _ResolvedPath(this.item, this.parentUri);
}

class _BishoTerminalPanelState extends State<BishoTerminalPanel> {
  static const Color _green = Color(0xFF86EFAC);
  static const Color _cyan = Color(0xFF7DD3FC);
  static const Color _red = Color(0xFFFCA5A5);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _yellow = Color(0xFFFDE68A);

  static const List<String> _commands = [
    'help', 'pwd', 'ls', 'cd', 'tree', 'cat', 'head', 'tail', 'grep',
    'find', 'wc', 'stat', 'mkdir', 'touch', 'echo', 'write', 'append',
    'cp', 'mv', 'rename', 'rm', 'open', 'history', 'project', 'date',
    'whoami', 'clear',
  ];

  final TextEditingController _commandController = TextEditingController();
  final FocusNode _commandFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<_TerminalLine> _output = [];
  final List<String> _history = [];
  final List<String> _directoryNames = [];
  String? _currentUri;
  bool _busy = false;
  int _historyIndex = 0;

  @override
  void initState() {
    super.initState();
    _resetDirectory();
    _write('Bisho Advanced Terminal · اكتب help لعرض الأوامر', _cyan);
    _write('المجلد: ${widget.projectName}', _muted);
  }

  @override
  void didUpdateWidget(covariant BishoTerminalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectUri != widget.projectUri) {
      _resetDirectory();
      _write('تم تغيير المشروع إلى ${widget.projectName}', _cyan);
    }
  }

  void _resetDirectory() {
    _currentUri = widget.projectUri;
    _directoryNames.clear();
  }

  @override
  void dispose() {
    _commandController.dispose();
    _commandFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _path =>
      '/${_directoryNames.join('/')}${_directoryNames.isEmpty ? '' : ''}';

  void _write(String text, [Color color = Colors.white70]) {
    if (!mounted) return;
    setState(() {
      _output.add(_TerminalLine(text, color));
      if (_output.length > 600) {
        _output.removeRange(0, _output.length - 600);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  List<String> _parse(String input) {
    final result = <String>[];
    final buffer = StringBuffer();
    String? quote;
    var escaped = false;
    var tokenStarted = false;

    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      if (escaped) {
        buffer.write(char);
        escaped = false;
        tokenStarted = true;
        continue;
      }
      if (char == '\\' && quote != null) {
        escaped = true;
        continue;
      }
      if (quote != null) {
        if (char == quote) {
          quote = null;
        } else {
          buffer.write(char);
        }
        tokenStarted = true;
        continue;
      }
      if (char == '"' || char == "'") {
        quote = char;
        tokenStarted = true;
      } else if (RegExp(r'\s').hasMatch(char)) {
        if (tokenStarted) {
          result.add(buffer.toString());
          buffer.clear();
          tokenStarted = false;
        }
      } else {
        buffer.write(char);
        tokenStarted = true;
      }
    }
    if (quote != null) throw const FormatException('علامة اقتباس غير مغلقة.');
    if (escaped) buffer.write('\\');
    if (tokenStarted) result.add(buffer.toString());
    return result;
  }

  Future<SafDocumentFile?> _child(String parentUri, String name) =>
      widget.files.findChild(parentUri: parentUri, name: name);

  Future<_ResolvedPath?> _resolveItem(String input) async {
    final rootUri = widget.projectUri;
    if (rootUri == null) return null;

    final normalizedInput = input.replaceAll('\\', '/');
    final parts = normalizedInput.startsWith('/')
        ? <String>[]
        : List<String>.from(_directoryNames);
    for (final part in normalizedInput.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else {
        parts.add(part);
      }
    }

    var parentUri = rootUri;
    SafDocumentFile? current;
    for (var i = 0; i < parts.length; i++) {
      current = await _child(parentUri, parts[i]);
      if (current == null) return null;
      if (i < parts.length - 1) {
        if (!current.isDir) return null;
        parentUri = current.uri;
      }
    }
    if (current == null) {
      current = await widget.files.getItem(rootUri);
      if (current == null) return null;
      return _ResolvedPath(current, rootUri);
    }
    return _ResolvedPath(current, parentUri);
  }

  Future<_ResolvedPath?> _resolveParent(String input) async {
    final normalized = input.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    final parentPath = index < 0 ? '.' : normalized.substring(0, index);
    final name = index < 0 ? normalized : normalized.substring(index + 1);
    if (name.isEmpty || name == '.' || name == '..') {
      throw const FormatException('اسم الوجهة غير صالح.');
    }
    final parent = await _resolveItem(parentPath.isEmpty ? '/' : parentPath);
    if (parent == null || !parent.item.isDir) return null;
    return _ResolvedPath(
      // This placeholder is never used as the destination document.
      parent.item,
      parent.item.uri,
    );
  }

  Future<String?> _resolveDirectory(String input) async {
    final resolved = await _resolveItem(input);
    if (resolved == null || !resolved.item.isDir) return null;
    if (input.startsWith('/')) {
      _directoryNames.clear();
    }
    final normalizedInput = input.replaceAll('\\', '/');
    final parts = normalizedInput.startsWith('/')
        ? <String>[]
        : List<String>.from(_directoryNames);
    for (final part in normalizedInput.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else {
        parts.add(part);
      }
    }
    _directoryNames
      ..clear()
      ..addAll(parts);
    _currentUri = resolved.item.uri;
    return _currentUri;
  }

  Future<void> _list(String path, {bool all = false, bool long = false}) async {
    final resolved = await _resolveItem(path);
    if (resolved == null || !resolved.item.isDir) {
      _write('المجلد غير موجود: $path', _red);
      return;
    }
    final items = await widget.files.listDirectory(resolved.item.uri);
    items.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    if (items.isEmpty) {
      _write('(المجلد فارغ)', _muted);
      return;
    }
    for (final item in items) {
      if (!all && item.name.startsWith('.')) continue;
      _write(
        long
            ? '${item.isDir ? 'DIR ' : 'FILE'}  ${item.name}  ${item.uri}'
            : '${item.isDir ? '📁 ' : '📄 '}${item.name}${item.isDir ? '/' : ''}',
        item.isDir ? _cyan : Colors.white70,
      );
    }
  }

  Future<void> _tree(
    String uri,
    String prefix, {
    int depth = 0,
    int maxDepth = 6,
    int maxItems = 250,
    required List<int> count,
  }) async {
    if (depth >= maxDepth || count.first >= maxItems) {
      _write('$prefix… تم إيقاف العرض عند الحد الآمن', _muted);
      return;
    }
    final children = await widget.files.listDirectory(uri);
    children.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    for (var i = 0; i < children.length; i++) {
      if (count.first >= maxItems) break;
      final item = children[i];
      count[0]++;
      final last = i == children.length - 1;
      _write(
        '$prefix${last ? '└── ' : '├── '}${item.name}${item.isDir ? '/' : ''}',
        item.isDir ? _cyan : Colors.white70,
      );
      if (item.isDir) {
        await _tree(
          item.uri,
          '$prefix${last ? '    ' : '│   '}',
          depth: depth + 1,
          maxDepth: maxDepth,
          maxItems: maxItems,
          count: count,
        );
      }
    }
  }

  Future<void> _walkFiles(
    String uri,
    String prefix,
    Future<void> Function(SafDocumentFile file, String relative) visit, {
    int depth = 0,
    List<int>? count,
  }) async {
    final tracker = count ?? [0];
    if (depth > 12 || tracker.first >= 1000) return;
    final children = await widget.files.listDirectory(uri);
    for (final item in children) {
      if (tracker.first >= 1000) return;
      final relative = prefix.isEmpty ? item.name : '$prefix/${item.name}';
      tracker[0]++;
      if (item.isDir) {
        await _walkFiles(item.uri, relative, visit,
            depth: depth + 1, count: tracker);
      } else {
        await visit(item, relative);
      }
    }
  }

  Future<void> _printFile(String path, {int? first, int? last}) async {
    final resolved = await _resolveItem(path);
    if (resolved == null || resolved.item.isDir) {
      _write('الملف غير موجود: $path', _red);
      return;
    }
    final bytes = await widget.files.readFile(resolved.item.uri);
    if (first == null && last == null && bytes.length > 2 * 1024 * 1024) {
      throw const FormatException(
        'الملف أكبر من 2 MB. استخدم head أو tail لعرض جزء منه.',
      );
    }
    final content = utf8.decode(bytes, allowMalformed: true);
    final lines = const LineSplitter().convert(content);
    if (lines.isEmpty) {
      _write('(ملف فارغ)', _muted);
      return;
    }
    final selected = first != null
        ? lines.take(first)
        : last != null
            ? lines.skip(lines.length > last ? lines.length - last : 0)
            : lines;
    for (final line in selected) {
      _write(line);
    }
  }

  Future<void> _makeDirectory(String path, {bool parents = false}) async {
    final normalized = path.replaceAll('\\', '/');
    if (!parents) {
      final destination = await _resolveParent(normalized);
      if (destination == null) {
        throw const FormatException('المجلد الأب غير موجود.');
      }
      final name = normalized.split('/').last;
      final existing = await _child(destination.parentUri, name);
      if (existing != null) {
        throw FormatException('العنصر موجود بالفعل: $name');
      }
      await widget.files.createFolder(
        parentUri: destination.parentUri,
        folderName: name,
      );
      _write('تم إنشاء المجلد $path', _green);
      return;
    }

    // Resolve from project root so relative paths honor cwd and never escape it.
    final names = normalized.startsWith('/')
        ? <String>[]
        : List<String>.from(_directoryNames);
    for (final segment in normalized.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (names.isNotEmpty) names.removeLast();
      } else {
        names.add(segment);
      }
    }

    var uri = widget.projectUri!;
    for (final segment in names) {
      final existing = await _child(uri, segment);
      if (existing != null) {
        if (!existing.isDir) {
          throw StateError('$segment موجود كملف وليس مجلدًا.');
        }
        uri = existing.uri;
      } else {
        final created = await widget.files.createFolder(
          parentUri: uri,
          folderName: segment,
        );
        uri = created.uri;
      }
    }
    _write('تم إنشاء المسار $path', _green);
  }

  Future<void> _writeFile(String path, String content, {bool append = false}) async {
    final destination = await _resolveParent(path);
    if (destination == null) throw const FormatException('المجلد الأب غير موجود.');
    final name = path.replaceAll('\\', '/').split('/').last;
    final existing = await _child(destination.parentUri, name);
    if (existing != null && existing.isDir) {
      throw const FormatException('لا يمكن الكتابة فوق مجلد.');
    }
    if (existing != null && !append) {
      final ok = await _confirm(
        'تأكيد استبدال الملف',
        'الملف "$name" موجود بالفعل. سيتم استبدال محتواه بالكامل.',
      );
      if (!ok) {
        _write('تم إلغاء الكتابة.', _yellow);
        return;
      }
    }
    var bytes = Uint8List.fromList(utf8.encode(content));
    if (append && existing != null) {
      final previous = await widget.files.readFile(existing.uri);
      bytes = Uint8List.fromList([...previous, ...bytes]);
    }
    final saved = await widget.files.saveFile(
      parentUri: destination.parentUri,
      fileName: name,
      bytes: bytes,
      overwrite: true,
    );
    _write('${append ? 'تمت الإضافة إلى' : 'تم الحفظ:'} ${saved.name}', _green);
  }

  Future<bool> _confirm(String title, String message) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    return answer == true;
  }

  Future<void> _remove(List<String> args) async {
    final recursive = args.contains('-r') || args.contains('-rf') || args.contains('-R');
    final force = args.contains('-f') || args.contains('-rf');
    final targetNames = args.where((a) => !a.startsWith('-')).toList();
    final targetName = targetNames.isEmpty ? null : targetNames.first;
    if (targetName == null) throw const FormatException('استخدم: rm [-r] <مسار>');
    final resolved = await _resolveItem(targetName);
    if (resolved == null) {
      if (force) {
        _write('العنصر غير موجود؛ تم تجاهله.', _muted);
        return;
      }
      throw FormatException('العنصر غير موجود: $targetName');
    }
    if (widget.projectUri == resolved.item.uri) {
      throw const FormatException('لا يمكن حذف جذر المشروع من الطرفية.');
    }
    if (resolved.item.isDir) {
      final children = await widget.files.listDirectory(resolved.item.uri);
      if (children.isNotEmpty && !recursive) {
        throw const FormatException('المجلد غير فارغ. استخدم rm -r بعد التأكد.');
      }
      if (recursive) {
        final ok = await _confirm(
          'تأكيد الحذف',
          'سيتم حذف "${resolved.item.name}" وكل محتوياته نهائيًا. هل تريد المتابعة؟',
        );
        if (!ok) {
          _write('تم إلغاء الحذف.', _yellow);
          return;
        }
        await widget.files.deleteTree(resolved.item.uri);
      } else {
        await widget.files.deleteItem(resolved.item.uri);
      }
    } else {
      await widget.files.deleteItem(resolved.item.uri);
    }
    _write('تم حذف ${resolved.item.name}', _green);
  }

  Future<void> _copyFile(String source, String destination) async {
    final from = await _resolveItem(source);
    if (from == null || from.item.isDir) {
      throw const FormatException('المصدر غير موجود أو ليس ملفًا.');
    }
    final target = await _resolveItem(destination);
    String parentUri;
    String newName;
    if (target != null && target.item.isDir) {
      parentUri = target.item.uri;
      newName = from.item.name;
    } else {
      final parent = await _resolveParent(destination);
      if (parent == null) throw const FormatException('مجلد الوجهة غير موجود.');
      parentUri = parent.parentUri;
      newName = destination.replaceAll('\\', '/').split('/').last;
    }

    final existing = await _child(parentUri, newName);
    if (existing?.uri == from.item.uri) {
      throw const FormatException('المصدر والوجهة هما الملف نفسه.');
    }
    if (existing != null && existing.isDir) {
      throw const FormatException('لا يمكن استبدال مجلد بملف.');
    }
    if (existing != null) {
      final ok = await _confirm(
        'تأكيد استبدال الملف',
        'الملف \"$newName\" موجود بالفعل. هل تريد استبداله؟',
      );
      if (!ok) {
        _write('تم إلغاء النسخ.', _yellow);
        return;
      }
    }
    final bytes = await widget.files.readFile(from.item.uri);
    final saved = await widget.files.saveFile(
      parentUri: parentUri,
      fileName: newName,
      bytes: bytes,
      overwrite: existing != null,
    );
    _write('تم نسخ ${from.item.name} إلى ${saved.name}', _green);
  }

  Future<void> _grep(String pattern, String path) async {
    final resolved = await _resolveItem(path);
    if (resolved == null) {
      _write('المسار غير موجود: $path', _red);
      return;
    }
    var matches = 0;
    Future<void> inspect(SafDocumentFile file, String relative) async {
      if (matches >= 150) return;
      try {
        final text = utf8.decode(
          await widget.files.readFile(file.uri),
          allowMalformed: true,
        );
        final lines = const LineSplitter().convert(text);
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains(pattern)) {
            _write('$relative:${i + 1}: ${lines[i]}', _yellow);
            matches++;
            if (matches >= 150) break;
          }
        }
      } catch (_) {
        // Binary or unreadable files are skipped.
      }
    }

    if (resolved.item.isDir) {
      await _walkFiles(resolved.item.uri, '', inspect);
    } else {
      await inspect(resolved.item, resolved.item.name);
    }
    if (matches == 0) _write('لم يتم العثور على "$pattern".', _muted);
    if (matches >= 150) _write('تم إيقاف النتائج عند 150 تطابقًا.', _muted);
  }

  Future<void> _find(String name, String path) async {
    final resolved = await _resolveItem(path);
    if (resolved == null || !resolved.item.isDir) {
      _write('المجلد غير موجود: $path', _red);
      return;
    }
    var matches = 0;
    var scanned = 0;
    Future<void> inspect(SafDocumentFile file, String relative) async {
      scanned++;
      if (file.name.toLowerCase().contains(name.toLowerCase())) {
        _write(relative, file.isDir ? _cyan : Colors.white70);
        matches++;
      }
    }
    // Include folders as well as files.
    Future<void> visit(String uri, String prefix, int depth) async {
      if (depth > 12 || matches >= 150 || scanned >= 1000) return;
      final children = await widget.files.listDirectory(uri);
      for (final item in children) {
        if (matches >= 150 || scanned >= 1000) break;
        final relative = prefix.isEmpty ? item.name : '$prefix/${item.name}';
        await inspect(item, relative);
        if (item.isDir) await visit(item.uri, relative, depth + 1);
      }
    }
    await visit(resolved.item.uri, '', 0);
    if (matches == 0) _write('لم يتم العثور على "$name".', _muted);
    if (scanned >= 1000) _write('تم إيقاف البحث بعد فحص 1000 عنصر.', _muted);
  }

  Future<void> _execute(String raw) async {
    final command = raw.trim();
    if (command.isEmpty || _busy) return;
    _commandController.clear();
    _history.add(command);
    if (_history.length > 200) _history.removeAt(0);
    _historyIndex = _history.length;
    _write('bisho:${_path}\$ $command', _green);

    if (command == 'clear' || command == 'cls') {
      setState(_output.clear);
      return;
    }

    setState(() => _busy = true);
    try {
      // Support simple shell-style output redirection, including append.
      final redirect = RegExp(r'^echo\s+(.+?)\s*(>>|>)\s*(.+)$').firstMatch(command);
      if (redirect != null) {
        final value = _parse(redirect.group(1)!);
        final destination = _parse(redirect.group(3)!);
        if (destination.isEmpty) throw const FormatException('اسم الملف مفقود.');
        await _writeFile(
          destination.first,
          '${value.join(' ')}\n',
          append: redirect.group(2) == '>>',
        );
        return;
      }

      final args = _parse(command);
      if (args.isEmpty) return;
      final cmd = args.first.toLowerCase();
      final rest = args.skip(1).toList();

      if (widget.projectUri == null &&
          !const {'help', 'date', 'whoami', 'history', 'clear'}.contains(cmd)) {
        throw const FormatException('افتح مشروعًا أولاً لاستخدام أوامر الملفات.');
      }

      switch (cmd) {
        case 'help':
          _write('Bisho Project Terminal — الأوامر:', _cyan);
          _write('التنقل: pwd | ls [-a] [-l] [مسار] | cd [مسار] | tree [مسار]');
          _write('القراءة: cat ملف | head [-n عدد] ملف | tail [-n عدد] ملف');
          _write('البحث: grep نص [مسار] | find اسم [مجلد] | wc ملف');
          _write('الملفات: touch ملف | mkdir [-p] مجلد | write ملف نص (استبدال بتأكيد) | append ملف نص');
          _write('النسخ والتسمية: cp مصدر وجهة | mv عنصر اسم-جديد | rename عنصر اسم-جديد');
          _write('الحذف: rm ملف | rm -r مجلد (يتطلب تأكيدًا)');
          _write('أخرى: open ملف | stat مسار | history | project | date | whoami | clear');
          _write('المسارات النسبية و / و .. مدعومة. النتائج الطويلة محدودة لحماية الأداء.', _muted);
          _write('هذه بيئة أوامر لإدارة ملفات المشروع عبر SAF وليست Linux shell.', _yellow);
          break;
        case 'pwd':
          _write(_path, _cyan);
          break;
        case 'project':
          _write(widget.projectName, _cyan);
          _write('URI: ${widget.projectUri}', _muted);
          break;
        case 'date':
          _write(DateTime.now().toLocal().toString(), _cyan);
          break;
        case 'whoami':
          _write('bisho-user (مساحة التطبيق)', _cyan);
          break;
        case 'history':
          for (var i = 0; i < _history.length; i++) {
            _write('${i + 1}  ${_history[i]}', _muted);
          }
          break;
        case 'ls':
        case 'dir':
          final all = rest.contains('-a');
          final long = rest.contains('-l');
          final pathArgs = rest.where((a) => !a.startsWith('-')).toList();
          final path = pathArgs.isEmpty ? '.' : pathArgs.first;
          await _list(path, all: all, long: long);
          break;
        case 'cd':
          final path = rest.isEmpty ? '/' : rest.first;
          final uri = await _resolveDirectory(path);
          if (uri == null) _write('المجلد غير موجود: $path', _red);
          break;
        case 'tree':
          final path = rest.isEmpty ? '.' : rest.first;
          final resolved = await _resolveItem(path);
          if (resolved == null || !resolved.item.isDir) {
            throw FormatException('المجلد غير موجود: $path');
          }
          _write('${resolved.item.name}/', _cyan);
          await _tree(resolved.item.uri, '', count: [0]);
          break;
        case 'cat':
          if (rest.isEmpty) throw const FormatException('استخدم: cat <ملف>');
          await _printFile(rest.first);
          break;
        case 'head':
        case 'tail':
          if (rest.isEmpty) throw FormatException('استخدم: $cmd [-n عدد] <ملف>');
          var count = 10;
          var file = rest.last;
          if (rest.length >= 3 && rest[0] == '-n') {
            count = int.tryParse(rest[1]) ?? 10;
            file = rest[2];
          }
          if (count < 1 || count > 500) {
            throw const FormatException('عدد الأسطر يجب أن يكون بين 1 و500.');
          }
          await _printFile(file, first: cmd == 'head' ? count : null,
              last: cmd == 'tail' ? count : null);
          break;
        case 'grep':
          if (rest.isEmpty) throw const FormatException('استخدم: grep <نص> [مسار]');
          await _grep(rest[0], rest.length > 1 ? rest[1] : '.');
          break;
        case 'find':
          if (rest.isEmpty) throw const FormatException('استخدم: find <اسم> [مجلد]');
          await _find(rest[0], rest.length > 1 ? rest[1] : '.');
          break;
        case 'wc':
          if (rest.isEmpty) throw const FormatException('استخدم: wc <ملف>');
          final file = await _resolveItem(rest.first);
          if (file == null || file.item.isDir) throw const FormatException('الملف غير موجود.');
          final text = utf8.decode(await widget.files.readFile(file.item.uri), allowMalformed: true);
          final lines = text.isEmpty ? 0 : '\n'.allMatches(text).length + (text.endsWith('\n') ? 0 : 1);
          final words = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
          _write('$lines lines  $words words  ${text.length} chars  ${file.item.name}', _cyan);
          break;
        case 'stat':
          if (rest.isEmpty) throw const FormatException('استخدم: stat <مسار>');
          final item = await _resolveItem(rest.first);
          if (item == null) throw const FormatException('العنصر غير موجود.');
          _write('الاسم: ${item.item.name}');
          _write('النوع: ${item.item.isDir ? 'مجلد' : 'ملف'}');
          _write('URI: ${item.item.uri}', _muted);
          if (item.item.isDir) {
            _write('العناصر: ${(await widget.files.listDirectory(item.item.uri)).length}');
          } else {
            _write('الحجم: ${(await widget.files.readFile(item.item.uri)).length} bytes');
          }
          break;
        case 'mkdir':
          if (rest.isEmpty) throw const FormatException('استخدم: mkdir [-p] <مجلد>');
          await _makeDirectory(rest.last, parents: rest.contains('-p'));
          break;
        case 'touch':
          if (rest.isEmpty) throw const FormatException('استخدم: touch <ملف>');
          final destination = await _resolveParent(rest.first);
          if (destination == null) throw const FormatException('المجلد الأب غير موجود.');
          final name = rest.first.replaceAll('\\', '/').split('/').last;
          final existing = await _child(destination.parentUri, name);
          if (existing != null) {
            _write('موجود بالفعل: $name', _muted);
          } else {
            final created = await widget.files.saveFile(
              parentUri: destination.parentUri,
              fileName: name,
              bytes: Uint8List(0),
              overwrite: false,
            );
            _write('تم إنشاء ${created.name}', _green);
          }
          break;
        case 'write':
        case 'append':
          if (rest.length < 2) throw FormatException('استخدم: $cmd <ملف> <نص>');
          await _writeFile(rest.first, '${rest.skip(1).join(' ')}\n', append: cmd == 'append');
          break;
        case 'echo':
          _write(rest.join(' '));
          break;
        case 'cp':
          if (rest.length < 2) throw const FormatException('استخدم: cp <مصدر> <وجهة>');
          await _copyFile(rest[0], rest[1]);
          break;
        case 'mv':
        case 'rename':
          if (rest.length < 2) throw FormatException('استخدم: $cmd <ملف> <اسم-جديد>');
          final source = await _resolveItem(rest[0]);
          if (source == null) throw const FormatException('المصدر غير موجود.');
          if (rest[1].contains('/') || rest[1].contains('\\')) {
            throw const FormatException('الاسم الجديد يجب أن يكون اسمًا فقط دون مسارات.');
          }
          if (rest[1] == source.item.name) {
            _write('الاسم لم يتغير.', _muted);
            break;
          }
          final collision = await _child(source.parentUri, rest[1]);
          if (collision != null && collision.uri != source.item.uri) {
            throw FormatException('يوجد عنصر آخر بالاسم: ${rest[1]}');
          }
          final renamed = await widget.files.renameItem(uri: source.item.uri, newName: rest[1]);
          _write('تمت إعادة التسمية إلى ${renamed.name}', _green);
          break;
        case 'rm':
        case 'del':
          await _remove(rest);
          break;
        case 'open':
          if (rest.isEmpty) throw const FormatException('استخدم: open <ملف>');
          final file = await _resolveItem(rest.first);
          if (file == null || file.item.isDir) {
            _write('الملف غير موجود: ${rest.first}', _red);
          } else {
            await widget.onOpenFile(file.item, file.parentUri);
            _write('تم فتح ${file.item.name} في المحرر', _green);
          }
          break;
        case 'flutter':
        case 'dart':
        case 'python':
        case 'node':
        case 'npm':
        case 'git':
        case 'gradle':
        case './gradlew':
          _write('الأمر "$cmd" يحتاج بيئة تنفيذ خارجية غير مضمّنة في التطبيق.', _red);
          _write('هذه الحزمة تطور إدارة ملفات الطرفية؛ لم يتم تفعيل shell أو تنفيذ أوامر النظام.', _muted);
          break;
        default:
          final suggestions = _commands.where((c) => c.startsWith(cmd)).take(4).join(', ');
          _write('أمر غير معروف: $cmd${suggestions.isEmpty ? '' : ' — هل تقصد: $suggestions؟'}', _red);
      }
    } catch (error) {
      _write('خطأ: $error', _red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _historyMove(int direction) {
    if (_history.isEmpty) return;
    _historyIndex = (_historyIndex + direction).clamp(0, _history.length).toInt();
    _commandController.text =
        _historyIndex == _history.length ? '' : _history[_historyIndex];
    _commandController.selection = TextSelection.collapsed(
      offset: _commandController.text.length,
    );
  }

  String _commonPrefix(List<String> values) {
    if (values.isEmpty) return '';
    var prefix = values.first;
    for (final value in values.skip(1)) {
      var i = 0;
      while (i < prefix.length && i < value.length && prefix[i] == value[i]) {
        i++;
      }
      prefix = prefix.substring(0, i);
    }
    return prefix;
  }

  /// Tab-completion for touch keyboards: completes command names for the
  /// first token and file/folder names of the current directory afterwards.
  Future<void> _complete() async {
    if (_busy) return;
    final text = _commandController.text;
    final lastSpace = text.lastIndexOf(' ');
    final head = lastSpace < 0 ? '' : text.substring(0, lastSpace + 1);
    final token = lastSpace < 0 ? text : text.substring(lastSpace + 1);

    List<String> candidates;
    if (lastSpace < 0) {
      candidates = _commands.where((c) => c.startsWith(token)).toList();
    } else {
      final uri = _currentUri;
      if (uri == null) return;
      try {
        final children = await widget.files.listDirectory(uri);
        candidates = children
            .where((item) => !item.name.contains(' ') && item.name.startsWith(token))
            .map((item) => item.isDir ? '${item.name}/' : item.name)
            .toList();
      } catch (_) {
        return;
      }
    }
    if (!mounted || candidates.isEmpty) return;

    final completed = candidates.length == 1
        ? candidates.first
        : _commonPrefix(candidates);
    if (completed.length > token.length) {
      _commandController.text = '$head$completed';
      _commandController.selection = TextSelection.collapsed(
        offset: _commandController.text.length,
      );
    }
    if (candidates.length > 1) {
      _write(candidates.take(40).join('   '), _muted);
    }
  }

  Future<void> _copyOutput() async {
    final text = _output.map((line) => line.text).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('تم نسخ ناتج الطرفية')),
    );
  }

  void _insertQuickCommand(String command, {bool run = true}) {
    if (_busy) return;
    if (run) {
      _execute(command);
    } else {
      _commandController.text = command;
      _commandController.selection = TextSelection.collapsed(offset: command.length);
      _commandFocus.requestFocus();
    }
  }

  Widget _quickBar() {
    Widget chip(String label, VoidCallback onTap, {IconData? icon}) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ActionChip(
            visualDensity: VisualDensity.compact,
            avatar: icon == null ? null : Icon(icon, size: 15, color: _cyan),
            label: Text(label, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            onPressed: _busy ? null : onTap,
          ),
        );
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        children: [
          chip('Tab', _complete, icon: Icons.keyboard_tab_rounded),
          chip('↑', () => _historyMove(-1)),
          chip('↓', () => _historyMove(1)),
          chip('ls', () => _insertQuickCommand('ls')),
          chip('pwd', () => _insertQuickCommand('pwd')),
          chip('tree', () => _insertQuickCommand('tree')),
          chip('cd ..', () => _insertQuickCommand('cd ..')),
          chip('cat ', () => _insertQuickCommand('cat ', run: false)),
          chip('help', () => _insertQuickCommand('help')),
          chip('نسخ الناتج', _copyOutput, icon: Icons.copy_rounded),
          chip('مسح', _clearOutput, icon: Icons.delete_sweep_rounded),
        ],
      ),
    );
  }

  void _clearOutput() {
    setState(_output.clear);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF080D19),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              itemCount: _output.length,
              itemBuilder: (context, index) => SelectableText(
                _output[index].text,
                style: TextStyle(
                  color: _output[index].color,
                  fontSize: 11,
                  height: 1.45,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF263449)),
          _quickBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 5, 6, 6),
            child: Row(
              children: [
                const Icon(Icons.chevron_right, color: _green, size: 19),
                Expanded(
                  child: Shortcuts(
                    shortcuts: <ShortcutActivator, Intent>{
                      const SingleActivator(LogicalKeyboardKey.arrowUp):
                          const _TerminalHistoryIntent(-1),
                      const SingleActivator(LogicalKeyboardKey.arrowDown):
                          const _TerminalHistoryIntent(1),
                      const SingleActivator(LogicalKeyboardKey.keyL, control: true):
                          const _TerminalClearIntent(),
                      const SingleActivator(LogicalKeyboardKey.tab):
                          const _TerminalCompleteIntent(),
                    },
                    child: Actions(
                      actions: <Type, Action<Intent>>{
                        _TerminalHistoryIntent:
                            CallbackAction<_TerminalHistoryIntent>(
                          onInvoke: (intent) {
                            _historyMove(intent.direction);
                            return null;
                          },
                        ),
                        _TerminalCompleteIntent:
                            CallbackAction<_TerminalCompleteIntent>(
                          onInvoke: (_) {
                            _complete();
                            return null;
                          },
                        ),
                        _TerminalClearIntent:
                            CallbackAction<_TerminalClearIntent>(
                          onInvoke: (_) {
                            _clearOutput();
                            return null;
                          },
                        ),
                      },
                      child: TextField(
                        controller: _commandController,
                        focusNode: _commandFocus,
                        enabled: !_busy,
                        textDirection: TextDirection.ltr,
                        textInputAction: TextInputAction.go,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          hintText: _busy ? 'جاري التنفيذ...' : 'اكتب أمرًا... (help)',
                          hintStyle: const TextStyle(color: _muted, fontSize: 11),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: _execute,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'تنفيذ الأمر',
                  visualDensity: VisualDensity.compact,
                  onPressed: _busy ? null : () => _execute(_commandController.text),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded, color: _green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalHistoryIntent extends Intent {
  final int direction;
  const _TerminalHistoryIntent(this.direction);
}

class _TerminalCompleteIntent extends Intent {
  const _TerminalCompleteIntent();
}

class _TerminalClearIntent extends Intent {
  const _TerminalClearIntent();
}
