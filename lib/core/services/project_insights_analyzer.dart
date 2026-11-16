/// Static, dependency-free project insights for Bisho IDE.
/// The analyzer consumes an in-memory file map and never reads or mutates disk.
enum ProjectInsightSeverity { info, warning, error }

enum ProjectInsightCategory {
  structure,
  imports,
  maintenance,
  security,
  dependencies,
  style,
}

class ProjectInsight {
  final String code;
  final String path;
  final int line;
  final String message;
  final ProjectInsightSeverity severity;
  final ProjectInsightCategory category;

  const ProjectInsight({
    required this.code,
    required this.path,
    required this.line,
    required this.message,
    required this.severity,
    required this.category,
  });
}

class ProjectInsightsReport {
  final List<ProjectInsight> insights;
  final int filesScanned;
  final int linesScanned;

  ProjectInsightsReport({
    required Iterable<ProjectInsight> insights,
    required this.filesScanned,
    required this.linesScanned,
  }) : insights = List.unmodifiable(insights);

  int count(ProjectInsightSeverity severity) =>
      insights.where((item) => item.severity == severity).length;

  bool get hasErrors => count(ProjectInsightSeverity.error) > 0;
}

class ProjectInsightsAnalyzer {
  const ProjectInsightsAnalyzer();

  static const _sourceExtensions = <String>{'.dart', '.js', '.ts', '.jsx', '.tsx', '.py'};
  static const _ignoredDirectories = <String>{'.git', '.dart_tool', 'build', 'node_modules'};

  ProjectInsightsReport analyze(Map<String, String> files) {
    final normalized = <String, String>{};
    for (final entry in files.entries) {
      final path = _normalize(entry.key);
      if (path != null && !_isIgnored(path)) normalized[path] = entry.value;
    }

    final result = <ProjectInsight>[];
    var lineCount = 0;
    final pathSet = normalized.keys.toSet();
    final pubspec = normalized['pubspec.yaml'];
    final declaredPackages = _readPubPackages(pubspec ?? '');

    void add(String code, String path, int line, String message,
        ProjectInsightSeverity severity, ProjectInsightCategory category) {
      result.add(ProjectInsight(code: code, path: path, line: line,
          message: message, severity: severity, category: category));
    }

    if (normalized.isEmpty) {
      add('empty_project', '.', 0, 'لا توجد ملفات قابلة للتحليل في المشروع.',
          ProjectInsightSeverity.info, ProjectInsightCategory.structure);
    }

    if (pubspec != null && !normalized.containsKey('lib/main.dart')) {
      add('flutter_entry_missing', 'lib/main.dart', 0,
          'يوجد pubspec.yaml لكن لم يتم العثور على lib/main.dart؛ تحقق من نوع المشروع.',
          ProjectInsightSeverity.warning, ProjectInsightCategory.structure);
    }

    final sourcePaths = normalized.keys.where(_isSource).toList()..sort();
    final usedPackages = <String>{};
    for (final path in sourcePaths) {
      final source = normalized[path]!;
      final lines = source.split('\n');
      lineCount += lines.length;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lineNo = i + 1;
        if (RegExp(r'\b(TODO|FIXME|XXX)\b', caseSensitive: false).hasMatch(line)) {
          add('maintenance_marker', path, lineNo,
              'يوجد تعليق صيانة يحتاج إلى مراجعة.', ProjectInsightSeverity.info,
              ProjectInsightCategory.maintenance);
        }
        if (RegExp(r'catch\s*\([^)]*\)\s*\{\s*\}').hasMatch(line) ||
            RegExp(r'catch\s*\{\s*\}').hasMatch(line)) {
          add('empty_catch', path, lineNo,
              'كتلة catch فارغة؛ قد يؤدي ذلك إلى إخفاء خطأ مهم.',
              ProjectInsightSeverity.warning, ProjectInsightCategory.maintenance);
        }
        if (RegExp(r'''(?:api[_-]?key|secret|password|token)\s*[:=]\s*['"][^'"]{8,}['"]''',
            caseSensitive: false).hasMatch(line)) {
          add('possible_embedded_secret', path, lineNo,
              'قد يحتوي هذا السطر على سر ثابت؛ انقل القيمة إلى تخزين آمن أو متغير بيئة.',
              ProjectInsightSeverity.warning, ProjectInsightCategory.security);
        }
        if (path.endsWith('.dart') && RegExp(r'\bprint\s*\(').hasMatch(line)) {
          add('dart_print_call', path, lineNo,
              'استخدام print في كود التطبيق؛ راجع استخدام سجلّ مناسب قبل الإصدار.',
              ProjectInsightSeverity.info, ProjectInsightCategory.style);
        }

        final importMatch = RegExp(
          r'''(?:import|export|part)\s+['"]([^'"]+)['"]''').firstMatch(line);
        if (importMatch == null) continue;
        final target = importMatch.group(1)!;
        if (target.startsWith('package:')) {
          final package = target.substring(8).split('/').first;
          usedPackages.add(package);
          if (pubspec != null && !declaredPackages.contains(package) &&
              !{'flutter', 'sky_engine'}.contains(package)) {
            add('undeclared_package_import', path, lineNo,
                'الحزمة "$package" مستخدمة في الاستيراد لكنها غير معلنة في pubspec.yaml.',
                ProjectInsightSeverity.warning, ProjectInsightCategory.dependencies);
          }
        } else if (target.startsWith('.') &&
            (path.endsWith('.dart') || path.endsWith('.js') || path.endsWith('.ts') ||
             path.endsWith('.jsx') || path.endsWith('.tsx'))) {
          final resolved = _resolveRelative(path, target);
          if (resolved != null && !_relativeTargetExists(resolved, pathSet)) {
            add('unresolved_relative_import', path, lineNo,
                'تعذر العثور على الملف المحلي المشار إليه: $target',
                ProjectInsightSeverity.error, ProjectInsightCategory.imports);
          }
        }
      }
    }

