import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/project_insights_analyzer.dart';

void main() {
  const analyzer = ProjectInsightsAnalyzer();

  group('ProjectInsightsAnalyzer', () {
    test('detects unresolved relative imports with source line', () {
      final report = analyzer.analyze({
        'lib/main.dart': "import 'missing.dart';\nvoid main() {}",
      });
      final issue = report.insights.singleWhere((i) => i.code == 'unresolved_relative_import');
      expect(issue.path, 'lib/main.dart');
      expect(issue.line, 1);
      expect(issue.severity, ProjectInsightSeverity.error);
    });

    test('accepts relative imports with implicit Dart extension', () {
      final report = analyzer.analyze({
        'lib/main.dart': "import 'src/app';",
        'lib/src/app.dart': 'class App {}',
      });
      expect(report.insights.where((i) => i.code == 'unresolved_relative_import'), isEmpty);
    });

    test('detects undeclared package imports and likely unused dependencies', () {
      final report = analyzer.analyze({
        'pubspec.yaml': 'dependencies:\n  flutter:\n    sdk: flutter\n  http: ^1.0.0\n  yaml: ^3.0.0\n',
        'lib/main.dart': "import 'package:dio/dio.dart';",
      });
      expect(report.insights.any((i) => i.code == 'undeclared_package_import'), isTrue);
      expect(report.insights.any((i) => i.code == 'possibly_unused_dependency' && i.message.contains('http')), isTrue);
    });

    test('reports maintenance, empty catch and possible hard-coded secrets without echoing values', () {
      final report = analyzer.analyze({
        'lib/main.dart': "// TODO: replace\nvoid f() { try {} catch (e) {} }\nconst api_key = 'abcdefghijk123';",
      });
      expect(report.insights.map((i) => i.code), containsAll([
        'maintenance_marker', 'empty_catch', 'possible_embedded_secret',
      ]));
      expect(report.insights.every((i) => !i.message.contains('abcdefghijk123')), isTrue);
    });

    test('ignores generated directories and rejects unsafe input paths', () {
      final report = analyzer.analyze({
        '../outside.dart': "import 'x.dart';",
        '.dart_tool/generated.dart': 'TODO',
        'lib/main.dart': 'void main() {}',
      });
      expect(report.filesScanned, 1);
      expect(report.insights, isEmpty);
    });

    test('reports Flutter entrypoint omission and stable counts', () {
      final report = analyzer.analyze({'pubspec.yaml': 'name: sample\n'});
      expect(report.insights.single.code, 'flutter_entry_missing');
      expect(report.filesScanned, 1);
    });
  });
}
