
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';

import 'package:highlight/languages/dart.dart' as dart_lang;
import 'package:highlight/languages/python.dart' as python_lang;
import 'package:highlight/languages/javascript.dart' as js_lang;
import 'package:highlight/languages/typescript.dart' as ts_lang;
import 'package:highlight/languages/java.dart' as java_lang;
import 'package:highlight/languages/kotlin.dart' as kotlin_lang;
import 'package:highlight/languages/swift.dart' as swift_lang;
import 'package:highlight/languages/cpp.dart' as cpp_lang;
import 'package:highlight/languages/css.dart' as css_lang;
import 'package:highlight/languages/xml.dart' as xml_lang;
import 'package:highlight/languages/json.dart' as json_lang;
import 'package:highlight/languages/sql.dart' as sql_lang;
import 'package:highlight/languages/bash.dart' as bash_lang;
import 'package:highlight/languages/go.dart' as go_lang;
import 'package:highlight/languages/rust.dart' as rust_lang;
import 'package:highlight/languages/php.dart' as php_lang;
import 'package:highlight/languages/yaml.dart' as yaml_lang;
import 'package:highlight/languages/markdown.dart' as markdown_lang;

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saf/saf.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';

import 'core/theme/bisho_theme.dart';
import 'core/services/saf_file_service.dart';
import 'core/languages/language_identity.dart';
import 'core/services/project_archive_validator.dart';
import 'features/projects/new_project_wizard.dart';
import 'flutter_preview_screen.dart';
import 'html_preview_screen.dart';
import 'web_code_runner_screen.dart';
import 'core/services/language_engine_manager.dart';
import 'core/services/editor_editing_assist.dart';
import 'core/services/editor_line_actions.dart';
import 'core/services/editor_text_navigation.dart';
import 'core/services/editor_syntax_diagnostics.dart';
import 'core/services/editor_bracket_matcher.dart';
import 'core/services/editor_completion_engine.dart';
import 'core/services/editor_symbol_insert.dart';
import 'core/services/workspace_metrics.dart';
import 'core/services/project_insights_analyzer.dart';
import 'core/services/project_backup_service.dart';
import 'core/services/project_backup_repository.dart';
import 'core/services/project_text_diff.dart';
import 'features/terminal/bisho_terminal_panel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BishoThemeController.load();
  runApp(const BishoIDE());
}

class BishoIDE extends StatelessWidget {
  const BishoIDE({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: BishoThemeController.mode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Bisho IDE',
        debugShowCheckedModeBanner: false,
        theme: BishoTheme.lightTheme,
        darkTheme: BishoTheme.darkTheme,
        themeMode: mode,
        home: Theme(
          data: BishoTheme.darkTheme,
          child: const _BishoSplashGate(),
        ),
      ),
    );
  }
}

/// Page route that keeps the code workspace (previews, runners, fullscreen
/// editor) on the dark theme, which those screens are hand-styled for.
class _DarkPageRoute<T> extends MaterialPageRoute<T> {
  _DarkPageRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });

  @override
  Widget buildContent(BuildContext context) =>
      Theme(data: BishoTheme.darkTheme, child: super.buildContent(context));
}


/// Computes the 1-based line and column for [offset] without allocating a
/// substring or running a regex over the text on every rebuild.
(int, int) _cursorLineColumn(String text, int offset) {
  final end = offset.clamp(0, text.length).toInt();
  var line = 1;
  var lastBreak = -1;
  for (var i = 0; i < end; i++) {
    if (text.codeUnitAt(i) == 0x0A) {
      line++;
      lastBreak = i;
    }
  }
  return (line, end - lastBreak);
}

PopupMenuItem<String> _bishoMenuItem(
  String value,
  IconData icon,
  String label, {
  Color color = const Color(0xFF38BDF8),
}) {
  return PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}

class _BishoSplashGate extends StatefulWidget {
  const _BishoSplashGate({super.key});

  @override
  State<_BishoSplashGate> createState() => _BishoSplashGateState();
}