    if (pubspec != null) {
      final unused = declaredPackages.difference(usedPackages)
        ..removeAll({'flutter', 'flutter_test'});
      for (final package in unused.toList()..sort()) {
        add('possibly_unused_dependency', 'pubspec.yaml', 0,
            'الحزمة "$package" معلنة ولا يظهر لها استيراد مباشر في ملفات المصدر المفحوصة؛ تحقق قبل حذفها.',
            ProjectInsightSeverity.info, ProjectInsightCategory.dependencies);
      }
    }

    result.sort((a, b) {
      final severity = a.severity.index.compareTo(b.severity.index);
      if (severity != 0) return severity;
      final path = a.path.compareTo(b.path);
      return path != 0 ? path : a.line.compareTo(b.line);
    });
    return ProjectInsightsReport(insights: result, filesScanned: normalized.length,
        linesScanned: lineCount);
  }

  String? _normalize(String raw) {
    final value = raw.replaceAll('\\', '/').trim();
    if (value.isEmpty || value.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(value)) return null;
    final parts = <String>[];
    for (final part in value.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..' || part.contains('\u0000')) return null;
      parts.add(part);
    }
    return parts.isEmpty ? null : parts.join('/');
  }

  bool _isIgnored(String path) => path.split('/').any(_ignoredDirectories.contains);
  bool _isSource(String path) => _sourceExtensions.any(path.endsWith);

  Set<String> _readPubPackages(String source) {
    final result = <String>{};
    var section = '';
    for (final line in source.split('\n')) {
      if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
      if (!line.startsWith(' ') && line.trim().endsWith(':')) {
        section = line.trim().substring(0, line.trim().length - 1);
        continue;
      }
      if (section == 'dependencies' || section == 'dev_dependencies') {
        final match = RegExp(r'^\s{2}([A-Za-z0-9_]+)\s*:').firstMatch(line);
        if (match != null) result.add(match.group(1)!);
      }
    }
    return result;
  }

  String? _resolveRelative(String sourcePath, String target) {
    final parts = sourcePath.split('/')..removeLast();
    for (final segment in target.replaceAll('\\', '/').split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (parts.isEmpty) return null;
        parts.removeLast();
      } else {
        parts.add(segment);
      }
    }
    return parts.isEmpty ? null : parts.join('/');
  }

  bool _relativeTargetExists(String target, Set<String> paths) {
    if (paths.contains(target)) return true;
    if (RegExp(r'\.[A-Za-z0-9]+$').hasMatch(target)) return false;
    return paths.contains('$target.dart') || paths.contains('$target.js') ||
        paths.contains('$target.ts') || paths.contains('$target.jsx') ||
        paths.contains('$target.tsx') || paths.contains('$target/index.dart') ||
        paths.contains('$target/index.js') || paths.contains('$target/index.ts');
  }
}