class _BishoSplashGateState extends State<_BishoSplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    Future<void>.delayed(const Duration(milliseconds: 1450), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 850),
          pageBuilder: (_, __, ___) => const EditorScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: .97, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: const Color(0xFF172337),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFF33465F)),
                  ),
                  child: const Icon(Icons.code_rounded,
                    size: 62, color: Color(0xFF38BDF8)),
                ),
                const SizedBox(height: 22),
                const Text('Bisho IDE', style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w700,
                  letterSpacing: .2, color: Color(0xFFE5EDF7))),
                const SizedBox(height: 7),
                const Text('CODE  •  BUILD  •  CREATE', style: TextStyle(
                  color: Color(0xFF94A3B8), fontSize: 11, letterSpacing: 2)),
                const SizedBox(height: 28),
                SizedBox(width: 150, child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Color(0xFF243247),
                    valueColor: AlwaysStoppedAnimation(Color(0xFF38BDF8)),
                  ),
                )),
                const SizedBox(height: 14),
                const Text('جاري تجهيز بيئة التطوير...', style: TextStyle(
                  color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class EditorTab {
  final String id;
  final CodeController controller;

  String fileName;
  String language;

  String? fileUri;
  String? parentUri;

  bool isSaved;
  int selectionBaseOffset;
  int selectionExtentOffset;

  EditorTab({
    required this.id,
    required this.controller,
    required this.fileName,
    required this.language,
    this.fileUri,
    this.parentUri,
    this.isSaved = true,
    this.selectionBaseOffset = 0,
    this.selectionExtentOffset = 0,
  });
}

/// يمثل عنصرًا داخل شجرة SAF.
class _SafTreeEntry {
  final String uri;
  final String name;
  final String relativePath;
  final String? parentUri;
  final bool isDir;

  const _SafTreeEntry({
    required this.uri,
    required this.name,
    required this.relativePath,
    required this.parentUri,
    required this.isDir,
  });
}

class _ProjectSearchResult {
  final SafDocumentFile file;
  final String parentUri;
  final String relativePath;
  final List<int> matchingLines;

  const _ProjectSearchResult({
    required this.file,
    required this.parentUri,
    required this.relativePath,
    required this.matchingLines,
  });
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WidgetsBindingObserver {
  static const String _savedDirectoryUriKey =
      'bisho_selected_directory_uri';

  static const String _savedDirectoryNameKey =
      'bisho_selected_directory_name';

  final Saf saf = Saf();
  final SafFileService safFiles = SafFileService();

  final Map<String, dynamic> languages = {
    'Dart': dart_lang.dart,
    'Python': python_lang.python,
    'JavaScript': js_lang.javascript,
    'TypeScript': ts_lang.typescript,
    'Java': java_lang.java,
    'Kotlin': kotlin_lang.kotlin,
    'Swift': swift_lang.swift,
    'C': cpp_lang.cpp,
    'C++': cpp_lang.cpp,
    'CSS': css_lang.css,
    'HTML': xml_lang.xml,
    'XML': xml_lang.xml,
    'JSON': json_lang.json,
    'SQL': sql_lang.sql,
    'Bash': bash_lang.bash,
    'Go': go_lang.go,
    'Rust': rust_lang.rust,
    'PHP': php_lang.php,
    'Markdown': markdown_lang.markdown,
    'YAML': yaml_lang.yaml,
  };

  final Map<String, String> extensions = {
    'Dart': 'dart',
    'Python': 'py',
    'JavaScript': 'js',
    'TypeScript': 'ts',
    'Java': 'java',
    'Kotlin': 'kt',
    'Swift': 'swift',
    'C': 'c',
    'C++': 'cpp',
    'CSS': 'css',
    'HTML': 'html',
    'XML': 'xml',
    'JSON': 'json',
    'SQL': 'sql',
    'Bash': 'sh',
    'Go': 'go',
    'Rust': 'rs',
    'PHP': 'php',
    'Markdown': 'md',
    'YAML': 'yaml',
  };

  final List<EditorTab> tabs = [];

  int activeIndex = 0;
  int nextTabId = 1;
  int _explorerRevision = 0;
  String _explorerFilter = '';
  final TextEditingController _explorerFilterController = TextEditingController();

  String status = 'جاهز';

  String? projectUri;
  String projectName = 'لا يوجد مشروع';

  String? selectedDirectoryUri;
  String selectedDirectoryName = '';

  bool isRestoring = false;
  bool explorerVisible = true;
  bool _editorFullScreen = false;
  bool _bottomPanelVisible = false;
  int _bottomPanelTab = 0;
  double _editorFontSize = 14;
  double _bottomPanelHeight = 154;
  final Map<String, List<String>> _undoHistory = {};
  final Map<String, List<String>> _redoHistory = {};
  final Set<String> _historyApplying = {};
  final Set<String> _autoPairApplying = {};
  Timer? _tabStateSaveTimer;
  bool _tabStateSaveInProgress = false;
  bool _tabStateSavePending = false;
  Completer<void>? _tabStateSaveCompleter;
  bool _isDisposing = false;

  static const String _fontSizePreferenceKey = 'bisho_editor_font_size';
  static const String _explorerVisiblePreferenceKey = 'bisho_explorer_visible';
  static const String _bottomPanelVisiblePreferenceKey = 'bisho_bottom_panel_visible';
  static const String _bottomPanelHeightPreferenceKey = 'bisho_bottom_panel_height';

  EditorTab get activeTab => tabs[activeIndex];

  String? get creationDirectoryUri {
    return selectedDirectoryUri ?? projectUri;
  }

  String get creationDirectoryName {
    if (selectedDirectoryUri == null) {
      return projectName;
    }

    return selectedDirectoryName;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    restoreTabs();
  }

  String createId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${nextTabId++}';
  }

  EditorTab createTab({
    String fileName = 'untitled.dart',
    String language = 'Dart',
    String? code,
    String? fileUri,
    String? parentUri,
    bool isSaved = false,
    int selectionBaseOffset = 0,
    int selectionExtentOffset = 0,
  }) {
    final controller = CodeController(
      text: code ??
          '// Welcome to Bisho IDE\n\nvoid main() {\n  print("Hello World");\n}',
      language: languages[language] ?? languages['Dart'],
    );
    final safeBaseOffset = selectionBaseOffset
        .clamp(0, controller.text.length)
        .toInt();
    final safeExtentOffset = selectionExtentOffset
        .clamp(0, controller.text.length)
        .toInt();
    controller.selection = TextSelection(
      baseOffset: safeBaseOffset,
      extentOffset: safeExtentOffset,
    );

    final tab = EditorTab(
      id: createId(),
      controller: controller,
      fileName: fileName,
      language: language,
      fileUri: fileUri,
      parentUri: parentUri,
      isSaved: isSaved,
      selectionBaseOffset: safeBaseOffset,
      selectionExtentOffset: safeExtentOffset,
    );

    _undoHistory[tab.id] = <String>[controller.text];
    _redoHistory[tab.id] = <String>[];

    controller.addListener(() {
      if (_historyApplying.contains(tab.id)) return;

      // Auto-close a single newly typed opening delimiter. Multi-character
      // edits, paste operations, undo and redo are left untouched.
      if (!_autoPairApplying.contains(tab.id)) {
        final historyBeforeEdit =
            _undoHistory.putIfAbsent(tab.id, () => <String>[]);
        final previousText = historyBeforeEdit.isEmpty
            ? controller.text
            : historyBeforeEdit.last;
        _tryDeletePairedOpeningDelimiter(tab, previousText);
        _trySkipExistingClosingDelimiter(tab, previousText);
        _tryInsertClosingPair(tab, previousText);
        _tryAlignClosingDelimiter(tab, previousText);
        _tryAutoIndentNewline(tab, previousText);
      }

      final history = _undoHistory.putIfAbsent(tab.id, () => <String>[]);
      final textChanged = history.isEmpty || history.last != controller.text;
      final selection = controller.selection;
      final safeBaseOffset = selection.isValid
          ? selection.baseOffset.clamp(0, controller.text.length).toInt()
          : controller.text.length;
      final safeExtentOffset = selection.isValid
          ? selection.extentOffset.clamp(0, controller.text.length).toInt()
          : controller.text.length;
      final selectionChanged =
          tab.selectionBaseOffset != safeBaseOffset ||
          tab.selectionExtentOffset != safeExtentOffset;
      tab.selectionBaseOffset = safeBaseOffset;
      tab.selectionExtentOffset = safeExtentOffset;

      if (textChanged) {
        history.add(controller.text);
        // Bound undo memory by entry count and total characters so large
        // files do not keep ~100 full copies of themselves alive.
        var historyChars = 0;
        for (final entry in history) {
          historyChars += entry.length;
        }
        while (history.length > 101 ||
            (history.length > 2 && historyChars > 4000000)) {
          historyChars -= history.removeAt(0).length;
        }
        _redoHistory.putIfAbsent(tab.id, () => <String>[]).clear();
      }
      if (!mounted || isRestoring) return;

      // Selection changes also notify the controller. Refresh the cursor
      // indicator without incorrectly marking an unchanged file as dirty.
      setState(() {
        if (textChanged) {
          tab.isSaved = false;
          status = 'تعديلات جديدة';
        }
      });
      if (textChanged || selectionChanged) _scheduleTabStateSave();
    });

    return tab;
  }

  void _trySkipExistingClosingDelimiter(
    EditorTab tab,
    String previousText,
  ) {
    final controller = tab.controller;
    final result = EditorEditingAssist.skipExistingClosingDelimiter(
      previousText: previousText,
      currentText: controller.text,
      cursorOffset: controller.selection.extentOffset,
    );
    if (result == null) return;

    _autoPairApplying.add(tab.id);
    try {
      controller.value = TextEditingValue(
        text: result.text,
        selection: TextSelection.collapsed(offset: result.cursorOffset),
      );
    } finally {
      _autoPairApplying.remove(tab.id);
    }
  }

  void _tryDeletePairedOpeningDelimiter(
    EditorTab tab,
    String previousText,
  ) {
    final controller = tab.controller;
    final result = EditorEditingAssist.deletePairedOpeningDelimiter(
      previousText: previousText,
      currentText: controller.text,
      cursorOffset: controller.selection.extentOffset,
    );
    if (result == null) return;

    _autoPairApplying.add(tab.id);
    try {
      controller.value = TextEditingValue(
        text: result.text,
        selection: TextSelection.collapsed(offset: result.cursorOffset),
      );
    } finally {
      _autoPairApplying.remove(tab.id);
    }
  }

  void _tryAutoIndentNewline(EditorTab tab, String previousText) {
    final controller = tab.controller;
    final result = EditorEditingAssist.autoIndentNewline(
      previousText: previousText,
      currentText: controller.text,
      cursorOffset: controller.selection.extentOffset,
    );
    if (result == null) return;

    _autoPairApplying.add(tab.id);
    try {
      controller.value = TextEditingValue(
        text: result.text,
        selection: TextSelection.collapsed(offset: result.cursorOffset),
      );
    } finally {
      _autoPairApplying.remove(tab.id);
    }
  }

  void _tryAlignClosingDelimiter(EditorTab tab, String previousText) {
    final controller = tab.controller;
    final selection = controller.selection;
    if (!selection.isValid || !selection.isCollapsed) return;
    final result = EditorEditingAssist.alignClosingDelimiter(
      previousText: previousText,
      currentText: controller.text,
      cursorOffset: selection.extentOffset,
      language: tab.language,
    );
    if (result == null) return;

    _autoPairApplying.add(tab.id);
    try {
      controller.value = TextEditingValue(
        text: result.text,
        selection: TextSelection.collapsed(offset: result.cursorOffset),
      );
    } finally {
      _autoPairApplying.remove(tab.id);
    }
  }

  void _tryInsertClosingPair(EditorTab tab, String previousText) {
    final controller = tab.controller;
    final currentText = controller.text;
    if (currentText.length != previousText.length + 1) return;

    final cursor = controller.selection.extentOffset;
    if (cursor <= 0 || cursor > currentText.length) return;

    final insertionOffset = cursor - 1;
    if (currentText.substring(0, insertionOffset) !=
            previousText.substring(0, insertionOffset) ||
        currentText.substring(cursor) !=
            previousText.substring(insertionOffset)) {
      return;
    }

    final opening = currentText[insertionOffset];
    const closingPairs = <String, String>{
      '(': ')',
      '[': ']',
      '{': '}',
      '\'': '\'',
      '"': '"',
      '`': '`',
    };
    final closing = closingPairs[opening];
    if (closing == null) return;

    // Do not auto-pair an escaped quote.
    if (opening == '\'' || opening == '"' || opening == '`') {
      var backslashes = 0;
      for (var i = insertionOffset - 1; i >= 0 && currentText[i] == '\\'; i--) {
        backslashes++;
      }
      if (backslashes.isOdd) return;
    }

    final updatedText = currentText.replaceRange(
      cursor,
      cursor,
      closing,
    );
    _autoPairApplying.add(tab.id);
    try {
      controller.value = TextEditingValue(
        text: updatedText,
        selection: TextSelection.collapsed(offset: cursor),
      );
    } finally {
      _autoPairApplying.remove(tab.id);
    }
  }

  Future<void> _saveEditorPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fontSizePreferenceKey, _editorFontSize);
      await prefs.setBool(_explorerVisiblePreferenceKey, explorerVisible);
      await prefs.setBool(
        _bottomPanelVisiblePreferenceKey,
        _bottomPanelVisible,
      );
      await prefs.setDouble(
        _bottomPanelHeightPreferenceKey,
        _bottomPanelHeight,
      );
    } catch (_) {
      // Preferences are optional; editor actions must keep working if storage fails.
    }
  }

  Future<void> _saveSelectedDirectoryState() async {
    final prefs = await SharedPreferences.getInstance();

    if (selectedDirectoryUri == null ||
        selectedDirectoryUri!.isEmpty) {
      await prefs.remove(_savedDirectoryUriKey);
      await prefs.remove(_savedDirectoryNameKey);
      return;
    }

    await prefs.setString(
      _savedDirectoryUriKey,
      selectedDirectoryUri!,
    );

    await prefs.setString(
      _savedDirectoryNameKey,
      selectedDirectoryName,
    );
  }

  Future<void> _clearSavedDirectoryState() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_savedDirectoryUriKey);
    await prefs.remove(_savedDirectoryNameKey);
  }

  Future<void> selectCreationDirectory(
    String directoryUri,
    String directoryName,
  ) async {
    if (projectUri == null) return;

    try {
      final directory = await safFiles.getItem(directoryUri);

      if (directory == null || !directory.isDir) {
        showMessage('هذا المجلد غير متاح');
        return;
      }

      final root = await safFiles.getItem(projectUri!);

      if (root == null || !root.isDir) {
        showMessage('تعذر الوصول إلى جذر المشروع');
        return;
      }

      final tree = await collectSubtree(root);

      final isInsideProject = tree.any(
        (entry) =>
            entry.uri == directoryUri &&
            entry.isDir,
      );

      if (!isInsideProject) {
        showMessage('المجلد ليس داخل المشروع المفتوح');
        return;
      }

      if (!mounted) return;

      setState(() {
        selectedDirectoryUri = directory.uri;
        selectedDirectoryName = directory.name.isNotEmpty
            ? directory.name
            : directoryName;
        status = 'مجلد العمل: $selectedDirectoryName';
      });

      await _saveSelectedDirectoryState();

      if (!mounted) return;

      showMessage(
        'تم حفظ "$selectedDirectoryName" كمجلد عمل',
      );
    } catch (e) {
      showMessage('تعذر تحديد مجلد العمل: $e');
    }
  }

  Future<void> resetCreationDirectory() async {
    if (projectUri == null) return;

    try {
      if (!mounted) return;

      setState(() {
        selectedDirectoryUri = null;
        selectedDirectoryName = '';
        status = 'مجلد العمل: جذر المشروع';
      });

      await _clearSavedDirectoryState();

      if (!mounted) return;

      showMessage('تمت العودة إلى جذر المشروع');
    } catch (e) {
      showMessage('تعذر تغيير مجلد العمل: $e');
    }
  }

  void refreshExplorer() {
    if (!mounted) return;

    setState(() {
      _explorerRevision++;
      status = 'تم تحديث المستكشف';
    });
  }

  Future<void> _restoreSelectedDirectory(
    SharedPreferences prefs,
  ) async {
    selectedDirectoryUri = null;
    selectedDirectoryName = '';

    try {
      if (projectUri == null || projectUri!.isEmpty) {
        await _clearSavedDirectoryState();
        return;
      }

      final savedUri = prefs.getString(_savedDirectoryUriKey);

      if (savedUri == null || savedUri.isEmpty) {
        return;
      }

      final root = await safFiles.getItem(projectUri!);

      if (root == null || !root.isDir) {
        await _clearSavedDirectoryState();
        return;
      }

      final tree = await collectSubtree(root);

      _SafTreeEntry? matchingDirectory;

      for (final entry in tree) {
        if (entry.uri == savedUri && entry.isDir) {
          matchingDirectory = entry;
          break;
        }
      }

      if (matchingDirectory == null) {
        await _clearSavedDirectoryState();
        return;
      }

      selectedDirectoryUri = matchingDirectory.uri;
      selectedDirectoryName = matchingDirectory.name;

      await _saveSelectedDirectoryState();
    } catch (_) {
      selectedDirectoryUri = null;
      selectedDirectoryName = '';

      try {
        await _clearSavedDirectoryState();
      } catch (_) {}
    }
  }

  Future<void> restoreTabs() async {
    isRestoring = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      _editorFontSize = (prefs.getDouble(_fontSizePreferenceKey) ?? 14.0)
          .clamp(10.0, 24.0)
          .toDouble();
      explorerVisible = prefs.getBool(_explorerVisiblePreferenceKey) ?? true;
      _bottomPanelVisible =
          prefs.getBool(_bottomPanelVisiblePreferenceKey) ?? false;
      _bottomPanelHeight = (prefs.getDouble(_bottomPanelHeightPreferenceKey) ?? 154.0)
          .clamp(110.0, 420.0)
          .toDouble();

      final savedTabs = prefs.getString('bisho_tabs');
      final savedIndex = prefs.getInt('bisho_active_index') ?? 0;

      final savedProjectUri =
          prefs.getString('bisho_project_uri');

      final savedProjectName =
          prefs.getString('bisho_project_name') ??
              'لا يوجد مشروع';

      projectUri = null;
      projectName = 'لا يوجد مشروع';

      selectedDirectoryUri = null;
      selectedDirectoryName = '';

      if (savedProjectUri != null &&
          savedProjectUri.isNotEmpty) {
        try {
          final permissions =
              await safFiles.getPersistedPermissions();

          final matchingPermission = permissions.where(
            (permission) =>
                permission.uri == savedProjectUri &&
                permission.read &&
                permission.write,
          );

          if (matchingPermission.isNotEmpty) {
            final root = await safFiles.getItem(savedProjectUri);

            if (root != null && root.isDir) {
              projectUri = savedProjectUri;
              projectName = savedProjectName;

              await _restoreSelectedDirectory(prefs);
            } else {
              await prefs.remove('bisho_project_uri');
              await prefs.remove('bisho_project_name');

              await _clearSavedDirectoryState();
            }
          } else {
            await prefs.remove('bisho_project_uri');
            await prefs.remove('bisho_project_name');

            await _clearSavedDirectoryState();
          }
        } catch (_) {
          projectUri = null;
          projectName = 'لا يوجد مشروع';

          selectedDirectoryUri = null;
          selectedDirectoryName = '';

          try {
            await prefs.remove('bisho_project_uri');
            await prefs.remove('bisho_project_name');

            await _clearSavedDirectoryState();
          } catch (_) {}
        }
      } else {
        await _clearSavedDirectoryState();
      }

      if (savedTabs != null) {
        final List<dynamic> data = jsonDecode(savedTabs);

        for (final item in data) {
          final language =
              item['language'] as String? ?? 'Dart';

          final safeLanguage =
              languages.containsKey(language)
                  ? language
                  : 'Dart';

          tabs.add(
            createTab(
              fileName:
                  item['fileName'] as String? ?? 'untitled.dart',
              language: safeLanguage,
              code: item['code'] as String? ?? '',
              fileUri: item['fileUri'] as String?,
              parentUri: item['parentUri'] as String?,
              isSaved: true,
              selectionBaseOffset: item['selectionBaseOffset'] is int
                  ? item['selectionBaseOffset'] as int
                  : ((item['cursorOffset'] is int)
                      ? item['cursorOffset'] as int
                      : 0),
              selectionExtentOffset: item['selectionExtentOffset'] is int
                  ? item['selectionExtentOffset'] as int
                  : ((item['cursorOffset'] is int)
                      ? item['cursorOffset'] as int
                      : 0),
            ),
          );
        }
      } else {
        final oldCode = prefs.getString('bisho_code');

        final oldName =
            prefs.getString('bisho_filename') ?? 'main.dart';

        final oldLanguage =
            prefs.getString('bisho_language') ?? 'Dart';

        final safeLanguage =
            languages.containsKey(oldLanguage)
                ? oldLanguage
                : 'Dart';

        tabs.add(
          createTab(
            fileName: oldName,
            language: safeLanguage,
            code: oldCode,
            isSaved: true,
          ),
        );
      }

      if (tabs.isEmpty) {
        tabs.add(createTab());
      }

      activeIndex =
          savedIndex.clamp(0, tabs.length - 1).toInt();
    } catch (e) {
      for (final tab in tabs) {
        tab.controller.dispose();
      }

      tabs.clear();
      tabs.add(createTab());

      activeIndex = 0;

      projectUri = null;
      projectName = 'لا يوجد مشروع';

      selectedDirectoryUri = null;
      selectedDirectoryName = '';
    }

    isRestoring = false;

    if (mounted) {
      setState(() {
        status = projectUri != null
            ? 'تم استعادة المشروع والملفات'
            : 'تم استعادة الملفات - افتح مجلد المشروع';
      });
    }
  }

  void _scheduleTabStateSave() {
    _tabStateSaveTimer?.cancel();
    _tabStateSaveTimer = Timer(const Duration(milliseconds: 650), () {
      saveTabStateSilently();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _tabStateSaveTimer?.cancel();
      saveTabStateSilently();
    }
  }

  Future<void> saveTabStateSilently() async {
    if (_tabStateSaveInProgress) {
      _tabStateSavePending = true;
      final inFlight = _tabStateSaveCompleter;
      if (inFlight != null) {
        await inFlight.future;
        if (!_isDisposing) await saveTabStateSilently();
      }
      return;
    }
    _tabStateSaveInProgress = true;
    _tabStateSaveCompleter = Completer<void>();
    // Snapshot synchronously so controller disposal cannot invalidate a pending save.
    final data = tabs.map((tab) {
      return {
        'fileName': tab.fileName,
        'language': tab.language,
        'code': tab.controller.text,
        'fileUri': tab.fileUri,
        'parentUri': tab.parentUri,
        'selectionBaseOffset': tab.selectionBaseOffset
            .clamp(0, tab.controller.text.length)
            .toInt(),
        'selectionExtentOffset': tab.selectionExtentOffset
            .clamp(0, tab.controller.text.length)
            .toInt(),
      };
    }).toList();
    final savedIndex = activeIndex;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bisho_tabs', jsonEncode(data));
      await prefs.setInt('bisho_active_index', savedIndex);
    } catch (_) {
      // Local recovery is best-effort and must never interrupt editing.
    } finally {
      _tabStateSaveInProgress = false;
      final completed = _tabStateSaveCompleter;
      _tabStateSaveCompleter = null;
      if (completed != null && !completed.isCompleted) {
        completed.complete();
      }
      if (_tabStateSavePending) {
        _tabStateSavePending = false;
        if (!_isDisposing) _scheduleTabStateSave();
      }
    }
  }

  String _mimeType(String name) {
    final ext =
        name.contains('.') ? name.split('.').last.toLowerCase() : '';

    // Avoid Android SAF providers adding .txt to build/config files.
    if (const {'gradle', 'properties', 'bat', 'sh'}.contains(ext) ||
        name.toLowerCase() == 'gradlew') {
      return 'application/octet-stream';
    }

    const types = {
      'dart': 'text/plain',
      'py': 'text/x-python',
      'js': 'text/javascript',
      'ts': 'text/typescript',
      'html': 'text/html',
      'htm': 'text/html',
      'css': 'text/css',
      'json': 'application/json',
      'xml': 'application/xml',
      'java': 'text/x-java-source',
      'kt': 'text/plain',
      'php': 'text/plain',
      'sql': 'text/plain',
      'txt': 'text/plain',
    };

    return types[ext] ?? 'application/octet-stream';
  }

  Future<bool> saveTabToSAF(EditorTab tab) async {
    if (tab.parentUri == null || tab.parentUri!.isEmpty) {
      return false;
    }

    final bytes = Uint8List.fromList(
      utf8.encode(tab.controller.text),
    );

    final document = await safFiles.saveFile(
      parentUri: tab.parentUri!,
      fileName: tab.fileName,
      mimeType: _mimeType(tab.fileName),
      bytes: bytes,
      overwrite: true,
    );

    tab.fileUri = document.uri;
    tab.isSaved = true;

    return true;
  }

  Future<void> saveAllTabs() async {
    try {
      int savedCount = 0;
      int skippedCount = 0;

      for (final tab in tabs) {
        if (tab.parentUri == null) {
          skippedCount++;
          continue;
        }

        await saveTabToSAF(tab);
        savedCount++;
      }

      await saveTabStateSilently();

      if (!mounted) return;

      setState(() {
        status = 'تم حفظ $savedCount ملف';
      });

      if (skippedCount > 0) {
        showMessage(
          'تم حفظ $savedCount ملف. '
          '$skippedCount ملف يحتاج إلى تصدير منفصل.',
        );
      } else {
        showMessage('تم حفظ جميع الملفات');
      }
    } catch (e) {
      showMessage('تعذر حفظ بعض الملفات: $e');
    }
  }

  Future<void> _confirmApplicationExit() async {
    if (!mounted) return;
    final unsavedCount = tabs.where((tab) => !tab.isSaved).length;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('الخروج من Bisho IDE؟'),
        content: Text(
          unsavedCount > 0
              ? 'لديك $unsavedCount ملف غير محفوظ. يمكنك حفظ الملفات المرتبطة بالمشروع، أو الخروج مع الاحتفاظ بنسخة الجلسة لاستعادتها عند فتح التطبيق مجددًا.'
              : 'سيتم حفظ جلسة العمل والتبويبات المفتوحة قبل إغلاق التطبيق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: const Text('إلغاء'),
          ),
          if (unsavedCount > 0)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'session'),
              child: const Text('الخروج مع حفظ الجلسة'),
            ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            icon: const Icon(Icons.save_rounded),
            label: Text(unsavedCount > 0 ? 'حفظ ثم خروج' : 'حفظ الجلسة والخروج'),
          ),
        ],
      ),
    );
    if (choice == null || choice == 'cancel' || !mounted) return;

    try {
      if (choice == 'save' && unsavedCount > 0) {
        await saveAllTabs();
      }
      await saveTabStateSilently();
    } catch (error) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تعذر إكمال الحفظ'),
          content: Text('حدث خطأ أثناء حفظ الجلسة: $error\nهل تريد الخروج على أي حال؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('البقاء في التطبيق'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('الخروج'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (mounted) await SystemNavigator.pop();
  }

  void createNewTab() {
    setState(() {
      tabs.add(createTab());
      activeIndex = tabs.length - 1;
      status = 'تم إنشاء ملف جديد';
    });

    saveTabStateSilently();
  }

  void selectTab(int index) {
    if (index < 0 || index >= tabs.length) return;

    setState(() {
      activeIndex = index;
      status = 'تم فتح ${activeTab.fileName}';
    });
    saveTabStateSilently();
  }

  Future<void> closeTab(int index) async {
    if (index < 0 || index >= tabs.length) return;

    final tab = tabs[index];

    if (!tab.isSaved) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('إغلاق الملف؟'),
          content: Text(
            'الملف ${tab.fileName} يحتوي على تعديلات غير محفوظة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إغلاق بدون حفظ'),
            ),
          ],
        ),
      );

      if (result != true || !mounted) return;
    }

    setState(() {
      tab.controller.dispose();
      tabs.removeAt(index);

      if (tabs.isEmpty) {
        tabs.add(createTab());
        activeIndex = 0;
      } else if (activeIndex > index) {
        activeIndex--;
      } else if (activeIndex >= tabs.length) {
        activeIndex = tabs.length - 1;
      }
    });

    await saveTabStateSilently();
  }

  String detectLanguage(String extension) =>
      LanguageIdentity.fromFileName('file.$extension').name;

  Future<void> openFile() async {
    try {
      final file = await saf.pickFile(
        persistablePermission: true,
      );

      if (file == null) return;

      final bytes = await safFiles.readFile(file.uri);
      final content = utf8.decode(bytes, allowMalformed: true);

      final extension =
          file.name.contains('.') ? file.name.split('.').last : '';

      final language = detectLanguage(extension);

      final existingIndex = tabs.indexWhere(
        (tab) => tab.fileUri == file.uri,
      );

      if (existingIndex != -1) {
        selectTab(existingIndex);
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        return;
      }

      setState(() {
        tabs.add(
          createTab(
            fileName: file.name,
            language: language,
            code: content,
            fileUri: file.uri,
            parentUri: null,
            isSaved: true,
          ),
        );

        activeIndex = tabs.length - 1;
        status = 'تم فتح الملف';
      });

      await saveTabStateSilently();
    } catch (e) {
      showMessage('تعذر فتح الملف: $e');
    }
  }

  /// استيراد مشروع موجود من مساحة تخزين Android عبر SAF.
  ///
  /// لا ينسخ ملفات المستخدم ولا ينقلها؛ بل يمنح التطبيق صلاحية مستمرة
  /// للمجلد المختار ويعيّنه كجذر المشروع الحالي داخل مستكشف Bisho IDE.
  /// تبقى الملفات في مكانها الأصلي ويمكن تحريرها وحفظها مباشرة.
  Future<void> importExistingProject() async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استيراد مشروع موجود'),
        content: const Text(
          'اختر مجلد المشروع من ذاكرة الجهاز. '
          'سيتم ربطه بمستكشف Bisho IDE مع الاحتفاظ بملفاته في مكانها الأصلي، '
          'ويمكنك فتح الملفات وتعديلها وحفظها مباشرة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('اختيار مجلد'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await openProjectFolder();
    if (!mounted) return;
    if (projectUri != null && projectUri!.isNotEmpty) {
      try {
        final root = await safFiles.getItem(projectUri!);
        if (root == null || !root.isDir) {
          showMessage('تعذر التحقق من مجلد المشروع المستورد');
          return;
        }
        final children = await safFiles.listDirectory(projectUri!);
        showMessage(
          'تم استيراد "$projectName" بنجاح • ${children.length} عنصر في المجلد الرئيسي',
        );
      } catch (error) {
        showMessage('تم ربط المشروع، لكن تعذر قراءة محتوياته: $error');
      }
    }
  }

  Future<void> openProjectFolder() async {
    try {
      final directory = await safFiles.pickProjectFolder();

      if (directory == null) return;

      if (projectUri == directory.uri) {
        refreshExplorer();
        showMessage('هذا المشروع مفتوح بالفعل');
        return;
      }

      final projectTabs = tabs
          .where((tab) =>
              tab.parentUri != null && tab.parentUri!.isNotEmpty)
          .toList();

      final unsavedCount =
          projectTabs.where((tab) => !tab.isSaved).length;

      if (projectUri != null && projectTabs.isNotEmpty) {
        final message = unsavedCount > 0
            ? 'يوجد $unsavedCount ملف غير محفوظ في المشروع الحالي.\n\n'
                'ستبقى التبويبات القديمة مفتوحة ومرتبطة بمجلداتها الأصلية. '
                'لن يتم نقلها إلى المشروع الجديد.'
            : 'ستبقى تبويبات المشروع الحالي مفتوحة ومرتبطة بمجلداتها الأصلية. '
                'لن يتم نقلها إلى المشروع الجديد.';

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تغيير المشروع؟'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('متابعة'),
              ),
            ],
          ),
        );

        if (confirmed != true || !mounted) return;
      }

      await saveTabStateSilently();

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('bisho_project_uri', directory.uri);
      await prefs.setString('bisho_project_name', directory.name);

      await prefs.remove(_savedDirectoryUriKey);
      await prefs.remove(_savedDirectoryNameKey);

      if (!mounted) return;

      setState(() {
        projectUri = directory.uri;
        projectName = directory.name;

        selectedDirectoryUri = null;
        selectedDirectoryName = '';

        explorerVisible = true;
        _explorerRevision++;
        status = 'تم فتح المشروع عبر SAF';
      });

      showMessage('تم فتح مجلد المشروع');
    } catch (e) {
      showMessage('تعذر فتح المجلد: $e');
    }
  }

  /// إنشاء مشروع جديد باستخدام معالج المشاريع وSAF.
  Future<void> createNewProject() async {
    bool firstDirectory = true;

    try {
      await NewProjectWizard.show(
        context,
        pickLocation: () async {
          final folder = await safFiles.pickProjectFolder();

          if (folder == null) return null;

          return ProjectSaveLocation(
            uri: folder.uri,
            name: folder.name,
          );
        },
        createDirectory: (parentUri, directoryName) async {
          final existing = await safFiles.findChild(
            parentUri: parentUri,
            name: directoryName,
          );

          if (firstDirectory) {
            firstDirectory = false;

            if (existing != null) {
              throw Exception(
                'يوجد عنصر بالاسم "$directoryName" '
                'في مجلد الحفظ. اختر اسمًا آخر أو مجلدًا مختلفًا.',
              );
            }
          } else {
            if (existing != null) {
              if (existing.isDir) {
                return existing.uri;
              }

              throw Exception(
                'يوجد ملف بالاسم "$directoryName" '
                'ولا يمكن استخدامه كمجلد.',
              );
            }
          }

          final folder = await safFiles.createFolder(
            parentUri: parentUri,
            folderName: directoryName,
          );

          return folder.uri;
        },
        writeFile: (
          parentUri,
          fileName,
          mimeType,
          bytes,
        ) async {
          await safFiles.saveFile(
            parentUri: parentUri,
            fileName: fileName,
            mimeType: mimeType,
            bytes: Uint8List.fromList(bytes),
            overwrite: false,
          );
        },
        deleteDirectoryTree: (rootUri) => safFiles.deleteTree(rootUri),
        onCreated: (project) async {
          final prefs = await SharedPreferences.getInstance();

          await prefs.setString(
            'bisho_project_uri',
            project.rootUri,
          );

          await prefs.setString(
            'bisho_project_name',
            project.name,
          );

          await prefs.remove(_savedDirectoryUriKey);
          await prefs.remove(_savedDirectoryNameKey);

          if (!mounted) return;

          setState(() {
            projectUri = project.rootUri;
            projectName = project.name;

            selectedDirectoryUri = null;
            selectedDirectoryName = '';

            explorerVisible = true;
            _explorerRevision++;

            status = 'تم إنشاء المشروع ${project.name}';
          });

          // البحث عن ملف البداية داخل المشروع.
          try {
            final segments = project.entryFile
                .split('/')
                .where((segment) => segment.isNotEmpty)
                .toList();

            var currentUri = project.rootUri;
            SafDocumentFile? entryFile;
            var entryParentUri = currentUri;

            for (var i = 0; i < segments.length; i++) {
              final found = await safFiles.findChild(
                parentUri: currentUri,
                name: segments[i],
              );

              if (found == null) {
                break;
              }

              if (i == segments.length - 1) {
                if (!found.isDir) {
                  entryFile = found;
                  entryParentUri = currentUri;
                }
              } else {
                if (!found.isDir) {
                  break;
                }

                currentUri = found.uri;
              }
            }

            if (!mounted) return;

            if (entryFile != null) {
              // لا تغلق المسار الحالي هنا: معالج إنشاء المشروع
              // مسؤول عن إغلاق نافذته بعد اكتمال onCreated.
              await openProjectFile(
                entryFile,
                entryParentUri,
                closeOverlay: false,
              );
            } else {
              showMessage(
                'تم إنشاء المشروع، لكن تعذر العثور على ملف البداية.',
              );
            }
          } catch (e) {
            showMessage(
              'تم إنشاء المشروع، لكن تعذر فتح ملف البداية: $e',
            );
          }

          await saveTabStateSilently();

          if (!mounted) return;

          if (project.isFlutterSourceOnly) {
            showMessage(
              'تم إنشاء مشروع Flutter مع هيكل Android وملفات Gradle محليًا. '
              'يمكنك الآن ربط GitHub لإنشاء المستودع ورفع المشروع وبدء البناء تلقائيًا.',
            );
          } else {
            showMessage(
              'تم إنشاء المشروع وفتح ملف البداية بنجاح',
            );
          }
        },
      );
    } catch (e) {
      if (!mounted) return;

      showMessage('تعذر إنشاء المشروع: $e');
    }
  }

  Future<void> openProjectFile(
    SafDocumentFile file,
    String parentUri, {
    bool closeOverlay = true,
  }) async {
    try {
      final bytes = await safFiles.readFile(file.uri);
      final content = utf8.decode(bytes, allowMalformed: true);

      final extension =
          file.name.contains('.') ? file.name.split('.').last : '';

      final language = detectLanguage(extension);

      final existingIndex = tabs.indexWhere(
        (tab) => tab.fileUri == file.uri,
      );

      if (existingIndex != -1) {
        selectTab(existingIndex);
        if (closeOverlay && Navigator.of(context).canPop()) Navigator.of(context).pop();
        return;
      }

      setState(() {
        tabs.add(
          createTab(
            fileName: file.name,
            language: language,
            code: content,
            fileUri: file.uri,
            parentUri: parentUri,
            isSaved: true,
          ),
        );

        activeIndex = tabs.length - 1;
        status = 'تم فتح ${file.name}';
      });

      await saveTabStateSilently();
      if (closeOverlay && mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      showMessage('تعذر قراءة الملف: $e');
    }
  }

  Future<void> createProjectFile() async {
    final targetUri = creationDirectoryUri;

    if (targetUri == null || targetUri.isEmpty) {
      showMessage('افتح مجلد مشروع أولاً');
      return;
    }

    final targetName = creationDirectoryName;

    final name = await askName(
      'إنشاء ملف داخل $targetName',
      'مثال: main.dart',
    );

    if (name == null || name.trim().isEmpty || !mounted) return;

    final fileName = name.trim();

    if (fileName.contains('/') || fileName.contains('\\')) {
      showMessage('اكتب اسم ملف فقط');
      return;
    }

    try {
      final document = await safFiles.saveFile(
        parentUri: targetUri,
        fileName: fileName,
        mimeType: _mimeType(fileName),
        bytes: Uint8List(0),
        overwrite: false,
      );

      final language = detectLanguage(
        fileName.contains('.') ? fileName.split('.').last : '',
      );

      if (!mounted) return;

      setState(() {
        tabs.add(
          createTab(
            fileName: fileName,
            language: language,
            code: '',
            fileUri: document.uri,
            parentUri: targetUri,
            isSaved: true,
          ),
        );

        activeIndex = tabs.length - 1;
        _explorerRevision++;
        status = 'تم إنشاء الملف داخل $targetName';
      });

      await saveTabStateSilently();
      showMessage('تم إنشاء الملف داخل $targetName');
    } catch (e) {
      showMessage('تعذر إنشاء الملف: $e');
    }
  }

  Future<void> createProjectFolder() async {
    final targetUri = creationDirectoryUri;

    if (targetUri == null || targetUri.isEmpty) {
      showMessage('افتح مجلد مشروع أولاً');
      return;
    }

    final targetName = creationDirectoryName;

    final name = await askName(
      'إنشاء مجلد داخل $targetName',
      'اسم المجلد',
    );

    if (name == null || name.trim().isEmpty || !mounted) return;

    final folderName = name.trim();

    if (folderName.contains('/') || folderName.contains('\\')) {
      showMessage('اكتب اسم مجلد فقط');
      return;
    }

    try {
      await safFiles.createFolder(
        parentUri: targetUri,
        folderName: folderName,
      );

      if (!mounted) return;

      setState(() {
        _explorerRevision++;
        status = 'تم إنشاء المجلد داخل $targetName';
      });

      showMessage('تم إنشاء المجلد داخل $targetName');
    } catch (e) {
      showMessage('تعذر إنشاء المجلد: $e');
    }
  }

  Future<String?> askName(String title, String hint) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('موافق'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<List<_SafTreeEntry>> collectSubtree(
    SafDocumentFile root,
  ) async {
    final result = <_SafTreeEntry>[];
    final visited = <String>{};

    Future<void> visit(
      SafDocumentFile item, {
      required String relativePath,
      required String? parentUri,
      int depth = 0,
    }) async {
      if (depth > 64) {
        throw StateError('تجاوز عمق المشروع الحد المسموح أثناء فحص الملفات.');
      }
      if (!visited.add(item.uri)) return;

      result.add(
        _SafTreeEntry(
          uri: item.uri,
          name: item.name,
          relativePath: relativePath,
          parentUri: parentUri,
          isDir: item.isDir,
        ),
      );

      if (!item.isDir) return;

      final children = await safFiles.listDirectory(item.uri);

      for (final child in children) {
        final childPath = relativePath.isEmpty
            ? child.name
            : '$relativePath/${child.name}';

        await visit(
          child,
          relativePath: childPath,
          parentUri: item.uri,
          depth: depth + 1,
        );
      }
    }

    await visit(
      root,
      relativePath: '',
      parentUri: null,
    );

    return result;
  }

  Future<SafDocumentFile> _copySafTree(
    SafDocumentFile source,
    String targetParentUri, {
    String? targetName,
    int depth = 0,
  }) async {
    if (depth > 64) {
      throw StateError('تجاوز عمق المجلد الحد المسموح أثناء النسخ.');
    }
    if (source.isDir) {
      final destination = await safFiles.createFolder(
        parentUri: targetParentUri,
        folderName: targetName ?? source.name,
      );
      try {
        final children = await safFiles.listDirectory(source.uri);
        for (final child in children) {
          await _copySafTree(child, destination.uri, depth: depth + 1);
        }
        return destination;
      } catch (_) {
        try { await safFiles.deleteTree(destination.uri); } catch (_) { /* Preserve the original even if cleanup is unavailable. */ }
        rethrow;
      }
    }
    final openTabIndex = tabs.indexWhere((tab) => tab.fileUri == source.uri);
    final bytes = openTabIndex >= 0
        ? utf8.encode(tabs[openTabIndex].controller.text)
        : await safFiles.readFile(source.uri);
    return safFiles.saveFile(
      parentUri: targetParentUri,
      fileName: targetName ?? source.name,
      mimeType: SafFileService.mimeTypeForName(targetName ?? source.name),
      bytes: Uint8List.fromList(bytes),
      overwrite: false,
    );
  }

  Future<void> copyOrMoveEntity(
    SafDocumentFile entity, {required bool move}) async {
    SafDocumentFile? copiedRoot;
    var copyCompleted = false;
    try {
      final destination = await safFiles.pickProjectFolder();
      if (destination == null || !mounted) return;
      final oldTree = await collectSubtree(entity);
      if (oldTree.any((entry) => entry.uri == destination.uri)) {
        showMessage('لا يمكن نسخ أو نقل مجلد إلى نفسه أو إلى أحد مجلداته');
        return;
      }
      final collision = await safFiles.findChild(
        parentUri: destination.uri, name: entity.name);
      if (collision != null) {
        showMessage('يوجد عنصر باسم ${entity.name} في مجلد الوجهة؛ لم يتم استبداله');
        return;
      }
      final copied = await _copySafTree(entity, destination.uri);
      copiedRoot = copied;
      copyCompleted = true;
      if (!move) {
        if (!mounted) return;
        setState(() {
          _explorerRevision++;
          status = 'تم نسخ ${entity.name}';
        });
        showMessage('تم نسخ ${entity.name} إلى ${destination.name}');
        return;
      }

      // Copy completes and is enumerated before deleting the source.
      final newTree = entity.isDir
          ? await collectSubtree(copied)
          : <_SafTreeEntry>[
              _SafTreeEntry(uri: copied.uri, name: copied.name,
                relativePath: '', parentUri: destination.uri, isDir: false),
            ];
      await safFiles.deleteItem(entity.uri);
      final oldByUri = <String, _SafTreeEntry>{
        for (final item in oldTree) item.uri: item,
      };
      final newByPath = <String, _SafTreeEntry>{
        for (final item in newTree) item.relativePath: item,
      };
      for (final tab in tabs) {
        final oldFile = tab.fileUri == null ? null : oldByUri[tab.fileUri];
        if (oldFile != null) {
          final replacement = newByPath[oldFile.relativePath];
          if (replacement != null) {
            tab.fileUri = replacement.uri;
            tab.fileName = replacement.name;
          }
        }
        if (tab.parentUri != null && oldByUri.containsKey(tab.parentUri)) {
          final oldParent = oldByUri[tab.parentUri];
          final replacement = oldParent == null ? null : newByPath[oldParent.relativePath];
          if (replacement != null) tab.parentUri = replacement.uri;
        } else if (!entity.isDir && tab.fileUri == copied.uri) {
          tab.parentUri = destination.uri;
        }
      }
      if (selectedDirectoryUri != null && oldByUri.containsKey(selectedDirectoryUri)) {
        final oldSelected = oldByUri[selectedDirectoryUri];
        final replacement = oldSelected == null ? null : newByPath[oldSelected.relativePath];
        if (replacement != null) {
          selectedDirectoryUri = replacement.uri;
          selectedDirectoryName = replacement.name;
        }
      }
      if (!mounted) return;
      setState(() {
        _explorerRevision++;
        status = 'تم نقل ${entity.name}';
      });
      await _saveSelectedDirectoryState();
      await saveTabStateSilently();
      showMessage('تم نقل ${entity.name} بنجاح');
    } catch (error) {
      if (!copyCompleted && copiedRoot != null) {
        try { await safFiles.deleteTree(copiedRoot.uri); } catch (_) { /* Keep original; report cleanup failure below. */ }
      }
      refreshExplorer();
      showMessage('تعذرت عملية ${move ? 'النقل' : 'النسخ'}: $error');
    }
  }

  Future<void> renameEntity(SafDocumentFile entity) async {
    final name = await askName('إعادة تسمية', entity.name);

    if (name == null || name.trim().isEmpty || !mounted) return;

    final newName = name.trim();

    if (newName.contains('/') || newName.contains('\\')) {
      showMessage('اكتب اسمًا فقط');
      return;
    }

    if (newName == entity.name) return;

    try {
      final oldTree = await collectSubtree(entity);

      final renamed = await safFiles.renameItem(
        uri: entity.uri,
        newName: newName,
      );

      if (entity.isDir) {
        final newTree = await collectSubtree(renamed);

        final oldByUri = <String, _SafTreeEntry>{
          for (final item in oldTree) item.uri: item,
        };

        final newByPath = <String, _SafTreeEntry>{
          for (final item in newTree) item.relativePath: item,
        };

        if (selectedDirectoryUri != null) {
          final selectedEntry = oldByUri[selectedDirectoryUri];

          if (selectedEntry != null) {
            final newSelectedEntry =
                newByPath[selectedEntry.relativePath];

            if (newSelectedEntry != null) {
              selectedDirectoryUri = newSelectedEntry.uri;
              selectedDirectoryName = newSelectedEntry.name;
            }
          }
        }

        for (final tab in tabs) {
          final oldFileEntry = tab.fileUri == null
              ? null
              : oldByUri[tab.fileUri];

          if (oldFileEntry != null) {
            final newFileEntry =
                newByPath[oldFileEntry.relativePath];

            if (newFileEntry != null) {
              tab.fileUri = newFileEntry.uri;
              tab.fileName = newFileEntry.name;
            }
          }

          if (tab.parentUri != null) {
            final oldParentEntry = oldByUri[tab.parentUri];

            if (oldParentEntry != null) {
              final newParentEntry =
                  newByPath[oldParentEntry.relativePath];

              if (newParentEntry != null) {
                tab.parentUri = newParentEntry.uri;
              }
            }
          }
        }
      } else {
        for (final tab in tabs) {
          if (tab.fileUri == entity.uri) {
            tab.fileUri = renamed.uri;
            tab.fileName = renamed.name;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _explorerRevision++;
        status = 'تم تغيير الاسم';
      });

      await _saveSelectedDirectoryState();
      await saveTabStateSilently();

      if (!mounted) return;

      showMessage('تم تغيير الاسم وتحديث البيانات المحفوظة');
    } catch (e) {
      refreshExplorer();
      showMessage('تعذرت إعادة التسمية أو تحديث التبويبات: $e');
    }
  }

  Future<void> deleteEntity(SafDocumentFile entity) async {
    try {
      final subtree = await collectSubtree(entity);

      final deletedUris = subtree.map((item) => item.uri).toSet();

      final affectedTabs = tabs.where((tab) {
        final fileIsInside = tab.fileUri != null &&
            deletedUris.contains(tab.fileUri);

        final parentIsInside = tab.parentUri != null &&
            deletedUris.contains(tab.parentUri);

        return fileIsInside || parentIsInside;
      }).toList();

      final unsavedCount =
          affectedTabs.where((tab) => !tab.isSaved).length;

      final message = unsavedCount > 0
          ? 'هل تريد حذف ${entity.name}؟\n\n'
              'يوجد $unsavedCount ملف مفتوح يحتوي على تعديلات غير محفوظة. '
              'سيتم إغلاق التبويبات التابعة لهذا العنصر وفقدان تعديلاتها.'
          : 'هل تريد حذف ${entity.name}؟';

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      final activeId =
          tabs.isNotEmpty ? activeTab.id : null;
      final oldActiveIndex = activeIndex;

      await safFiles.deleteItem(entity.uri);

      final selectedDirectoryWasDeleted =
          selectedDirectoryUri != null &&
          deletedUris.contains(selectedDirectoryUri);

      if (selectedDirectoryWasDeleted) {
        selectedDirectoryUri = null;
        selectedDirectoryName = '';

        await _clearSavedDirectoryState();
      }

      for (final tab in affectedTabs) {
        tab.controller.dispose();
      }

      tabs.removeWhere((tab) => affectedTabs.contains(tab));

      if (tabs.isEmpty) {
        tabs.add(createTab());
        activeIndex = 0;
      } else {
        final preservedIndex = activeId == null
            ? -1
            : tabs.indexWhere((tab) => tab.id == activeId);

        if (preservedIndex != -1) {
          activeIndex = preservedIndex;
        } else {
          activeIndex = oldActiveIndex
              .clamp(0, tabs.length - 1)
              .toInt();
        }
      }

      if (!mounted) return;

      setState(() {
        _explorerRevision++;
        status = selectedDirectoryWasDeleted
            ? 'تم الحذف والعودة إلى جذر المشروع'
            : 'تم حذف العنصر';
      });

      await saveTabStateSilently();

      if (!mounted) return;

      showMessage(
        selectedDirectoryWasDeleted
            ? 'تم الحذف والعودة إلى جذر المشروع'
            : 'تم الحذف وإغلاق التبويبات التابعة',
      );
    } catch (e) {
      refreshExplorer();
      showMessage('تعذر حذف العنصر: $e');
    }
  }

  Future<void> saveCurrentToDisk() async {
    final tab = activeTab;

    if (tab.parentUri == null) {
      showMessage('هذا الملف مستقل. استخدم تصدير لحفظ التعديلات.');
      return;
    }

    try {
      await saveTabToSAF(tab);

      if (!mounted) return;

      setState(() {
        status = 'تم حفظ ${tab.fileName}';
      });

      await saveTabStateSilently();
      showMessage('تم حفظ الملف');
    } catch (e) {
      showMessage('تعذر حفظ الملف: $e');
    }
  }

  Future<void> exportFile() async {
    try {
      final bytes = Uint8List.fromList(
        utf8.encode(activeTab.controller.text),
      );
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'تصدير الملف',
        fileName: activeTab.fileName,
        bytes: bytes,
      );
      if (path != null && mounted) {
        // Exporting a copy does not save the original SAF-backed document.
        setState(() => status = 'تم تصدير نسخة من الملف');
        showMessage('تم تصدير نسخة من الملف؛ حالة حفظ الملف الأصلي لم تتغير');
      }
    } catch (e) {
      showMessage('تعذر تصدير الملف: $e');
    }
  }

  Future<void> _addDirectoryToArchive(
    Archive archive,
    String directoryUri,
    String relativePath,
    Set<String> visitedUris,
    ProjectArchiveBudget budget, {
    int depth = 0,
  }) async {
    if (depth > 32) {
      throw FormatException('عمق مجلدات المشروع يتجاوز 32 مستوى.');
    }
    if (!visitedUris.add(directoryUri)) return;
    final children = await safFiles.listDirectory(directoryUri);
    for (final child in children) {
      final name = child.name.trim();
      if (name.isEmpty || name == '.' || name == '..' ||
          name.contains('/') || name.contains('\\')) {
        continue;
      }
      final childPath = relativePath.isEmpty ? name : '$relativePath/$name';
      if (child.isDir) {
        budget.registerEntry(childPath, byteCount: 0);
        archive.addFile(ArchiveFile('$childPath/', 0, <int>[]));
        await _addDirectoryToArchive(
          archive, child.uri, childPath, visitedUris, budget,
          depth: depth + 1,
        );
      } else {
        final bytes = await safFiles.readFile(child.uri);
        budget.registerEntry(childPath, byteCount: bytes.length);
        archive.addFile(ArchiveFile(childPath, bytes.length, bytes));
      }
    }
  }

  Future<void> _collectProjectBackup(
    String directoryUri,
    String relativePath,
    Map<String, List<int>> files,
    List<String> directories,
    Set<String> visitedUris, {
    int depth = 0,
    required List<int> budgetBytes,
  }) async {
    if (depth > 32) throw const FormatException('عمق المجلدات يتجاوز حد النسخ الاحتياطي.');
    if (!visitedUris.add(directoryUri)) throw const FormatException('تم اكتشاف حلقة أو URI مكرر في شجرة المشروع.');
    final children = await safFiles.listDirectory(directoryUri);
    for (final child in children) {
      final name = child.name;
      if (relativePath.isEmpty && child.isDir &&
          name == ProjectBackupRepository.directoryName) {
        continue; // Keep the repository outside its own snapshots.
      }
      if (name.trim().isEmpty || name == '.' || name == '..' || name.contains('/') || name.contains('\\')) {
        throw FormatException('اسم عنصر غير صالح أثناء النسخ الاحتياطي: ${child.name}');
      }
      final path = relativePath.isEmpty ? name : '$relativePath/$name';
      if (child.isDir) {
        directories.add(path);
        if (files.length + directories.length > ProjectBackupService.maxEntries) {
          throw const FormatException('عدد عناصر المشروع يتجاوز حد النسخ الاحتياطي.');
        }
        await _collectProjectBackup(child.uri, path, files, directories, visitedUris,
            depth: depth + 1, budgetBytes: budgetBytes);
      } else {
        final bytes = await safFiles.readFile(child.uri);
        if (bytes.length > ProjectBackupService.maxFileBytes ||
            budgetBytes[0] + bytes.length > ProjectBackupService.maxTotalBytes) {
          throw FormatException('حجم المشروع يتجاوز الحد المسموح عند الملف: $path');
        }
        files[path] = bytes;
        budgetBytes[0] += bytes.length;
        if (files.length + directories.length > ProjectBackupService.maxEntries) {
          throw const FormatException('عدد عناصر المشروع يتجاوز حد النسخ الاحتياطي.');
        }
      }
    }
  }

  Future<void> exportProjectBackup() async {
    var repositorySnapshotStored = false;
    if (projectUri == null || projectUri!.isEmpty) {
      showMessage('افتح مشروعًا أولاً لإنشاء نسخة احتياطية');
      return;
    }
    try {
      for (final tab in tabs) {
        if (tab.parentUri != null) {
          await saveTabToSAF(tab);
        } else if (!tab.isSaved) {
          throw StateError('الملف ${tab.fileName} غير مرتبط بمجلد المشروع ولم يُحفظ؛ احفظه أو صدّره قبل النسخ الاحتياطي.');
        }
      }
      final root = await safFiles.getItem(projectUri!);
      if (root == null || !root.isDir) throw Exception('مجلد المشروع غير متاح');
      final files = <String, List<int>>{};
      final directories = <String>[];
      await _collectProjectBackup(projectUri!, '', files, directories, <String>{}, budgetBytes: [0]);
      if (files.isEmpty && directories.isEmpty) throw Exception('المشروع فارغ');
      final manifest = const ProjectBackupService().encode(
        projectName: projectName,
        files: files,
        directories: directories,
      );
      final bytes = Uint8List.fromList(utf8.encode(manifest));
      await _storeProjectBackupSnapshot(
        manifestBytes: bytes,
        fileCount: files.length,
        directoryCount: directories.length,
        totalBytes: files.values.fold<int>(0, (sum, value) => sum + value.length),
      );
      repositorySnapshotStored = true;
      var safeName = projectName.trim().isEmpty
          ? 'bisho_project'
          : projectName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_. -]'), '_').replaceAll(RegExp(r'[. ]+$'), '');
      if (safeName.isEmpty || RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$', caseSensitive: false).hasMatch(safeName)) {
        safeName = 'bisho_project';
      }
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'إنشاء نسخة احتياطية كاملة',
        fileName: '$safeName.bisho-backup.json',
        bytes: bytes,
      );
      if (saved != null && mounted) {
        setState(() => status = 'تم إنشاء النسخة الاحتياطية');
        showMessage('تم حفظ نقطة استعادة داخل المشروع وتصدير نسخة تشمل ${files.length} ملفًا و${directories.length} مجلدًا');
      } else if (repositorySnapshotStored && mounted) {
        showMessage('تم حفظ نقطة الاستعادة داخل المشروع؛ تم إلغاء التصدير الخارجي.');
      }
    } catch (e) {
      showMessage(repositorySnapshotStored
          ? 'تم حفظ نقطة الاستعادة داخل المشروع، لكن تعذر إكمال التصدير الخارجي: $e'
          : 'تعذر إنشاء النسخة الاحتياطية: $e');
    }
  }

  Future<String> _ensureBackupRepositoryDirectory() async {
    if (projectUri == null || projectUri!.isEmpty) {
      throw StateError('افتح مشروعًا أولاً.');
    }
    final existing = await safFiles.findChild(
      parentUri: projectUri!, name: ProjectBackupRepository.directoryName,
    );
    if (existing != null) {
      if (!existing.isDir) throw StateError('مسار مستودع النسخ مستخدم كملف.');
      return existing.uri;
    }
    return (await safFiles.createFolder(
      parentUri: projectUri!, folderName: ProjectBackupRepository.directoryName,
    )).uri;
  }

  Future<List<ProjectBackupSnapshot>> _readProjectBackupCatalog(String repositoryUri) async {
    final catalogFile = await safFiles.findChild(
      parentUri: repositoryUri, name: ProjectBackupRepository.catalogFileName,
    );
    if (catalogFile == null) return const [];
    if (catalogFile.isDir) throw const FormatException('ملف فهرس النسخ هو مجلد.');
    final bytes = await safFiles.readFile(catalogFile.uri);
    return const ProjectBackupRepository().decodeCatalog(utf8.decode(bytes));
  }

  Future<void> _writeProjectBackupCatalog(
    String repositoryUri, List<ProjectBackupSnapshot> snapshots,
  ) async {
    final existing = await safFiles.findChild(
      parentUri: repositoryUri, name: ProjectBackupRepository.catalogFileName,
    );
    await safFiles.saveFile(
      parentUri: repositoryUri,
      fileName: ProjectBackupRepository.catalogFileName,
      mimeType: 'application/json',
      bytes: Uint8List.fromList(utf8.encode(
        const ProjectBackupRepository().encodeCatalog(snapshots),
      )),
      overwrite: existing != null,
    );
  }

  Future<void> _storeProjectBackupSnapshot({
    required Uint8List manifestBytes,
    required int fileCount,
    required int directoryCount,
    required int totalBytes,
  }) async {
    final repositoryUri = await _ensureBackupRepositoryDirectory();
    final repository = const ProjectBackupRepository();
    final oldSnapshots = await _readProjectBackupCatalog(repositoryUri);
    final id = 'snap_${DateTime.now().microsecondsSinceEpoch}';
    final snapshot = repository.createSnapshot(
      id: id, projectName: projectName, createdAt: DateTime.now(),
      fileCount: fileCount, directoryCount: directoryCount,
      totalBytes: totalBytes, manifestBytes: manifestBytes,
    );
    // Write immutable content first. A failed catalog update leaves only an
    // unreferenced file; it never destroys an existing restore point.
    await safFiles.saveFile(
      parentUri: repositoryUri, fileName: snapshot.fileName,
      mimeType: 'application/json', bytes: manifestBytes, overwrite: false,
    );
    final next = <ProjectBackupSnapshot>[snapshot, ...oldSnapshots]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final expired = next.length > ProjectBackupRepository.maxSnapshots
        ? next.sublist(ProjectBackupRepository.maxSnapshots) : <ProjectBackupSnapshot>[];
    final retained = next.take(ProjectBackupRepository.maxSnapshots).toList();
    await _writeProjectBackupCatalog(repositoryUri, retained);
    // Prune only after the new catalog is safely written.
    for (final item in expired) {
      final file = await safFiles.findChild(parentUri: repositoryUri, name: item.fileName);
      if (file != null && !file.isDir) await safFiles.deleteItem(file.uri);
    }
  }

  Future<void> manageProjectBackups() async {
    if (projectUri == null || projectUri!.isEmpty) {
      showMessage('افتح مشروعًا أولاً لعرض سجل النسخ.');
      return;
    }
    try {
      final repositoryUri = await _ensureBackupRepositoryDirectory();
      while (mounted) {
        final snapshots = await _readProjectBackupCatalog(repositoryUri);
        if (snapshots.isEmpty) {
          showMessage('لا توجد نقاط استعادة محفوظة لهذا المشروع بعد. أنشئ نسخة احتياطية أولاً.');
          return;
        }
        final choice = await showDialog<Map<String, Object?>>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('سجل النسخ ونقاط الاستعادة'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: snapshots.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = snapshots[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restore_rounded),
                    title: Text(item.createdAt.toLocal().toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${item.fileCount} ملف · ${item.directoryCount} مجلد · ${(item.totalBytes / 1048576).toStringAsFixed(2)} MB'),
                    trailing: Wrap(children: [
                      IconButton(
                        tooltip: 'استعادة هذه النقطة', icon: const Icon(Icons.settings_backup_restore_rounded),
                        onPressed: () => Navigator.pop(dialogContext, {'action': 'restore', 'snapshot': item}),
                      ),
                      IconButton(
                        tooltip: 'حذف نقطة الاستعادة', icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => Navigator.pop(dialogContext, {'action': 'delete', 'snapshot': item}),
                      ),
                    ]),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: snapshots.length < 2 ? null : () => Navigator.pop(dialogContext, {'action': 'compare'}),
                child: const Text('مقارنة نسختين'),
              ),
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
            ],
          ),
        );
        if (choice == null || !mounted) return;
        if (choice['action'] == 'compare') {
          await _compareProjectBackupSnapshots(repositoryUri, snapshots);
          continue;
        }
        final item = choice['snapshot'] as ProjectBackupSnapshot;
        if (choice['action'] == 'delete') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('حذف نقطة الاستعادة؟'),
              content: Text('سيتم حذف النسخة المؤرخة ${item.createdAt.toLocal()} دون التأثير على ملفات المشروع.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
              ],
            ),
          ) ?? false;
          if (!confirmed) continue;
          final latest = await _readProjectBackupCatalog(repositoryUri);
          final remaining = latest.where((entry) => entry.id != item.id).toList();
          await _writeProjectBackupCatalog(repositoryUri, remaining);
          final file = await safFiles.findChild(parentUri: repositoryUri, name: item.fileName);
          if (file != null && !file.isDir) await safFiles.deleteItem(file.uri);
          showMessage('تم حذف نقطة الاستعادة.');
          continue;
        }
        if (choice['action'] == 'restore') {
          final file = await safFiles.findChild(parentUri: repositoryUri, name: item.fileName);
          if (file == null || file.isDir) throw StateError('ملف نقطة الاستعادة غير موجود.');
          final bytes = await safFiles.readFile(file.uri);
          if (!const ProjectBackupRepository().verifyManifest(item, bytes)) {
            throw const FormatException('فشل التحقق من سلامة ملف نقطة الاستعادة.');
          }
          final backup = const ProjectBackupService().decode(utf8.decode(bytes));
          await _restoreRepositoryBackup(backup);
          return;
        }
      }
    } catch (e) {
      showMessage('تعذر فتح سجل النسخ الاحتياطية: $e');
    }
  }

  Future<void> _compareProjectBackupSnapshots(
    String repositoryUri, List<ProjectBackupSnapshot> snapshots,
  ) async {
    if (snapshots.length < 2 || !mounted) return;
    var olderId = snapshots[1].id;
    var newerId = snapshots.first.id;
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('مقارنة نقطتي استعادة'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: olderId,
              decoration: const InputDecoration(labelText: 'النسخة الأقدم'),
              items: snapshots.map((item) => DropdownMenuItem(
                value: item.id,
                child: Text(item.createdAt.toLocal().toString(), overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (value) => setDialogState(() => olderId = value ?? olderId),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: newerId,
              decoration: const InputDecoration(labelText: 'النسخة الأحدث'),
              items: snapshots.map((item) => DropdownMenuItem(
                value: item.id,
                child: Text(item.createdAt.toLocal().toString(), overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (value) => setDialogState(() => newerId = value ?? newerId),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: olderId == newerId ? null : () => Navigator.pop(dialogContext, [olderId, newerId]),
              child: const Text('مقارنة'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final older = snapshots.firstWhere((item) => item.id == selected[0]);
    final newer = snapshots.firstWhere((item) => item.id == selected[1]);
    Future<Map<String, String>> readChecksums(ProjectBackupSnapshot snapshot) async {
      final file = await safFiles.findChild(parentUri: repositoryUri, name: snapshot.fileName);
      if (file == null || file.isDir) throw StateError('ملف النسخة ${snapshot.fileName} غير موجود.');
      final bytes = await safFiles.readFile(file.uri);
      if (!const ProjectBackupRepository().verifyManifest(snapshot, bytes)) {
        throw FormatException('فشل التحقق من سلامة النسخة ${snapshot.fileName}.');
      }
      final backup = const ProjectBackupService().decode(utf8.decode(bytes));
      return {for (final entry in backup.files.entries) entry.key: entry.value.checksum};
    }
    try {
      final oldChecksums = await readChecksums(older);
      final newChecksums = await readChecksums(newer);
      final report = const ProjectBackupRepository().compareFileChecksums(
        older: oldChecksums, newer: newChecksums,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('نتيجة مقارنة النسختين'),
          content: SingleChildScrollView(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ملفات مضافة: ${report.added.length}'),
              Text('ملفات محذوفة: ${report.removed.length}'),
              Text('ملفات معدّلة: ${report.changed.length}'),
              Text('ملفات دون تغيير: ${report.unchanged.length}'),
              const Divider(),
              for (final entry in [
                ('مضافة', report.added), ('محذوفة', report.removed),
                ('معدّلة', report.changed),
              ]) ...[
                if (entry.$2.isNotEmpty) Text(entry.$1, style: const TextStyle(fontWeight: FontWeight.bold)),
                for (final path in entry.$2) Text('• $path'),
              ],
            ],
          )),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
        ),
      );
    } catch (e) {
      showMessage('تعذرت مقارنة النسختين: $e');
    }
  }

  Future<void> _restoreRepositoryBackup(ProjectBackup backup) async {
    String? createdRootUri;
    try {
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تأكيد استعادة نقطة محددة'),
          content: Text(
            'المشروع: ${backup.projectName}\n'
            'الملفات: ${backup.files.length}\n'
            'المجلدات: ${backup.directories.length}\n'
            'الحجم: ${(backup.totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB\n'
            'التاريخ: ${backup.createdAt.toLocal()}\n\n'
            'سيتم إنشاء مجلد جديد ولن يتم استبدال مشروع موجود.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('استعادة')),
          ],
        ),
      ) ?? false;
      if (!approved || !mounted) return;
      final parent = await safFiles.pickProjectFolder();
      if (parent == null) return;
      var folderName = backup.projectName.replaceAll(RegExp(r'[^a-zA-Z0-9_ .-]'), '_').trim()
          .replaceAll(RegExp(r'[. ]+$'), '');
      if (folderName.isEmpty || folderName == '.' || folderName == '..' ||
          RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$', caseSensitive: false).hasMatch(folderName)) {
        folderName = 'Restored_Project';
      }
      if (await safFiles.findChild(parentUri: parent.uri, name: folderName) != null) {
        folderName = '${folderName}_restored_${DateTime.now().millisecondsSinceEpoch}';
      }
      final root = await safFiles.createFolder(parentUri: parent.uri, folderName: folderName);
      createdRootUri = root.uri;
      for (final directory in backup.directories) {
        await _ensureBackupDirectory(root.uri, directory);
      }
      for (final file in backup.files.values) {
        final segments = file.path.split('/');
        final parentPath = segments.length == 1 ? '' : segments.take(segments.length - 1).join('/');
        final targetParent = parentPath.isEmpty ? root.uri : await _ensureBackupDirectory(root.uri, parentPath);
        await safFiles.saveFile(
          parentUri: targetParent, fileName: segments.last,
          mimeType: SafFileService.mimeTypeForName(segments.last),
          bytes: Uint8List.fromList(file.bytes), overwrite: false,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bisho_project_uri', root.uri);
      await prefs.setString('bisho_project_name', folderName);
      await prefs.remove(_savedDirectoryUriKey);
      await prefs.remove(_savedDirectoryNameKey);
      if (!mounted) return;
      setState(() {
        projectUri = root.uri; projectName = folderName;
        selectedDirectoryUri = null; selectedDirectoryName = '';
        explorerVisible = true; _explorerRevision++;
        status = 'تمت استعادة نقطة النسخة الاحتياطية';
      });
      await saveTabStateSilently();
      showMessage('تمت استعادة ${backup.files.length} ملفًا من نقطة بتاريخ ${backup.createdAt.toLocal()}');
    } catch (e) {
      if (createdRootUri != null) {
        try { await safFiles.deleteTree(createdRootUri); }
        catch (cleanupError) {
          showMessage('فشلت الاستعادة وتعذر تنظيف المجلد الجزئي: $cleanupError');
          return;
        }
      }
      showMessage('تعذرت استعادة نقطة النسخة: $e');
    }
  }

  Future<String> _ensureBackupDirectory(String rootUri, String relativePath) async {
    var current = rootUri;
    for (final segment in relativePath.split('/')) {
      final existing = await safFiles.findChild(parentUri: current, name: segment);
      if (existing != null && !existing.isDir) throw FormatException('تعارض ملف ومجلد أثناء الاستعادة: $segment');
      current = existing?.uri ?? (await safFiles.createFolder(parentUri: current, folderName: segment)).uri;
    }
    return current;
  }

  Future<void> restoreProjectBackup() async {
    String? createdRootUri;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
        allowMultiple: false,
      );
      if (picked == null || picked.files.isEmpty) return;
      final bytes = picked.files.single.bytes;
      if (bytes == null || bytes.isEmpty) throw Exception('تعذر قراءة ملف النسخة الاحتياطية');
      final backup = const ProjectBackupService().decode(utf8.decode(bytes));
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تأكيد استعادة النسخة'),
          content: Text(
            'المشروع: ${backup.projectName}\n'
            'الملفات: ${backup.files.length}\n'
            'المجلدات: ${backup.directories.length}\n'
            'الحجم: ${(backup.totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB\n'
            'تاريخ النسخة: ${backup.createdAt.toLocal()}\n\n'
            'سيتم إنشاء مجلد مشروع جديد ولن يتم استبدال الملفات الموجودة.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('متابعة الاستعادة')),
          ],
        ),
      ) ?? false;
      if (!approved || !mounted) return;
      final parent = await safFiles.pickProjectFolder();
      if (parent == null) return;
      var folderName = backup.projectName.replaceAll(RegExp(r'[^a-zA-Z0-9_ .-]'), '_').trim()
          .replaceAll(RegExp(r'[. ]+$'), '');
      if (folderName.isEmpty || folderName == '.' || folderName == '..' ||
          RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$', caseSensitive: false).hasMatch(folderName)) {
        folderName = 'Restored_Project';
      }
      if (await safFiles.findChild(parentUri: parent.uri, name: folderName) != null) {
        folderName = '${folderName}_restored_${DateTime.now().millisecondsSinceEpoch}';
      }
      final root = await safFiles.createFolder(parentUri: parent.uri, folderName: folderName);
      createdRootUri = root.uri;
      for (final directory in backup.directories) {
        await _ensureBackupDirectory(root.uri, directory);
      }
      for (final file in backup.files.values) {
        final segments = file.path.split('/');
        final parentPath = segments.length == 1 ? '' : segments.take(segments.length - 1).join('/');
        final targetParent = parentPath.isEmpty ? root.uri : await _ensureBackupDirectory(root.uri, parentPath);
        await safFiles.saveFile(
          parentUri: targetParent,
          fileName: segments.last,
          mimeType: SafFileService.mimeTypeForName(segments.last),
          bytes: Uint8List.fromList(file.bytes),
          overwrite: false,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bisho_project_uri', root.uri);
      await prefs.setString('bisho_project_name', folderName);
      await prefs.remove(_savedDirectoryUriKey);
      await prefs.remove(_savedDirectoryNameKey);
      if (!mounted) return;
      setState(() {
        projectUri = root.uri;
        projectName = folderName;
        selectedDirectoryUri = null;
        selectedDirectoryName = '';
        explorerVisible = true;
        _explorerRevision++;
        status = 'تمت استعادة النسخة الاحتياطية';
      });
      await saveTabStateSilently();
      showMessage('تمت استعادة ${backup.files.length} ملفًا من النسخة المؤرخة ${backup.createdAt.toLocal()}');
    } catch (e) {
      if (createdRootUri != null) {
        try {
          await safFiles.deleteTree(createdRootUri);
        } catch (cleanupError) {
          showMessage('فشلت الاستعادة والتنظيف التلقائي للمجلد الجزئي: $cleanupError');
          return;
        }
      }
      showMessage('تعذرت استعادة النسخة الاحتياطية: $e');
    }
  }

  Future<void> exportProjectArchive() async {
    if (projectUri == null || projectUri!.isEmpty) {
      showMessage('افتح مجلد مشروع أولاً لتصديره كاملاً');
      return;
    }
    try {
      await saveAllTabs();
      final root = await safFiles.getItem(projectUri!);
      if (root == null || !root.isDir) {
        throw Exception('مجلد المشروع غير متاح');
      }
      final archive = Archive();
      await _addDirectoryToArchive(
        archive, projectUri!, '', <String>{}, ProjectArchiveBudget(),
      );
      if (archive.files.isEmpty) {
        throw Exception('المشروع فارغ ولا يحتوي على ملفات للتصدير');
      }
      final archiveFiles = archive.files.where((entry) => entry.isFile).toList();
      ProjectArchiveValidator.validateArchive(
        entryCount: archive.files.length,
        files: archiveFiles.map((entry) => MapEntry(entry.name, entry.size)),
      );
      ProjectArchiveValidator.validateFilePaths(
        archiveFiles.map((entry) => entry.name),
      );
      final encoded = ZipEncoder().encode(archive);
      if (encoded == null || encoded.isEmpty) {
        throw Exception('تعذر إنشاء ملف ZIP');
      }
      final zipName = '${projectName.isEmpty ? 'bisho_project' : projectName}.zip';
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'تصدير المشروع كاملاً',
        fileName: zipName,
        bytes: Uint8List.fromList(encoded),
      );
      if (saved != null && mounted) {
        setState(() => status = 'تم تصدير المشروع كاملاً');
        showMessage('تم تصدير ${archive.files.length} عنصر إلى ملف ZIP');
      }
    } catch (e) {
      showMessage('تعذر تصدير المشروع: $e');
    }
  }

  Future<void> _writeArchiveEntry(
    String rootUri,
    String relativePath,
    List<int> bytes,
  ) async {
    final normalized = ProjectArchiveValidator.normalizePath(relativePath);
    final segments = normalized.split('/');
    var parentUri = rootUri;
    for (final segment in segments.take(segments.length - 1)) {
      final existing = await safFiles.findChild(parentUri: parentUri, name: segment);
      if (existing != null && !existing.isDir) {
        throw Exception('تعارض بين ملف ومجلد: $segment');
      }
      parentUri = existing?.uri ?? (await safFiles.createFolder(parentUri: parentUri, folderName: segment)).uri;
    }
    final fileName = segments.last;
    final existing = await safFiles.findChild(parentUri: parentUri, name: fileName);
    if (existing != null && existing.isDir) {
      throw Exception('يوجد مجلد باسم الملف: $fileName');
    }
    await safFiles.saveFile(
      parentUri: parentUri,
      fileName: fileName,
      mimeType: SafFileService.mimeTypeForName(fileName),
      bytes: Uint8List.fromList(bytes),
      overwrite: false,
    );
  }

  Future<void> importProjectArchive() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        withData: true,
        allowMultiple: false,
      );
      if (picked == null || picked.files.isEmpty) return;
      final input = picked.files.single;
      final zipBytes = input.bytes;
      if (zipBytes == null || zipBytes.isEmpty) {
        throw Exception('تعذر قراءة محتوى ملف ZIP');
      }
      final decoded = ZipDecoder().decodeBytes(zipBytes, verify: true);
      final archiveFiles = decoded.files.where((entry) => entry.isFile).toList();
      ProjectArchiveValidator.validateArchive(
        entryCount: decoded.files.length,
        files: archiveFiles.map((entry) => MapEntry(entry.name, entry.size)),
      );
      ProjectArchiveValidator.validateFilePaths(
        archiveFiles.map((entry) => entry.name),
      );
      // Validate directory entries too, before creating anything on disk.
      for (final entry in decoded.files.where((item) => !item.isFile)) {
        final directoryName = entry.name.endsWith('/')
            ? entry.name.substring(0, entry.name.length - 1)
            : entry.name;
        if (directoryName.isNotEmpty) {
          ProjectArchiveValidator.normalizePath(directoryName);
        }
      }
      final parent = await safFiles.pickProjectFolder();
      if (parent == null) return;
      var folderName = input.name.replaceAll(RegExp(r'\.zip$', caseSensitive: false), '').trim();
      folderName = folderName.replaceAll(RegExp(r'[^a-zA-Z0-9_ .-]'), '_').trim();
      if (folderName.isEmpty || folderName == '.' || folderName == '..') folderName = 'Imported_Project';
      final existing = await safFiles.findChild(parentUri: parent.uri, name: folderName);
      if (existing != null) throw Exception('يوجد مجلد بالاسم $folderName في المكان المحدد');
      final root = await safFiles.createFolder(parentUri: parent.uri, folderName: folderName);
      var importedCount = 0;
      for (final entry in decoded.files) {
        final name = entry.name.replaceAll('\\', '/');
        if (!entry.isFile) {
          final safeName = ProjectArchiveValidator.normalizePath(name);
          if (safeName.isNotEmpty) {
            final parts = safeName.split('/');
            var current = root.uri;
            for (final part in parts) {
              final found = await safFiles.findChild(parentUri: current, name: part);
              if (found != null && !found.isDir) throw Exception('تعارض في مسار ZIP');
              current = found?.uri ?? (await safFiles.createFolder(parentUri: current, folderName: part)).uri;
            }
          }
          continue;
        }
        final content = entry.content;
        final bytes = content is List<int> ? content : List<int>.from(content as Iterable);
        await _writeArchiveEntry(root.uri, name, bytes);
        importedCount++;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bisho_project_uri', root.uri);
      await prefs.setString('bisho_project_name', folderName);
      await prefs.remove(_savedDirectoryUriKey);
      await prefs.remove(_savedDirectoryNameKey);
      if (!mounted) return;
      setState(() {
        projectUri = root.uri;
        projectName = folderName;
        selectedDirectoryUri = null;
        selectedDirectoryName = '';
        explorerVisible = true;
        _explorerRevision++;
        status = 'تم استيراد المشروع';
      });
      await saveTabStateSilently();
      showMessage('تم استيراد $importedCount ملفًا بنجاح');
    } catch (e) {
      showMessage('تعذر استيراد المشروع المضغوط: $e');
    }
  }

  void changeLanguage(String? language) {
    if (language == null) return;

    setState(() {
      activeTab.language = language;
      activeTab.controller.language = languages[language];

      final parts = activeTab.fileName.split('.');
      final baseName = parts.length > 1
          ? parts.sublist(0, parts.length - 1).join('.')
          : activeTab.fileName;

      activeTab.fileName =
          '$baseName.${extensions[language] ?? 'txt'}';

      activeTab.isSaved = false;
      status = 'تم تغيير اللغة';
    });

    saveTabStateSilently();
  }

  Future<void> searchCode({bool startInReplaceMode = false}) async {
    final findController = TextEditingController();
    final replaceController = TextEditingController();
    var replaceMode = startInReplaceMode;

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('البحث والاستبدال'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: findController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'بحث عن',
                  hintText: 'اكتب النص المطلوب',
                ),
              ),
              if (replaceMode)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: replaceController,
                    decoration: const InputDecoration(
                      labelText: 'استبدال بـ',
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setDialogState(
                    () => replaceMode = !replaceMode,
                  ),
                  icon: Icon(replaceMode ? Icons.search : Icons.find_replace),
                  label: Text(
                    replaceMode ? 'إخفاء الاستبدال' : 'إظهار الاستبدال',
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, {
                    'find': findController.text,
                    'mode': 'project',
                  }),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('البحث في جميع ملفات المشروع'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'find': findController.text,
                'replace': replaceController.text,
                'mode': replaceMode ? 'replace' : 'find',
              }),
              child: Text(replaceMode ? 'استبدال الكل' : 'بحث'),
            ),
          ],
        ),
      ),
    );

    findController.dispose();
    replaceController.dispose();

    if (result == null) return;
    final query = result['find'] ?? '';
    if (query.isEmpty) return;

    if (result['mode'] == 'project') {
      await searchProjectFiles(query);
      return;
    }

    final source = activeTab.controller.text;
    if (result['mode'] == 'replace') {
      final replacement = result['replace'] ?? '';
      final matches = query.allMatches(source).length;
      if (matches == 0) {
        showMessage('لم يتم العثور على النص');
        return;
      }
      activeTab.controller.text = source.replaceAll(query, replacement);
      activeTab.controller.selection = TextSelection.collapsed(
        offset: activeTab.controller.text.length,
      );
      showMessage('تم استبدال $matches تطابق');
      return;
    }

    final currentSelection = activeTab.controller.selection;
    final searchFrom = currentSelection.isValid
        ? currentSelection.extentOffset.clamp(0, source.length).toInt()
        : 0;
    var start = source.indexOf(query, searchFrom);
    if (start == -1 && searchFrom > 0) {
      start = source.indexOf(query);
    }
    if (start == -1) {
      showMessage('لم يتم العثور على النص');
      return;
    }
    activeTab.controller.selection = TextSelection(
      baseOffset: start,
      extentOffset: start + query.length,
    );
    showMessage('تم العثور على النص');
  }

  Future<void> searchProjectFiles(String query) async {
    final rootUri = projectUri;
    if (rootUri == null || rootUri.isEmpty) {
      showMessage('افتح مجلد المشروع أولاً للبحث داخله');
      return;
    }

    final searchableExtensions = <String>{
      'dart', 'py', 'js', 'mjs', 'cjs', 'ts', 'tsx', 'jsx', 'html', 'htm',
      'css', 'scss', 'sass', 'json', 'xml', 'yaml', 'yml', 'md', 'markdown',
      'txt', 'java', 'kt', 'kts', 'swift', 'c', 'h', 'cpp', 'hpp', 'sql',
      'sh', 'bash', 'go', 'rs', 'php', 'toml', 'ini', 'gradle', 'properties',
    };
    final results = <_ProjectSearchResult>[];
    var visitedFiles = 0;
    var skippedFiles = 0;
    const maxFiles = 500;
    const maxFileBytes = 1024 * 1024;
    final needle = query.toLowerCase();

    Future<void> scanDirectory(
      String directoryUri,
      String relativeDirectory,
    ) async {
      if (visitedFiles >= maxFiles || results.length >= 200) return;
      List<SafDocumentFile> items;
      try {
        items = await safFiles.listDirectory(directoryUri);
      } catch (_) {
        skippedFiles++;
        return;
      }

      for (final item in items) {
        if (visitedFiles >= maxFiles || results.length >= 200) break;
        final relativePath = relativeDirectory.isEmpty
            ? item.name
            : '$relativeDirectory/${item.name}';
        if (item.isDir) {
          await scanDirectory(item.uri, relativePath);
          continue;
        }

        final dot = item.name.lastIndexOf('.');
        final extension = dot < 0
            ? ''
            : item.name.substring(dot + 1).toLowerCase();
        if (!searchableExtensions.contains(extension)) continue;

        visitedFiles++;
        try {
          final bytes = await safFiles.readFile(item.uri);
          if (bytes.length > maxFileBytes) {
            skippedFiles++;
            continue;
          }
          final content = utf8.decode(bytes, allowMalformed: true);
          final lines = content.split('\n');
          final matchingLines = <int>[];
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].toLowerCase().contains(needle)) {
              matchingLines.add(i + 1);
              if (matchingLines.length >= 20) break;
            }
          }
          if (matchingLines.isNotEmpty) {
            results.add(_ProjectSearchResult(
              file: item,
              parentUri: directoryUri,
              relativePath: relativePath,
              matchingLines: matchingLines,
            ));
          }
        } catch (_) {
          skippedFiles++;
        }
      }
    }

    showMessage('جارٍ البحث داخل ملفات المشروع...');
    await scanDirectory(rootUri, '');
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('نتائج البحث: ${results.length}'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(dialogContext).size.height * 0.55,
          child: results.isEmpty
              ? const Center(child: Text('لم يتم العثور على تطابقات'))
              : ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = results[index];
                    final lineSummary =
                        result.matchingLines.take(5).join(', ');
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(
                        result.file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${result.relativePath}\n'
                        'الأسطر: $lineSummary'
                        '${result.matchingLines.length > 5 ? ' ...' : ''}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        await openProjectFile(result.file, result.parentUri);
                        final opened = tabs.indexWhere(
                          (tab) => tab.fileUri == result.file.uri,
                        );
                        if (opened >= 0) {
                          selectTab(opened);
                          final text = tabs[opened].controller.text;
                          final offset = text.toLowerCase().indexOf(needle);
                          if (offset >= 0) {
                            tabs[opened].controller.selection = TextSelection(
                              baseOffset: offset,
                              extentOffset: offset + query.length,
                            );
                          }
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    final limitNote = visitedFiles >= maxFiles || results.length >= 200
        ? ' (توقف البحث عند بلوغ الحد الوقائي)'
        : '';
    showMessage(
      'اكتمل البحث: فُحص $visitedFiles ملفًا، وتُخطّي $skippedFiles$limitNote',
    );
  }

  void _applyHistoryText(EditorTab tab, String value) {
    _historyApplying.add(tab.id);
    tab.controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _historyApplying.remove(tab.id);
    setState(() {
      tab.isSaved = false;
      status = 'تعديل في سجل التراجع';
    });
  }

  void undoCodeEdit() {
    final tab = activeTab;
    final history = _undoHistory.putIfAbsent(
      tab.id,
      () => <String>[tab.controller.text],
    );
    if (history.length <= 1) {
      showMessage('لا توجد تعديلات للتراجع عنها');
      return;
    }
    final current = history.removeLast();
    _redoHistory.putIfAbsent(tab.id, () => <String>[]).add(current);
    _applyHistoryText(tab, history.last);
  }

  void redoCodeEdit() {
    final tab = activeTab;
    final redo = _redoHistory.putIfAbsent(tab.id, () => <String>[]);
    if (redo.isEmpty) {
      showMessage('لا توجد تعديلات لإعادتها');
      return;
    }
    final next = redo.removeLast();
    _undoHistory.putIfAbsent(tab.id, () => <String>[]).add(next);
    _applyHistoryText(tab, next);
  }

  void _applyLineEdit(EditorLineEditResult? result, String successMessage) {
    if (result == null) {
      showMessage('لا يمكن تنفيذ العملية في هذا الموضع');
      return;
    }
    final tab = activeTab;
    if (result.text == tab.controller.text) return;
    tab.controller.value = TextEditingValue(
      text: result.text,
      selection: result.selection,
    );
    setState(() {
      tab.isSaved = false;
      status = successMessage;
    });
    _scheduleTabStateSave();
  }

  void duplicateSelectedLines() {
    final tab = activeTab;
    _applyLineEdit(
      EditorLineActions.duplicateSelectedLines(
        text: tab.controller.text,
        selection: tab.controller.selection,
      ),
      'تم تكرار الأسطر المحددة',
    );
  }

  void moveCurrentLineUp() {
    final tab = activeTab;
    _applyLineEdit(
      EditorLineActions.moveCurrentLine(
        text: tab.controller.text,
        selection: tab.controller.selection,
        down: false,
      ),
      'تم نقل السطر للأعلى',
    );
  }

  void moveCurrentLineDown() {
    final tab = activeTab;
    _applyLineEdit(
      EditorLineActions.moveCurrentLine(
        text: tab.controller.text,
        selection: tab.controller.selection,
        down: true,
      ),
      'تم نقل السطر للأسفل',
    );
  }

  void toggleSelectedLineComments() {
    final tab = activeTab;
    _applyLineEdit(
      EditorLineActions.toggleLineComments(
        text: tab.controller.text,
        selection: tab.controller.selection,
        language: tab.language,
      ),
      'تم تبديل التعليق على الأسطر',
    );
  }

  void jumpToMatchingBracket() {
    final tab = activeTab;
    final selection = tab.controller.selection;
    final cursor = selection.isValid
        ? selection.extentOffset
        : tab.controller.text.length;
    final match = EditorBracketMatcher.findMatchingOffset(
      source: tab.controller.text,
      cursorOffset: cursor,
      language: tab.language,
    );
    if (match == null) {
      setState(() => status = 'لم يتم العثور على قوس مطابق');
      return;
    }
    tab.controller.selection = TextSelection.collapsed(offset: match);
    setState(() => status = 'تم الانتقال إلى القوس المطابق');
    _scheduleTabStateSave();
  }

  List<String> _getCurrentDiagnostics(EditorTab tab) {
    final source = tab.controller.text;
    final diagnostics = <String>[];
    try {
      switch (tab.language) {
        case 'JSON':
          jsonDecode(source);
          break;
        case 'XML':
          XmlDocument.parse(source);
          break;
        case 'YAML':
          loadYaml(source);
          break;
      }
    } catch (error) {
      final message = error.toString().replaceFirst(RegExp(r'^.*?:\s*'), '');
      diagnostics.add('${tab.language}: $message');
    }

    // Structural checks complement the real JSON/XML/YAML parsers. They are
    // deliberately labelled as lightweight editor diagnostics, not compiler
    // errors or a substitute for a language analyzer.
    diagnostics.addAll(
      EditorSyntaxDiagnostics.analyze(source, tab.language)
          .map((diagnostic) => '${tab.language}: $diagnostic'),
    );
    return diagnostics;
  }

  void _showTerminalPanel() {
    setState(() {
      _bottomPanelVisible = true;
      _bottomPanelTab = 2;
      _editorFullScreen = false;
    });
    _saveEditorPreferences();
  }

  Widget buildBottomPanel(EditorTab tab) {
    final diagnostics = _getCurrentDiagnostics(tab);
    final lines = tab.controller.text.isEmpty
        ? 1
        : '\n'.allMatches(tab.controller.text).length + 1;
    final characters = tab.controller.text.length;
    final isProblems = _bottomPanelTab == 0;
    final isFileInfo = _bottomPanelTab == 1;

    return Container(
      height: _bottomPanelHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF101827),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) {
              final screenHeight = MediaQuery.of(context).size.height;
              final nextHeight = _bottomPanelHeight - details.delta.dy;
              final maxHeight = screenHeight * 0.55;
              setState(() {
                _bottomPanelHeight = nextHeight.clamp(110.0, maxHeight).toDouble();
              });
              _saveEditorPreferences();
            },
            child: SizedBox(
              height: 12,
              child: Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _bottomPanelTab = 0),
                  icon: Icon(
                    Icons.error_outline,
                    size: 16,
                    color: _bottomPanelTab == 0
                        ? const Color(0xFF38BDF8)
                        : Colors.white54,
                  ),
                  label: Text(
                    'المشكلات${diagnostics.isEmpty ? '' : ' (${diagnostics.length})'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _bottomPanelTab == 0
                          ? const Color(0xFF38BDF8)
                          : Colors.white70,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _bottomPanelTab = 1),
                  icon: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: _bottomPanelTab == 1
                        ? const Color(0xFF38BDF8)
                        : Colors.white54,
                  ),
                  label: Text(
                    'معلومات الملف',
                    style: TextStyle(
                      fontSize: 11,
                      color: _bottomPanelTab == 1
                          ? const Color(0xFF38BDF8)
                          : Colors.white70,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showTerminalPanel,
                  icon: Icon(
                    Icons.terminal,
                    size: 16,
                    color: _bottomPanelTab == 2
                        ? const Color(0xFF38BDF8)
                        : Colors.white54,
                  ),
                  label: Text(
                    'الطرفية',
                    style: TextStyle(
                      fontSize: 11,
                      color: _bottomPanelTab == 2
                          ? const Color(0xFF38BDF8)
                          : Colors.white70,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'إغلاق اللوحة',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() => _bottomPanelVisible = false);
                    _saveEditorPreferences();
                  },
                  icon: const Icon(Icons.close, size: 17),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF263449)),
          Expanded(
            child: isProblems
                ? diagnostics.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد أخطاء تحقق معروفة لهذا النوع من الملفات',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      )
                    : ListView.builder(
                        itemCount: diagnostics.length,
                        itemBuilder: (context, index) => ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orangeAccent,
                            size: 18,
                          ),
                          title: Text(
                            diagnostics[index],
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      )
                : isFileInfo
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Wrap(
                            spacing: 18,
                            runSpacing: 8,
                            children: [
                              _panelInfo('الملف', tab.fileName),
                              _panelInfo('اللغة', tab.language),
                              _panelInfo('الأسطر', '$lines'),
                              _panelInfo('الأحرف', '$characters'),
                              _panelInfo('الحالة', tab.isSaved ? 'محفوظ' : 'معدّل'),
                            ],
                          ),
                        ),
                      )
                    : BishoTerminalPanel(
                        files: safFiles,
                        projectUri: projectUri,
                        projectName: projectName,
                        onOpenFile: (file, parentUri) => openProjectFile(
                          file,
                          parentUri,
                          closeOverlay: false,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _panelInfo(String label, String value) {
    return Text(
      '$label: $value',
      style: const TextStyle(fontSize: 11, color: Colors.white70),
    );
  }

  void changeEditorFontSize(double delta) {
    setState(() {
      _editorFontSize = (_editorFontSize + delta).clamp(10.0, 24.0).toDouble();
      status = 'حجم الخط: ${_editorFontSize.toStringAsFixed(0)}';
    });
    _saveEditorPreferences();
  }

  Future<void> showCodeCompletions() async {
    final tab = activeTab;
    final controller = tab.controller;
    final source = controller.text;
    final selection = controller.selection;
    final cursor = selection.isValid
        ? selection.extentOffset.clamp(0, source.length).toInt()
        : source.length;
    final beforeCursor = source.substring(0, cursor);
    final match = RegExp(r'[A-Za-z_][A-Za-z0-9_]*$').firstMatch(beforeCursor);
    final prefix = match?.group(0) ?? '';

    final Map<String, List<String>> completions = {
      'Dart': [
        'void main() {\n  \n}',
        'print()',
        'final ',
        'const ',
        'class ',
        'Future<void> ',
        'async',
        'if () {\n  \n}',
        'for (var i = 0; i < ; i++) {\n  \n}',
      ],
      'JavaScript': [
        'console.log()',
        'const ',
        'let ',
        'function ',
        'async function ',
        'if () {\n  \n}',
        'for (let i = 0; i < ; i++) {\n  \n}',
        'try {\n  \n} catch (error) {\n  console.error(error);\n}',
      ],
      'TypeScript': [
        'console.log()',
        'const ',
        'let ',
        'interface ',
        'type ',
        'function ',
        'async function ',
        'Promise<void>',
      ],
      'Python': [
        'print()',
        'def ',
        'class ',
        'if __name__ == "__main__":\n    ',
        'for item in :\n    ',
        'try:\n    \nexcept Exception as error:\n    print(error)',
        'import ',
      ],
      'HTML': [
        '<!DOCTYPE html>\n<html lang="ar">\n<head>\n  <meta charset="UTF-8">\n  <meta name="viewport" content="width=device-width, initial-scale=1.0">\n  <title></title>\n</head>\n<body>\n  \n</body>\n</html>',
        '<div></div>',
        '<p></p>',
        '<script>\n\n</script>',
        '<style>\n\n</style>',
      ],
      'CSS': [
        'display: flex;',
        'display: grid;',
        'margin: ;',
        'padding: ;',
        'color: ;',
        '@media (max-width: 600px) {\n  \n}',
      ],
      'SQL': [
        'SELECT * FROM ;',
        'SELECT  FROM  WHERE ;',
        'INSERT INTO  () VALUES ();',
        'UPDATE  SET  =  WHERE ;',
        'CREATE TABLE  (\n  id INTEGER PRIMARY KEY\n);',
      ],
      'Markdown': ['# ', '## ', '- ', '1. ', '```\n\n```', '> '],
      'YAML': ['name: ', 'version: ', 'dependencies:\n  ', 'scripts:\n  '],
      'JSON': ['{\n  "": ""\n}', '[\n  \n]'],
      'XML': ['<?xml version="1.0" encoding="UTF-8"?>\n<root>\n</root>', '<root></root>'],
    };

    final candidates = completions[tab.language] ??
        <String>['// TODO: ', 'if () {\n  \n}', 'class ', 'function '];
    final options = EditorCompletionEngine.rank(
      language: tab.language,
      prefix: prefix,
      snippets: [
        ...candidates,
        ...EditorCompletionEngine.identifiersIn(
          source,
          language: tab.language,
        ),
      ],
      maximumResults: 50,
    );

    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('إكمال تلقائي — ${tab.language}'),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: options.isEmpty
              ? const Center(child: Text('لا توجد اقتراحات مطابقة'))
              : ListView.separated(
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.code, size: 18),
                    title: Text(
                      options[index].replaceAll('\n', ' ↵ '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                    ),
                    onTap: () => Navigator.pop(dialogContext, options[index]),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );

    if (chosen == null || !mounted) return;
    final current = controller.text;
    final currentCursor = controller.selection.isValid
        ? controller.selection.extentOffset.clamp(0, current.length).toInt()
        : current.length;
    final currentBefore = current.substring(0, currentCursor);
    final currentMatch = RegExp(r'[A-Za-z_][A-Za-z0-9_]*$').firstMatch(currentBefore);
    final start = currentMatch?.start ?? currentCursor;
    final updated = current.replaceRange(start, currentCursor, chosen);
    controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + chosen.length),
    );
    setState(() {
      activeTab.isSaved = false;
      status = 'تم إدراج الإكمال';
    });
  }

  Future<void> copyCode() async {
    final controller = activeTab.controller;
    final selection = controller.selection;
    final text = selection.isValid && !selection.isCollapsed
        ? controller.text.substring(selection.start, selection.end)
        : controller.text;
    await Clipboard.setData(ClipboardData(text: text));
    showMessage(selection.isValid && !selection.isCollapsed
        ? 'تم نسخ النص المحدد'
        : 'تم نسخ الكود كاملاً');
  }

  void openFlutterPreview() {
    Navigator.push(
      context,
      _DarkPageRoute(
        builder: (_) => FlutterPreviewScreen(
          projectName: projectName,
          projectUri: projectUri,
          safFiles: safFiles,
          onPickProject: openProjectFolder,
          projectUriProvider: () => projectUri,
          projectNameProvider: () => projectName,
        ),
      ),
    );
  }

  Future<void> openLanguagePreview() async {
    final tab = activeTab;
    final engine = LanguageEngineManager.engineForFile(tab.fileName);

    switch (engine) {
      case LanguageEngine.webProject:
        // إذا فتح المستخدم ملف HTML منفرداً، نطلب منه اختيار مجلد المشروع
        // مرة واحدة ثم نتابع المعاينة تلقائياً بدلاً من إيقافه برسالة فقط.
        if (projectUri == null || projectUri!.isEmpty) {
          showMessage('اختر مجلد المشروع الذي يحتوي ملف HTML وموارده');
          await openProjectFolder();
          if (!mounted || projectUri == null || projectUri!.isEmpty) return;
        }

        final htmlUri = tab.fileUri;
        if (htmlUri == null || htmlUri.isEmpty) {
          showMessage(
            'هذا الملف غير مرتبط بموقع داخل المشروع. افتحه من مستكشف المشروع أو احفظه داخله أولاً.',
          );
          return;
        }

        // تحقق من أن ملف HTML موجود فعلاً داخل جذر المشروع المختار.
        try {
          final rootItem = await safFiles.getItem(projectUri!);
          if (rootItem == null || !rootItem.isDir) {
            showMessage('تعذر الوصول إلى مجلد المشروع؛ اختره مرة أخرى');
            return;
          }
          final projectTree = await collectSubtree(rootItem);
          final fileBelongsToProject = projectTree.any(
            (entry) => entry.uri == htmlUri && !entry.isDir,
          );
          if (!fileBelongsToProject) {
            showMessage(
              'ملف HTML ليس داخل مجلد المشروع المختار. اختر المجلد الأب الصحيح.',
            );
            return;
          }
        } catch (error) {
          showMessage('تعذر فحص ملفات المشروع: $error');
          return;
        }

        if (!mounted) return;
        await Navigator.push(
          context,
          _DarkPageRoute(
            builder: (_) => HtmlPreviewScreen(
              htmlCode: tab.controller.text,
              projectUri: projectUri,
              htmlFileUri: htmlUri,
            ),
          ),
        );
        return;

      case LanguageEngine.webCode:
        final mode =
            LanguageEngineManager.webModeForFile(tab.fileName);

        if (mode == null) {
          showMessage('نوع ملف الويب غير مدعوم');
          return;
        }

        await Navigator.push(
          context,
          _DarkPageRoute(
            builder: (_) => WebCodeRunnerScreen(
              code: tab.controller.text,
              fileName: tab.fileName,
              mode: mode,
            ),
          ),
        );
        return;

      case LanguageEngine.jsonViewer:
        await Navigator.push(
          context,
          _DarkPageRoute(
            builder: (_) => WebCodeRunnerScreen(
              code: tab.controller.text,
              fileName: tab.fileName,
              mode: 'json',
            ),
          ),
        );
        return;

      case LanguageEngine.unsupported:
        _showExecutionCapabilityDialog(tab.fileName);
        return;
    }
  }

  void _showExecutionCapabilityDialog(String fileName) {
    final capability = LanguageEngineManager.capabilitiesForFile(fileName);
    final language = capability?.language ?? 'هذه اللغة';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8)),
          const SizedBox(width: 8),
          const Expanded(child: Text('تشغيل هذا النوع من الملفات')),
        ]),
        content: Text(
          'يدعم Bisho IDE تحرير $language وتلوين الكود، لكن لا يحتوي حالياً '
          'على مترجم أو مفسّر محلي لهذا النوع.\n\n'
          'يمكنك متابعة التحرير والحفظ واستخدام أدوات الفحص المتاحة. '
          'لن يبدأ التطبيق عملية تشغيل وهمية أو يعرض نتيجة غير حقيقية.',
          style: const TextStyle(height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('حسناً'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _openDiagnosticsPanel();
            },
            icon: const Icon(Icons.rule_rounded),
            label: const Text('فحص الكود'),
          ),
        ],
      ),
    );
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget buildExplorerNode(String directoryUri, int depth) {
    return FutureBuilder<List<SafDocumentFile>>(
      key: ValueKey('$_explorerRevision-$directoryUri'),
      future: safFiles.listDirectory(directoryUri),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const ListTile(
            dense: true,
            title: Text('تعذر قراءة المجلد'),
          );
        }

        final items =
            List<SafDocumentFile>.from(snapshot.data ?? []);

        final filter = _explorerFilter.trim().toLowerCase();
        if (filter.isNotEmpty) {
          items.removeWhere((item) => !item.name.toLowerCase().contains(filter));
        }

        items.sort((a, b) {
          if (a.isDir && !b.isDir) return -1;
          if (!a.isDir && b.isDir) return 1;

          return a.name.toLowerCase().compareTo(
                b.name.toLowerCase(),
              );
        });

        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              filter.isEmpty ? 'المجلد فارغ' : 'لا توجد عناصر تطابق البحث',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((entity) {
            if (entity.isDir) {
              final isSelectedDirectory =
                  selectedDirectoryUri == entity.uri;

              return Padding(
                padding: EdgeInsets.only(right: depth * 5.0),
                child: ExpansionTile(
                  key: PageStorageKey<String>(entity.uri),
                  dense: true,
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                  ),
                  leading: Icon(
                    isSelectedDirectory
                        ? Icons.folder_special
                        : Icons.folder,
                    color: isSelectedDirectory
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFFFBBF24),
                    size: 20,
                  ),
                  title: Text(
                    entity.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelectedDirectory
                          ? const Color(0xFF38BDF8)
                          : null,
                      fontWeight: isSelectedDirectory
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (value) {
                      if (value == 'select') {
                        selectCreationDirectory(
                          entity.uri,
                          entity.name,
                        );
                      }

                      if (value == 'rename') {
                        renameEntity(entity);
                      }

                      if (value == 'delete') {
                        deleteEntity(entity);
                      }
                      if (value == 'copy') {
                        copyOrMoveEntity(entity, move: false);
                      }
                      if (value == 'move') {
                        copyOrMoveEntity(entity, move: true);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'select',
                        child: Row(
                          children: [
                            Icon(
                              Icons.drive_file_move,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text('تعيين كمجلد عمل'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'copy', child: Text('نسخ إلى مجلد…')),
                      const PopupMenuItem(value: 'move', child: Text('نقل إلى مجلد…')),
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('إعادة تسمية'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('حذف'),
                      ),
                    ],
                  ),
                  children: [
                    buildExplorerNode(entity.uri, depth + 1),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(right: depth * 5.0),
              child: ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                leading: LanguageBrandBadge(
                  language: LanguageIdentity.fromFileName(entity.name).name,
                  size: 25,
                ),
                title: Text(
                  entity.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => openProjectFile(entity, directoryUri),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (value) {
                    if (value == 'rename') {
                      renameEntity(entity);
                    }

                    if (value == 'delete') {
                      deleteEntity(entity);
                    }
                    if (value == 'copy') {
                      copyOrMoveEntity(entity, move: false);
                    }
                    if (value == 'move') {
                      copyOrMoveEntity(entity, move: true);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'copy', child: Text('نسخ إلى مجلد…')),
                    PopupMenuItem(value: 'move', child: Text('نقل إلى مجلد…')),
                    PopupMenuItem(
                      value: 'rename',
                      child: Text('إعادة تسمية'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('حذف'),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget buildExplorer() {
    return Container(
      width: 300,
      color: const Color(0xFF111827),
      child: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'المستكشف',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: createProjectFile,
                  icon: const Icon(Icons.note_add, size: 19),
                  tooltip: 'ملف جديد',
                ),
                IconButton(
                  onPressed: createProjectFolder,
                  icon: const Icon(Icons.create_new_folder, size: 19),
                  tooltip: 'مجلد جديد',
                ),
                IconButton(
                  onPressed: refreshExplorer,
                  icon: const Icon(Icons.refresh, size: 19),
                  tooltip: 'تحديث المستكشف',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (projectUri != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 5),
              child: TextField(
                controller: _explorerFilterController,
                onChanged: (value) => setState(() => _explorerFilter = value),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'تصفية الملفات والمجلدات',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _explorerFilter.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'مسح التصفية',
                          icon: const Icon(Icons.close, size: 17),
                          onPressed: () {
                            _explorerFilterController.clear();
                            setState(() => _explorerFilter = '');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          if (projectUri == null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.folder_open,
                        size: 38,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'لم يتم فتح مشروع',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: openProjectFolder,
                        child: const Text('فتح مجلد'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.folder,
                      color: Color(0xFFFBBF24),
                    ),
                    title: Text(
                      projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    trailing: IconButton(
                      onPressed: openProjectFolder,
                      icon: const Icon(Icons.folder_open, size: 18),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: selectedDirectoryUri != null
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF334155),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedDirectoryUri != null
                              ? Icons.folder_special
                              : Icons.home_work,
                          size: 15,
                          color: const Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'العمل: $creationDirectoryName',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        if (selectedDirectoryUri != null)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                              minWidth: 26,
                              minHeight: 26,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: 'العودة إلى جذر المشروع',
                            onPressed: resetCreationDirectory,
                            icon: const Icon(
                              Icons.home,
                              size: 17,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: buildExplorerNode(projectUri!, 0),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget buildTabBar() {
    return Container(
      height: 46,
      color: const Color(0xFF111827),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final selected = index == activeIndex;

                return InkWell(
                  onTap: () => selectTab(index),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 100,
                      maxWidth: 180,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF0B1020)
                          : Colors.transparent,
                      border: Border(
                        top: BorderSide(
                          color: selected
                              ? const Color(0xFF38BDF8)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        LanguageBrandBadge(
                          language: LanguageIdentity.fromFileName(tab.fileName).name,
                          size: 20,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            tab.fileName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        if (!tab.isSaved)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.circle,
                              size: 7,
                              color: Colors.amber,
                            ),
                          ),
                        GestureDetector(
                          onTap: () => closeTab(index),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            onPressed: createNewTab,
            icon: const Icon(
              Icons.add,
              color: Color(0xFF38BDF8),
            ),
          ),
        ],
      ),
    );
  }

  void _openEditorFullScreen() {
    if (_editorFullScreen || tabs.isEmpty) return;

    // Remove the embedded CodeField first. A CodeController should not be
    // attached to two CodeFields at the same time while the route animates.
    setState(() => _editorFullScreen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context)
          .push(
            _DarkPageRoute<void>(
              builder: (_) => EditorFullScreenScreen(
                tab: activeTab,
                fontSize: _editorFontSize,
                onSave: saveCurrentToDisk,
                onFontSizeChange: changeEditorFontSize,
                onShowCompletions: showCodeCompletions,
                onSearch: (replaceMode) =>
                    searchCode(startInReplaceMode: replaceMode),
                onPreview: openLanguagePreview,
                onFlutterPreview: openFlutterPreview,
              ),
            ),
          )
          .whenComplete(() {
            if (mounted) setState(() => _editorFullScreen = false);
          });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _explorerFilterController.dispose();
    _isDisposing = true;
    _tabStateSaveTimer?.cancel();
    // Capture the final editor state before releasing the controllers.
    saveTabStateSilently();
    for (final tab in tabs) {
      tab.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 14),
              Text(
                isRestoring ? 'جاري استعادة مساحة العمل...' : 'جاري تجهيز المحرر...',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    if (_editorFullScreen) {
      // The actual editor is displayed by EditorFullScreenScreen on its own
      // route. Keep this route lightweight while it is underneath.
      return const Scaffold(
        backgroundColor: Color(0xFF080D19),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tab = activeTab;
    final selection = tab.controller.selection;
    final cursorOffset = selection.isValid
        ? selection.extentOffset.clamp(0, tab.controller.text.length).toInt()
        : tab.controller.text.length;
    final cursorPosition = _cursorLineColumn(tab.controller.text, cursorOffset);
    final cursorLine = cursorPosition.$1;
    final cursorColumn = cursorPosition.$2;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmApplicationExit();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
        drawer: _editorFullScreen || !explorerVisible
            ? null
            : Drawer(
                width: 320,
                backgroundColor: const Color(0xFF111827),
                child: Theme(
                  data: BishoTheme.darkTheme,
                  child: SafeArea(child: buildExplorer()),
                ),
              ),
        appBar: _editorFullScreen ? null : AppBar(
          title: const Row(
            children: [
              Icon(
                Icons.code,
                color: Color(0xFF38BDF8),
              ),
              SizedBox(width: 8),
              Text(
                'Bisho IDE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _openEditorFullScreen,
              icon: const Icon(Icons.code),
              tooltip: 'فتح المحرر في شاشة كاملة',
            ),
            IconButton(
              onPressed: saveCurrentToDisk,
              icon: const Icon(Icons.save),
              tooltip: 'حفظ الملف',
            ),
            IconButton(
              onPressed: _showTerminalPanel,
              icon: const Icon(Icons.terminal, color: Color(0xFF38BDF8)),
              tooltip: 'فتح الطرفية',
            ),
            IconButton(
              onPressed: BishoThemeController.toggle,
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
              ),
              tooltip: 'تبديل الثيم (فاتح/داكن)',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'new') createNewTab();
                if (value == 'new_project') createNewProject();
                if (value == 'open') openFile();
                if (value == 'folder') openProjectFolder();
                if (value == 'export') exportFile();
                if (value == 'export_project') exportProjectArchive();
                if (value == 'import_zip') importProjectArchive();
                if (value == 'search') searchCode();
                if (value == 'copy') copyCode();
                if (value == 'saveall') saveAllTabs();
                if (value == 'terminal') _showTerminalPanel();
                if (value == 'complete') showCodeCompletions();
                if (value == 'exit') _confirmApplicationExit();
              },
              itemBuilder: (context) => [
                _bishoMenuItem('new', Icons.note_add_rounded, 'ملف جديد'),
                _bishoMenuItem('new_project', Icons.create_new_folder_rounded, 'إنشاء مشروع جديد'),
                _bishoMenuItem('open', Icons.file_open_rounded, 'فتح ملف'),
                _bishoMenuItem('folder', Icons.folder_open_rounded, 'فتح مجلد مشروع'),
                const PopupMenuDivider(),
                _bishoMenuItem('export', Icons.download_rounded, 'تصدير الملف'),
                _bishoMenuItem('export_project', Icons.archive_rounded, 'تصدير المشروع ZIP كاملاً'),
                _bishoMenuItem('import_zip', Icons.unarchive_rounded, 'استيراد مشروع ZIP'),
                const PopupMenuDivider(),
                _bishoMenuItem('search', Icons.search_rounded, 'بحث'),
                _bishoMenuItem('copy', Icons.copy_rounded, 'نسخ الكود'),
                _bishoMenuItem('complete', Icons.auto_awesome_rounded, 'الإكمال التلقائي'),
                _bishoMenuItem('saveall', Icons.save_rounded, 'حفظ جميع الملفات'),
                _bishoMenuItem('terminal', Icons.terminal_rounded, 'فتح الطرفية'),
                const PopupMenuDivider(),
                _bishoMenuItem('exit', Icons.exit_to_app_rounded, 'الخروج من التطبيق', color: Colors.orangeAccent),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (_editorFullScreen)
              Container(
                height: 48,
                color: const Color(0xFF151C30),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _editorFullScreen = false),
                      icon: const Icon(Icons.fullscreen_exit),
                      tooltip: 'العودة إلى واجهة IDE',
                    ),
                    Expanded(
                      child: Text(
                        tab.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: saveCurrentToDisk,
                      icon: const Icon(Icons.save),
                      tooltip: 'حفظ الملف',
                    ),
                  ],
                ),
              ),
            if (!_editorFullScreen) ...[
            Theme(data: BishoTheme.darkTheme, child: buildTabBar()),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined, size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tab.fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  DropdownButton<String>(
                    borderRadius: BorderRadius.circular(12),
                    isDense: true,
                    value: tab.language,
                    dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    underline: const SizedBox(),
                    items: languages.keys.map((language) {
                      return DropdownMenuItem<String>(
                        value: language,
                        child: Text(language),
                      );
                    }).toList(),
                    onChanged: changeLanguage,
                  ),
                ],
              ),
            ),

            Expanded(
              child: Theme(
                data: BishoTheme.darkTheme,
                child: _buildToolsDashboard(tab),
              ),
            ),
            if (!_editorFullScreen && _bottomPanelVisible)
              Theme(data: BishoTheme.darkTheme, child: buildBottomPanel(tab)),
            if (!_editorFullScreen)
              Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                border: Border(
                  top: BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    color: tab.isSaved ? Colors.green : Colors.amber,
                    size: 9,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  Text(
                    'Ln $cursorLine, Col $cursorColumn',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    tab.language,
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    tab.isSaved ? 'محفوظ' : 'غير محفوظ',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildToolsDashboard(EditorTab tab) {
    const cyan = Color(0xFF08B9F4);
    const blue = Color(0xFF247BFF);
    const violet = Color(0xFF8B42F5);
    const green = Color(0xFF19D889);
    const red = Color(0xFFFF456A);
    const amber = Color(0xFFFFC247);

    final primary = <_DashboardAction>[
      _DashboardAction(Icons.download_rounded, 'تصدير ملف', exportFile, cyan),
      _DashboardAction(Icons.archive_rounded, 'تصدير ZIP', exportProjectArchive, cyan),
      _DashboardAction(Icons.unarchive_rounded, 'استيراد ZIP', importProjectArchive, green),
      _DashboardAction(Icons.backup_rounded, 'نسخ احتياطي', exportProjectBackup, green),
      _DashboardAction(Icons.settings_backup_restore_rounded, 'استعادة نسخة', restoreProjectBackup, green),
      _DashboardAction(Icons.history_rounded, 'سجل النسخ', manageProjectBackups, green),
      _DashboardAction(Icons.save_rounded, 'حفظ', saveCurrentToDisk, cyan),
      _DashboardAction(Icons.create_new_folder_rounded, 'مشروع جديد', createNewProject, cyan),
      _DashboardAction(Icons.folder_rounded, 'مشروع', openProjectFolder, cyan),
      _DashboardAction(Icons.drive_folder_upload_rounded, 'استيراد مشروع', importExistingProject, green),
      _DashboardAction(Icons.folder_open_rounded, 'فتح', openFile, cyan),
      _DashboardAction(Icons.add_rounded, 'جديد', createNewTab, cyan),
    ];
    final tools = <_DashboardAction>[
      _DashboardAction(Icons.search_rounded, 'بحث', searchCode, cyan),
      _DashboardAction(Icons.find_replace_rounded, 'استبدال', () => searchCode(startInReplaceMode: true), violet),
      _DashboardAction(Icons.undo_rounded, 'تراجع', undoCodeEdit, red),
      _DashboardAction(Icons.redo_rounded, 'إعادة', redoCodeEdit, green),
    ];
    final extras = <_DashboardAction>[
      _DashboardAction(Icons.palette_rounded, 'تبديل الثيم', _showDashboardThemeInfo, green),
      _DashboardAction(Icons.rocket_launch_rounded, 'أدوات سريعة', showCodeCompletions, violet),
      _DashboardAction(Icons.analytics_rounded, 'تحليل الكود', _openDiagnosticsPanel, cyan),
      _DashboardAction(Icons.health_and_safety_rounded, 'فحص المشروع', _openProjectInsightsPanel, green),
      _DashboardAction(Icons.extension_rounded, 'إضافات', _showPluginsHub, blue),
    ];
    final allTools = <_DashboardAction>[
      ...tools,
      _DashboardAction(Icons.copy_all_rounded, 'تكرار الأسطر', duplicateSelectedLines, cyan),
      _DashboardAction(Icons.arrow_upward_rounded, 'نقل السطر لأعلى', moveCurrentLineUp, cyan),
      _DashboardAction(Icons.arrow_downward_rounded, 'نقل السطر لأسفل', moveCurrentLineDown, cyan),
      _DashboardAction(Icons.comment_rounded, 'تعليق / إلغاء', toggleSelectedLineComments, green),
      _DashboardAction(Icons.compare_arrows_rounded, 'القوس المطابق', jumpToMatchingBracket, cyan),
      _DashboardAction(Icons.difference_rounded, 'مقارنة النص', _openTextDiffDialog, violet),
      _DashboardAction(Icons.copy_rounded, 'نسخ', copyCode, cyan),
      _DashboardAction(Icons.text_increase_rounded, 'تكبير الخط', () => changeEditorFontSize(1), cyan),
      _DashboardAction(Icons.text_decrease_rounded, 'تصغير الخط', () => changeEditorFontSize(-1), cyan),
      _DashboardAction(Icons.vertical_align_bottom_rounded, 'لوحة المشكلات', _openDiagnosticsPanel, amber),
      _DashboardAction(Icons.save_rounded, 'حفظ جميع الملفات', saveAllTabs, green),
      _DashboardAction(Icons.settings_rounded, 'إعدادات مساحة العمل', _showWorkspaceSettings, green),
      _DashboardAction(Icons.extension_rounded, 'اللغات المدعومة', _showLanguageCapabilities, cyan),
      _DashboardAction(Icons.info_outline_rounded, 'معلومات المحرر', _showEditorInfoDialog, cyan),
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF071329), Color(0xFF050B1B), Color(0xFF080D24)]),
      ),
      child: Stack(children: [
        Positioned(left: -100, bottom: 10, child: Container(width: 260, height: 170,
          decoration: BoxDecoration(shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: cyan.withValues(alpha: .20), blurRadius: 75, spreadRadius: 20)]))),
        Positioned(right: -100, bottom: 0, child: Container(width: 260, height: 170,
          decoration: BoxDecoration(shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: violet.withValues(alpha: .20), blurRadius: 75, spreadRadius: 20)]))),
        Positioned(left: 0, right: 0, bottom: 0, height: 150,
          child: IgnorePointer(child: CustomPaint(painter: _DashboardWavePainter()))),
        ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 22),
          children: [
            _dashboardFileStrip(tab),
            const SizedBox(height: 12),
            _dashboardGlowPanel(
              child: SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  itemCount: primary.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => SizedBox(
                    width: 82,
                    child: _dashboardToolCard(primary[index]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              itemCount: tools.length + 1,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: .90),
              itemBuilder: (context, index) => index < tools.length
                ? _dashboardToolCard(tools[index])
                : _dashboardSquareAction(Icons.more_horiz_rounded, 'المزيد', violet, () => _showAllDashboardTools(allTools)),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              itemCount: extras.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: .98),
              itemBuilder: (context, index) => _dashboardToolCard(extras[index]),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: _dashboardSectionTitle(Icons.history_rounded, 'المشاريع الحديثة')),
              _dashboardPillButton('عرض الكل', Icons.chevron_left_rounded, openProjectFolder),
            ]),
            const SizedBox(height: 9),
            _dashboardProjectCard(
              icon: Icons.folder_special_rounded,
              title: projectName == 'لا يوجد مشروع' ? tab.fileName : projectName,
              subtitle: projectUri ?? 'الملف الحالي • ${tab.language}',
              onTap: projectUri != null ? openProjectFolder : _openEditorFullScreen,
              accent: cyan,
            ),
            const SizedBox(height: 9),
            _dashboardProjectCard(
              icon: Icons.code_rounded, title: tab.fileName,
              subtitle: 'الملف المفتوح حالياً • ${tab.language}',
              onTap: _openEditorFullScreen, accent: violet,
            ),
            const SizedBox(height: 15),
            _workspaceMetricsPanel(),
            const SizedBox(height: 12),
            _dashboardPanel(child: Row(children: [
              const Icon(Icons.circle, color: green, size: 9),
              const SizedBox(width: 9),
              Expanded(child: Text(tab.isSaved ? 'جميع التغييرات محفوظة' : 'توجد تغييرات غير محفوظة',
                style: const TextStyle(color: Color(0xFFDCE8F7), fontSize: 11))),
              Text(tab.language, style: const TextStyle(color: cyan, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Text('Ln ${tab.controller.selection.isValid ? tab.controller.selection.extentOffset : 1}',
                style: const TextStyle(color: Color(0xFF9CB1D0), fontSize: 10)),
            ])),
          ],
        ),
      ]),
    );
  }

  Widget _dashboardFileStrip(EditorTab tab) => Container(
    height: 54, padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: const Color(0xFF0A1428).withValues(alpha: .88),
      border: Border(bottom: BorderSide(color: const Color(0xFF147DBB).withValues(alpha: .55)))),
    child: Row(children: [
      IconButton(onPressed: createNewTab, icon: const Icon(Icons.add, color: Color(0xFF08B9F4), size: 30)),
      const Spacer(),
      const Icon(Icons.close, color: Color(0xFF9AAAC4), size: 18),
      const SizedBox(width: 9),
      Text(tab.fileName, style: const TextStyle(color: Color(0xFFE7EFFB), fontSize: 14)),
      const SizedBox(width: 10),
      const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF08B9F4)),
    ]),
  );

  Widget _dashboardGlowPanel({required Widget child}) => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(25),
      gradient: const LinearGradient(colors: [Color(0xFF0789D7), Color(0xFF202A73), Color(0xFF8C20D8)]),
      boxShadow: [BoxShadow(color: const Color(0xFF087FEA).withValues(alpha: .22), blurRadius: 18, spreadRadius: 1)]),
    child: Container(padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: const Color(0xFF0A142A), borderRadius: BorderRadius.circular(19)),
      child: child),
  );

  Widget _dashboardSquareAction(IconData icon, String label, Color color, VoidCallback onTap) =>
    Material(color: const Color(0xFF111E37), borderRadius: BorderRadius.circular(19),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(19),
        child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(19),
          border: Border.all(color: color.withValues(alpha: .42))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 31), const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ]))));

  Widget _dashboardPillButton(String label, IconData icon, VoidCallback onTap) =>
    OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 19), label: Text(label),
      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDCE8F7),
        side: const BorderSide(color: Color(0xFF3155A7)), shape: const StadiumBorder()));

  void _showAllDashboardTools(List<_DashboardAction> actions) {
    var query = '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final needle = query.trim().toLowerCase();
          final filtered = needle.isEmpty
              ? actions
              : actions
                  .where((a) => a.label.toLowerCase().contains(needle))
                  .toList();
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * .78,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        'جميع أدوات Bisho IDE',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        onChanged: (value) => setSheetState(() => query = value),
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          hintText: 'ابحث عن أداة...',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('لا توجد أدوات مطابقة'))
                          : GridView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filtered.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 9,
                                mainAxisSpacing: 9,
                                childAspectRatio: 1.15,
                              ),
                              itemBuilder: (_, index) {
                                final action = filtered[index];
                                return _dashboardToolCard(
                                  _DashboardAction(action.icon, action.label, () {
                                    Navigator.pop(sheetContext);
                                    action.onTap();
                                  }, action.color),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _workspaceMetricsPanel() {
    final metrics = WorkspaceMetrics.fromSources(
      tabs.map((tab) => tab.controller.text),
    );
    return _dashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dashboardSectionTitle(Icons.insights_rounded, 'ملخص مساحة العمل'),
          const SizedBox(height: 11),
          Row(
            children: [
              _metricTile('التبويبات', metrics.fileCount.toString(), Icons.tab),
              _metricTile('الأسطر', metrics.lineCount.toString(), Icons.format_align_left),
              _metricTile('الكلمات', metrics.wordCount.toString(), Icons.text_fields),
              _metricTile('الأحرف', metrics.characterCount.toString(), Icons.notes),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'الإحصائيات محسوبة من محتوى التبويبات المفتوحة فقط',
            style: TextStyle(color: Colors.white.withValues(alpha: .48), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value, IconData icon) => Expanded(
    child: Column(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF38BDF8)),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
      ],
    ),
  );

  Future<void> _openTextDiffDialog() async {
    final previousController = TextEditingController();
    ProjectTextDiffReport? report;
    final currentText = activeTab.controller.text;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('مقارنة النص الحالي بنسخة سابقة'),
            content: SizedBox(
              width: 620,
              height: 460,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (report == null) ...[
                    const Text('الصق النص السابق هنا، وسيتم مقارنته بمحتوى التبويب الحالي.'),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TextField(
                        controller: previousController,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: 'النص السابق...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                  ] else ...[
                    Wrap(spacing: 12, runSpacing: 6, children: [
                      Text('إضافات: ${report!.addedCount}', style: const TextStyle(color: Color(0xFF19D889))),
                      Text('حذف: ${report!.removedCount}', style: const TextStyle(color: Color(0xFFFF657A))),
                      Text('دون تغيير: ${report!.unchangedCount}', style: const TextStyle(color: Color(0xFF9BAFCB))),
                    ]),
                    if (report!.usedFallback)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('مقارنة كبيرة: عُرضت الفروقات بتقريب آمن لتقليل استهلاك الذاكرة.',
                          style: TextStyle(color: Color(0xFFFFC247), fontSize: 11)),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: const Color(0xFF080F20),
                          borderRadius: BorderRadius.circular(10)),
                        child: ListView.builder(
                          itemCount: report!.lines.length,
                          itemBuilder: (_, index) {
                            final line = report!.lines[index];
                            final added = line.kind == TextDiffKind.added;
                            final removed = line.kind == TextDiffKind.removed;
                            final prefix = added ? '+' : removed ? '-' : ' ';
                            final color = added ? const Color(0xFF19D889)
                                : removed ? const Color(0xFFFF657A) : const Color(0xFF9BAFCB);
                            return Container(
                              color: added ? const Color(0x2219D889)
                                  : removed ? const Color(0x22FF657A) : Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              child: Text('$prefix ${line.oldLine ?? '-'}:${line.newLine ?? '-'}  ${line.text.isEmpty ? ' ' : line.text}',
                                style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 11),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (report != null)
                TextButton(onPressed: () => setDialogState(() => report = null),
                  child: const Text('تغيير النص السابق')),
              TextButton(onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إغلاق')),
              if (report == null)
                FilledButton.icon(
                  onPressed: () => setDialogState(() {
                    report = const ProjectTextDiff().compare(
                      previousController.text, currentText);
                  }),
                  icon: const Icon(Icons.difference_rounded),
                  label: const Text('اعرض الفروقات'),
                ),
            ],
          ),
        ),
      );
    } finally {
      previousController.dispose();
    }
  }

  void _openProjectInsightsPanel() {
    final files = <String, String>{};
    for (final tab in tabs) {
      final path = tab.fileName.replaceAll('\\', '/');
      if (path.isNotEmpty && !files.containsKey(path)) {
        files[path] = tab.controller.text;
      }
    }
    final report = const ProjectInsightsAnalyzer().analyze(files);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .72,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
              child: Row(children: [
                const Icon(Icons.health_and_safety_rounded, color: Color(0xFF19D889)),
                const SizedBox(width: 9),
                const Expanded(child: Text('فحص جودة المشروع', style: TextStyle(fontWeight: FontWeight.w700))),
                Text('${report.filesScanned} ملف · ${report.linesScanned} سطر',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close)),
              ]),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [
              _insightCount('أخطاء', report.count(ProjectInsightSeverity.error), const Color(0xFFFF647C)),
              _insightCount('تحذيرات', report.count(ProjectInsightSeverity.warning), const Color(0xFFFFC247)),
              _insightCount('ملاحظات', report.count(ProjectInsightSeverity.info), const Color(0xFF38BDF8)),
            ])),
            const Divider(height: 18),
            Expanded(child: report.insights.isEmpty
                ? const Center(child: Text('لا توجد ملاحظات في الملفات المفتوحة.'))
                : ListView.separated(
                    itemCount: report.insights.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final issue = report.insights[index];
                      final color = issue.severity == ProjectInsightSeverity.error
                          ? const Color(0xFFFF647C)
                          : issue.severity == ProjectInsightSeverity.warning
                              ? const Color(0xFFFFC247) : const Color(0xFF38BDF8);
                      return ListTile(
                        dense: true,
                        leading: Icon(issue.severity == ProjectInsightSeverity.error
                            ? Icons.error_outline : issue.severity == ProjectInsightSeverity.warning
                                ? Icons.warning_amber_rounded : Icons.info_outline, color: color),
                        title: Text(issue.message, style: const TextStyle(fontSize: 12)),
                        subtitle: Text(issue.line > 0 ? '${issue.path}:${issue.line}' : issue.path,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      );
                    },
                  )),
            const Padding(padding: EdgeInsets.all(10), child: Text(
              'الفحص يغطي التبويبات المفتوحة فقط ولا يغيّر أي ملف. نتائج الاستيراد والتحذيرات إرشادية.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _insightCount(String label, int count, Color color) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text('$count', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFFCBD5E1))),
      ]),
    ),
  );

  void _openDiagnosticsPanel() {
    final tab = activeTab;
    final diagnostics = _getCurrentDiagnostics(tab);
    final structural = EditorSyntaxDiagnostics.analyze(
      tab.controller.text,
      tab.language,
    );
    final parserCount = (diagnostics.length - structural.length)
        .clamp(0, diagnostics.length)
        .toInt();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .62,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  children: [
                    const Icon(Icons.bug_report_outlined, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 9),
                    Expanded(child: Text('مشكلات ${tab.fileName}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text('${diagnostics.length}', style: const TextStyle(color: Color(0xFF94A3B8))),
                    IconButton(onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: diagnostics.isEmpty
                    ? const Center(child: Text('لا توجد مشكلات معروفة في الفحص الحالي'))
                    : ListView.separated(
                        itemCount: diagnostics.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          if (index < parserCount) {
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.error_outline, color: Colors.orange),
                              title: Text(diagnostics[index], style: const TextStyle(fontSize: 12)),
                              subtitle: const Text('نتيجة محلل البيانات المحلي'),
                            );
                          }
                          final issue = structural[index - parserCount];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                            title: Text(issue.message, style: const TextStyle(fontSize: 12)),
                            subtitle: Text('السطر ${issue.line}، العمود ${issue.column}'),
                            trailing: const Icon(Icons.my_location, size: 17),
                            onTap: () {
                              final offset = issue.offset
                                  .clamp(0, tab.controller.text.length)
                                  .toInt();
                              tab.controller.selection = TextSelection.collapsed(offset: offset);
                              _scheduleTabStateSave();
                              Navigator.pop(sheetContext);
                              _openEditorFullScreen();
                            },
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'الفحص بنيوي ومحلي؛ اضغط على المشكلة ذات الموقع للانتقال إليها. لا يحل محل محلل المترجم الرسمي.',
                  style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: .55)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showWorkspaceSettings() async {
    var draftFontSize = _editorFontSize;
    var draftExplorerVisible = explorerVisible;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refreshSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.tune_rounded, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 9),
                  const Expanded(child: Text('إعدادات مساحة العمل',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  IconButton(onPressed: () => Navigator.pop(sheetContext, false),
                    icon: const Icon(Icons.close)),
                ]),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('إظهار مستكشف الملفات'),
                  value: draftExplorerVisible,
                  onChanged: (value) => refreshSheet(() => draftExplorerVisible = value),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(child: Text('حجم خط المحرر')),
                  Text('${draftFontSize.round()} px', style: const TextStyle(color: Color(0xFF38BDF8))),
                ]),
                Slider(
                  min: 10, max: 24, divisions: 14,
                  value: draftFontSize,
                  onChanged: (value) => refreshSheet(() => draftFontSize = value),
                ),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.save_rounded), label: const Text('حفظ الإعدادات'),
                )),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true || !mounted) return;
    setState(() {
      _editorFontSize = draftFontSize.clamp(10.0, 24.0).toDouble();
      explorerVisible = draftExplorerVisible;
    });
    await _saveEditorPreferences();
    showMessage('تم حفظ إعدادات مساحة العمل');
  }

  Widget _dashboardPanel({required Widget child}) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF151F30),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF29384D), width: 1),
    ),
    child: child,
  );

  Widget _dashboardToolCard(_DashboardAction action) => Material(
    color: const Color(0xFF101D36),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: action.onTap, borderRadius: BorderRadius.circular(19),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(19),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [action.color.withValues(alpha: .17), const Color(0xFF111B34), const Color(0xFF0C142A)]),
          border: Border.all(color: action.color.withValues(alpha: .38)),
          boxShadow: [BoxShadow(color: action.color.withValues(alpha: .10), blurRadius: 12)]),
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(action.icon, size: 27, color: action.color),
          const SizedBox(height: 6),
          Flexible(child: Text(action.label, maxLines: 2, softWrap: true,
            overflow: TextOverflow.visible, textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFEAF2FF),
              fontSize: 10, height: 1.16, fontWeight: FontWeight.w600))),
        ]),
      ),
    ),
  );

  Widget _dashboardSectionTitle(IconData icon, String title) => Row(children: [
    Icon(icon, color: const Color(0xFF38BDF8), size: 20),
    const SizedBox(width: 8),
    Expanded(child: Text(title, style: const TextStyle(
      color: Color(0xFFE5EDF7), fontSize: 14, fontWeight: FontWeight.w700))),
  ]);

  Widget _dashboardProjectCard({required IconData icon, required String title,
    required String subtitle, required VoidCallback onTap, required Color accent}) =>
    Material(
      color: const Color(0xFF101B34),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: .38)),
            boxShadow: [BoxShadow(color: accent.withValues(alpha: .10), blurRadius: 13)],
          ),
          child: Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF1B293D),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: accent, size: 23),
            ),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFE5EDF7),
                  fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 4),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
            ])),
            Icon(Icons.chevron_left_rounded, color: accent),
          ]),
        ),
      ),
    );

  void _showDashboardThemeInfo() {
    BishoThemeController.toggle();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تبديل الثيم')),
    );
  }

  void _showPluginsHub() {
    final actions = <_DashboardAction>[
      _DashboardAction(Icons.data_object_rounded, 'تنسيق JSON', () => _runEditorExtension('json_format'), const Color(0xFF08B9F4)),
      _DashboardAction(Icons.compress_rounded, 'ضغط JSON', () => _runEditorExtension('json_minify'), const Color(0xFF8B42F5)),
      _DashboardAction(Icons.lock_rounded, 'ترميز Base64', () => _runEditorExtension('base64_encode'), const Color(0xFF19D889)),
      _DashboardAction(Icons.lock_open_rounded, 'فك Base64', () => _runEditorExtension('base64_decode'), const Color(0xFFFFC247)),
      _DashboardAction(Icons.link_rounded, 'ترميز URL', () => _runEditorExtension('url_encode'), const Color(0xFF08B9F4)),
      _DashboardAction(Icons.link_off_rounded, 'فك URL', () => _runEditorExtension('url_decode'), const Color(0xFF247BFF)),
      _DashboardAction(Icons.sort_by_alpha_rounded, 'ترتيب الأسطر', () => _runEditorExtension('sort_lines'), const Color(0xFF8B42F5)),
      _DashboardAction(Icons.filter_alt_rounded, 'حذف الأسطر المكررة', () => _runEditorExtension('unique_lines'), const Color(0xFF19D889)),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(children: [
                  const Icon(Icons.extension_rounded, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 9),
                  const Expanded(child: Text('إضافات وأدوات مدمجة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  IconButton(onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close)),
                ]),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(alignment: Alignment.centerRight,
                  child: Text('أدوات محلية تعمل مباشرة على محتوى الملف الحالي',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11))),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                  itemCount: actions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
                    childAspectRatio: 1.55),
                  itemBuilder: (_, index) => _dashboardToolCard(_DashboardAction(
                    actions[index].icon, actions[index].label, () {
                      Navigator.pop(sheetContext);
                      actions[index].onTap();
                    }, actions[index].color)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runEditorExtension(String operation) async {
    if (tabs.isEmpty) {
      showMessage('افتح ملفاً أولاً لاستخدام الإضافة');
      return;
    }
    final tab = activeTab;
    final controller = tab.controller;
    final source = controller.text;
    final selection = controller.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final start = hasSelection ? selection.start : 0;
    final end = hasSelection ? selection.end : source.length;
    final input = source.substring(start, end);
    String output;
    String success;

    try {
      switch (operation) {
        case 'json_format':
          output = const JsonEncoder.withIndent('  ').convert(jsonDecode(input));
          success = 'تم تنسيق JSON';
          break;
        case 'json_minify':
          output = jsonEncode(jsonDecode(input));
          success = 'تم ضغط JSON وإزالة المسافات';
          break;
        case 'base64_encode':
          output = base64Encode(utf8.encode(input));
          success = 'تم ترميز النص بصيغة Base64';
          break;
        case 'base64_decode':
          output = utf8.decode(base64Decode(input.trim()));
          success = 'تم فك ترميز Base64';
          break;
        case 'url_encode':
          output = Uri.encodeComponent(input);
          success = 'تم ترميز النص للرابط';
          break;
        case 'url_decode':
          output = Uri.decodeComponent(input);
          success = 'تم فك ترميز الرابط';
          break;
        case 'sort_lines':
          final lines = input.split('\n')..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          output = lines.join('\n');
          success = 'تم ترتيب الأسطر أبجدياً';
          break;
        case 'unique_lines':
          final seen = <String>{};
          output = input.split('\n').where((line) => seen.add(line)).join('\n');
          success = 'تم حذف الأسطر المكررة';
          break;
        default:
          return;
      }
    } catch (error) {
      showMessage('تعذر تنفيذ الإضافة: ${error is FormatException ? error.message : error}');
      return;
    }

    final updated = source.replaceRange(start, end, output);
    controller.value = controller.value.copyWith(
      text: updated,
      selection: TextSelection.collapsed(offset: start + output.length),
      composing: TextRange.empty,
    );
    tab.isSaved = false;
    _scheduleTabStateSave();
    if (mounted) setState(() {});
    showMessage(success);
  }

  void _showDiagnosticsAvailabilityInfo() {
    showMessage('لوحة التحليل والمشكلات المتكاملة قيد التطوير؛ أدوات التشخيص الحالية تعمل حسب اللغة المدعومة');
  }

  void _showLanguageCapabilities() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  children: [
                    const Icon(Icons.code_rounded, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 9),
                    const Expanded(child: Text('دليل اللغات والقدرات',
                      style: TextStyle(fontWeight: FontWeight.w700))),
                    IconButton(onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: LanguageEngineManager.capabilities.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final capability = LanguageEngineManager.capabilities[index];
                    final hasPreviewRoute = capability.extensions.any((extension) =>
                        LanguageEngineManager.engineForFile('sample.$extension') !=
                        LanguageEngine.unsupported);
                    final notes = capability.note.isNotEmpty
                        ? capability.note
                        : capability.executionEngine
                            ? 'توجد معاينة أو بيئة تنفيذ محددة لهذه اللغة.'
                            : hasPreviewRoute
                                ? 'توجد أداة عرض أو تحقق للملفات، دون تشغيل برنامج مستقل.'
                                : 'تحرير وتلوين؛ لا يوجد محرك تشغيل مضمّن حالياً.';
                    return ExpansionTile(
                      title: Text(capability.language,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(notes, style: const TextStyle(fontSize: 10)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Chip(label: Text(capability.syntaxHighlighting ? 'تلوين مدعوم' : 'نص عادي')),
                              Chip(label: Text(capability.structuralDiagnostics ? 'فحص بنيوي' : 'بدون فحص بنيوي')),
                              Chip(label: Text(hasPreviewRoute ? 'معاينة/عرض متاح' : 'لا يوجد محرك تشغيل')),
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'الامتدادات: ${capability.extensions.map((extension) => ".$extension").join("، ")}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditorInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('معلومات المحرر'),
        content: const Text('يوفر Bisho IDE أدوات إنشاء الملفات والمشاريع، والحفظ والتصدير، والبحث والاستبدال، والتنقل بين الأسطر، وإكمال الكود، ومعاينة اللغات المدعومة. نضيف الميزات تدريجياً بعد اختبارها.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget toolButton(
    IconData icon,
    String label,
    VoidCallback action,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: const Color(0xFF38BDF8),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blue = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6
      ..shader = const LinearGradient(colors: [Color(0x0012AFFF), Color(0xFF087DFF), Color(0xFF12AFFF)])
        .createShader(Offset.zero & size);
    final purple = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5
      ..shader = const LinearGradient(colors: [Color(0x002D65FF), Color(0xFF8B24FF), Color(0xFFB21FFF)])
        .createShader(Offset.zero & size);
    final a = Path()..moveTo(0, size.height * .18)
      ..cubicTo(size.width * .22, size.height * .62, size.width * .36, size.height * .80, size.width * .58, size.height * .52)
      ..cubicTo(size.width * .76, size.height * .27, size.width * .88, size.height * .20, size.width, size.height * .42);
    final b = Path()..moveTo(0, size.height * .38)
      ..cubicTo(size.width * .22, size.height * .82, size.width * .42, size.height * .93, size.width * .62, size.height * .67)
      ..cubicTo(size.width * .78, size.height * .44, size.width * .91, size.height * .32, size.width, size.height * .56);
    canvas.drawPath(a, blue);
    canvas.drawPath(b, purple);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashboardAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _DashboardAction(this.icon, this.label, this.onTap, this.color);
}

/// شاشة مستقلة للمحرر؛ تستخدم نفس CodeController حتى تبقى التعديلات
/// والتبويبات والحالة محفوظة عند الرجوع إلى الواجهة الرئيسية.
class EditorFullScreenScreen extends StatefulWidget {
  const EditorFullScreenScreen({
    super.key,
    required this.tab,
    required this.fontSize,
    required this.onSave,
    required this.onFontSizeChange,
    required this.onShowCompletions,
    required this.onSearch,
    required this.onPreview,
    required this.onFlutterPreview,
  });

  final EditorTab tab;
  final double fontSize;
  final Future<void> Function() onSave;
  final void Function(double delta) onFontSizeChange;
  final Future<void> Function() onShowCompletions;
  final Future<void> Function(bool replaceMode) onSearch;
  final Future<void> Function() onPreview;
  final void Function() onFlutterPreview;

  @override
  State<EditorFullScreenScreen> createState() =>
      _EditorFullScreenScreenState();
}

class _EditorFullScreenScreenState extends State<EditorFullScreenScreen> {
  static const String _wordWrapPreferenceKey = 'bisho_editor_word_wrap';
  late double _fontSize;
  bool _wordWrap = false;

  @override
  void initState() {
    super.initState();
    _fontSize = widget.fontSize;
    _restoreWordWrapPreference();
  }

  Future<void> _restoreWordWrapPreference() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedValue = preferences.getBool(_wordWrapPreferenceKey) ?? false;
      if (!mounted) return;
      setState(() => _wordWrap = savedValue);
    } catch (_) {
      // Word wrap remains available with its default when preferences fail.
    }
  }

  Future<void> _toggleWordWrap() async {
    final nextValue = !_wordWrap;
    setState(() => _wordWrap = nextValue);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_wordWrapPreferenceKey, nextValue);
    } catch (_) {
      // The current session setting remains active if persistence is unavailable.
    }
  }

  void _changeFontSize(double delta) {
    widget.onFontSizeChange(delta);
    setState(() {
      _fontSize = (_fontSize + delta).clamp(10.0, 24.0).toDouble();
    });
  }

  void _insertSymbol(String symbol) {
    final controller = widget.tab.controller;
    final nextValue = EditorSymbolInsert.apply(
      text: controller.text,
      selection: controller.selection,
      symbol: symbol,
    );
    controller.value = nextValue;
  }

  void _moveCursor({int horizontal = 0, int vertical = 0}) {
    final controller = widget.tab.controller;
    final text = controller.text;
    final selection = controller.selection;
    final current = selection.isValid
        ? selection.extentOffset.clamp(0, text.length).toInt()
        : text.length;

    int target;
    if (horizontal != 0) {
      target = (current + horizontal).clamp(0, text.length).toInt();
    } else {
      final lineStart = text.lastIndexOf('\\n', current - 1) + 1;
      final lineEndFound = text.indexOf('\\n', current);
      final lineEnd = lineEndFound == -1 ? text.length : lineEndFound;
      final column = current - lineStart;
      if (vertical < 0) {
        if (lineStart == 0) return;
        final previousEnd = lineStart - 1;
        final previousStart = text.lastIndexOf('\\n', previousEnd - 1) + 1;
        target = (previousStart + column).clamp(previousStart, previousEnd).toInt();
      } else {
        if (lineEnd == text.length) return;
        final nextStart = lineEnd + 1;
        final nextEndFound = text.indexOf('\\n', nextStart);
        final nextEnd = nextEndFound == -1 ? text.length : nextEndFound;
        target = (nextStart + column).clamp(nextStart, nextEnd).toInt();
      }
    }
    controller.selection = TextSelection.collapsed(offset: target);
  }

  void _setCursor(int offset, {bool extendSelection = false}) {
    final controller = widget.tab.controller;
    final safe = offset.clamp(0, controller.text.length).toInt();
    final current = controller.selection;
    controller.selection = extendSelection && current.isValid
        ? TextSelection(baseOffset: current.baseOffset, extentOffset: safe)
        : TextSelection.collapsed(offset: safe);
  }

  void _selectCurrentWord() {
    final controller = widget.tab.controller;
    final offset = controller.selection.isValid
        ? controller.selection.extentOffset
        : controller.text.length;
    final selected = EditorTextNavigation.selectCurrentWord(controller.text, offset);
    controller.selection = selected;
  }

  Future<void> _copySelection() async {
    final controller = widget.tab.controller;
    final selection = controller.selection;
    final text = selection.isValid && !selection.isCollapsed
        ? controller.text.substring(selection.start, selection.end)
        : controller.text;
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _cutSelection() async {
    final controller = widget.tab.controller;
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final selectedText = controller.text.substring(selection.start, selection.end);
    await Clipboard.setData(ClipboardData(text: selectedText));
    controller.value = EditorTextNavigation.replaceSelection(
      controller.text,
      selection,
      '',
    );
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasted = data?.text;
    if (pasted == null) return;
    final controller = widget.tab.controller;
    final selection = controller.selection;
    controller.value = EditorTextNavigation.replaceSelection(
      controller.text,
      selection,
      pasted,
    );
  }

  KeyEventResult _handleEditorKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final control = keyboard.isControlPressed || keyboard.isMetaPressed;
    final controller = widget.tab.controller;
    final selection = controller.selection;
    final offset = selection.isValid
        ? selection.extentOffset.clamp(0, controller.text.length).toInt()
        : controller.text.length;
    final extend = event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight ||
        keyboard.isShiftPressed;

    if (control && event.logicalKey == LogicalKeyboardKey.keyS) {
      widget.onSave();
      return KeyEventResult.handled;
    }
    if (control && event.logicalKey == LogicalKeyboardKey.keyF) {
      widget.onSearch(false);
      return KeyEventResult.handled;
    }
    if (control && event.logicalKey == LogicalKeyboardKey.keyH) {
      widget.onSearch(true);
      return KeyEventResult.handled;
    }
    if (control && event.logicalKey == LogicalKeyboardKey.space) {
      widget.onShowCompletions();
      return KeyEventResult.handled;
    }
    if (control && event.logicalKey == LogicalKeyboardKey.keyD) {
      _selectCurrentWord();
      return KeyEventResult.handled;
    }
    if (control && (event.logicalKey == LogicalKeyboardKey.equal ||
        event.logicalKey == LogicalKeyboardKey.add)) {
      _changeFontSize(1);
      return KeyEventResult.handled;
    }
    if (control && (event.logicalKey == LogicalKeyboardKey.minus ||
        event.logicalKey == LogicalKeyboardKey.numpadSubtract)) {
      _changeFontSize(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) {
      _setCursor(control ? 0 : EditorTextNavigation.lineStart(controller.text, offset),
          extendSelection: extend);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.end) {
      _setCursor(control ? controller.text.length :
          EditorTextNavigation.lineEnd(controller.text, offset),
          extendSelection: extend);
      return KeyEventResult.handled;
    }
    if (control && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _setCursor(EditorTextNavigation.moveByWord(controller.text, offset, forward: false),
          extendSelection: extend);
      return KeyEventResult.handled;
    }
    if (control && event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _setCursor(EditorTextNavigation.moveByWord(controller.text, offset, forward: true),
          extendSelection: extend);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildCursorPad() {
    Widget arrow(IconData icon, String tooltip, int horizontal, int vertical) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: const Color(0xFF1B293D),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _moveCursor(horizontal: horizontal, vertical: vertical),
            child: SizedBox(
              width: 38,
              height: 34,
              child: Icon(icon, size: 18, color: const Color(0xFFBAE6FD)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        border: Border(
          bottom: BorderSide(color: Color(0xFF26334D)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location, size: 16, color: Color(0xFF38BDF8)),
          const SizedBox(width: 7),
          const Expanded(
            child: Text(
              'التحكم بالمؤشر',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ),
          arrow(Icons.keyboard_arrow_left, 'تحريك المؤشر يساراً', -1, 0),
          const SizedBox(width: 5),
          arrow(Icons.keyboard_arrow_up, 'السطر السابق', 0, -1),
          const SizedBox(width: 5),
          arrow(Icons.keyboard_arrow_down, 'السطر التالي', 0, 1),
          const SizedBox(width: 5),
          arrow(Icons.keyboard_arrow_right, 'تحريك المؤشر يميناً', 1, 0),
        ],
      ),
    );
  }

  Widget _buildMobileSymbolBar() {
    const symbols = <String>[
      'TAB', '(', '{', '[', ';', ':', '=', '=>', '.', ',', '->',
      "'", '"', '`', '&&', '||', '!',
    ];
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        border: Border(
          bottom: BorderSide(color: Color(0xFF26334D)),
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          itemCount: symbols.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final symbol = symbols[index];
            final label = symbol == 'TAB' ? '⇥' : symbol;
            return Material(
              color: const Color(0xFF1B293D),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _insertSymbol(symbol),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 38),
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF304158)),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFBAE6FD),
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080D19),
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'العودة إلى Bisho IDE',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tab.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                tab.language,
                style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8)),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'معاينة / تشغيل الملف الحالي',
              onPressed: widget.onPreview,
              icon: const Icon(Icons.play_circle_fill_rounded,
                color: Color(0xFF19D889)),
            ),
            IconButton(
              tooltip: 'بناء ومعاينة Flutter',
              onPressed: widget.onFlutterPreview,
              icon: const Icon(Icons.phone_android_rounded,
                color: Color(0xFF38BDF8)),
            ),
            PopupMenuButton<String>(
              tooltip: 'أدوات التحرير',
              onSelected: (action) {
                switch (action) {
                  case 'select_word':
                    _selectCurrentWord();
                    break;
                  case 'copy':
                    _copySelection();
                    break;
                  case 'cut':
                    _cutSelection();
                    break;
                  case 'paste':
                    _pasteClipboard();
                    break;
                  case 'wrap':
                    _toggleWordWrap();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'select_word',
                  child: Row(
                    children: [
                      Icon(Icons.select_all, size: 20),
                      const SizedBox(width: 12),
                      Text('تحديد الكلمة الحالية (Ctrl+D)'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy, size: 20),
                      const SizedBox(width: 12),
                      Text('نسخ المحدد'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'cut',
                  child: Row(
                    children: [
                      Icon(Icons.content_cut, size: 20),
                      const SizedBox(width: 12),
                      Text('قص المحدد'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'paste',
                  child: Row(
                    children: [
                      Icon(Icons.content_paste, size: 20),
                      const SizedBox(width: 12),
                      Text('لصق'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'wrap',
                  child: Row(
                    children: [
                      Icon(_wordWrap ? Icons.wrap_text : Icons.notes, size: 20),
                      const SizedBox(width: 12),
                      Text(_wordWrap ? 'تعطيل التفاف الأسطر' : 'تفعيل التفاف الأسطر'),
                    ],
                  ),
                ),
              ],
              icon: const Icon(Icons.edit_note),
            ),
            IconButton(
              tooltip: 'إكمال تلقائي',
              onPressed: widget.onShowCompletions,
              icon: const Icon(Icons.auto_awesome),
            ),
            IconButton(
              tooltip: 'تصغير الخط',
              onPressed: () => _changeFontSize(-1),
              icon: const Icon(Icons.text_decrease),
            ),
            IconButton(
              tooltip: 'تكبير الخط',
              onPressed: () => _changeFontSize(1),
              icon: const Icon(Icons.text_increase),
            ),
            IconButton(
              tooltip: 'حفظ الملف',
              onPressed: widget.onSave,
              icon: const Icon(Icons.save),
            ),
          ],
        ),
        body: SafeArea(
          child: Focus(
            onKeyEvent: _handleEditorKey,
            child: Column(
            children: [
              _buildMobileSymbolBar(),
              _buildCursorPad(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                  child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF080D19),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF26334D)),
              ),
              clipBehavior: Clip.antiAlias,
              child: CodeTheme(
                data: CodeThemeData(styles: monokaiSublimeTheme),
                child: CodeField(
                  key: ValueKey('fullscreen-${tab.id}'),
                  controller: tab.controller,
                  expands: true,
                  wrap: _wordWrap,
                  padding: const EdgeInsets.all(14),
                  textStyle: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: _fontSize,
                  ),
                  gutterStyle: const GutterStyle(
                    showLineNumbers: true,
                    showErrors: true,
                    showFoldingHandles: true,
                  ),
                ),
              ),
            ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
