/// Non-destructive project structure diagnostics shared by the repair UI.
class ProjectHealthIssue {
  final String code;
  final String path;
  final String message;
  final bool repairable;

  const ProjectHealthIssue({
    required this.code,
    required this.path,
    required this.message,
    this.repairable = false,
  });
}

class ProjectHealthAnalyzer {
  const ProjectHealthAnalyzer();

  List<ProjectHealthIssue> analyze({
    required Set<String> paths,
    String? pubspecContent,
  }) {
    final normalized = paths.map((p) => p.replaceAll('\\', '/').toLowerCase()).toSet();
    final issues = <ProjectHealthIssue>[];
    final isFlutter = normalized.contains('pubspec.yaml') &&
        (pubspecContent == null ||
            RegExp(r'flutter\s*:\s*\n\s*sdk\s*:\s*flutter', caseSensitive: false)
                .hasMatch(pubspecContent));

    void missing(String path, String message) {
      if (!normalized.contains(path.toLowerCase())) {
        issues.add(ProjectHealthIssue(
          code: 'missing_${path.replaceAll('/', '_')}',
          path: path,
          message: message,
          repairable: true,
        ));
      }
    }

    if (isFlutter) {
      missing('lib/main.dart', 'ملف نقطة تشغيل Flutter غير موجود.');
      missing('android/settings.gradle', 'إعدادات Gradle الأساسية غير موجودة.');
      missing('android/build.gradle', 'ملف بناء Android العام غير موجود.');
      missing('android/app/build.gradle', 'إعدادات تطبيق Android غير موجودة.');
      missing('android/app/src/main/AndroidManifest.xml', 'ملف Android Manifest غير موجود.');
      missing('android/gradle/wrapper/gradle-wrapper.properties', 'إعدادات Gradle Wrapper غير موجودة.');
      final hasActivity = normalized.any((p) =>
          p.endsWith('/mainactivity.kt') || p.endsWith('/mainactivity.java'));
      if (!hasActivity) {
        issues.add(const ProjectHealthIssue(
          code: 'missing_main_activity',
          path: 'android/app/src/main/.../MainActivity',
          message: 'لم يتم العثور على MainActivity في شجرة Android.',
          repairable: true,
        ));
      }
      missing('android/gradle/wrapper/gradle-wrapper.jar', 'ملف Gradle Wrapper JAR غير موجود.');
      missing('android/gradlew', 'سكريبت Gradle Wrapper غير موجود.');
      missing('android/gradlew.bat', 'سكريبت Gradle Wrapper لويندوز غير موجود.');
      missing('android/app/src/main/res/values/styles.xml', 'ملفات أنماط شاشة Android غير موجودة.');
    } else if (normalized.contains('index.html')) {
      missing('style.css', 'ملف CSS الأساسي غير موجود (اختياري).');
    } else if (normalized.contains('pyproject.toml') || normalized.contains('requirements.txt')) {
      if (!normalized.contains('main.py') && !normalized.contains('app.py') && !normalized.contains('app/main.py')) {
        issues.add(const ProjectHealthIssue(
          code: 'missing_python_entry', path: 'main.py',
          message: 'لم يتم العثور على ملف تشغيل Python معروف.', repairable: true,
        ));
      }
    }
    return List.unmodifiable(issues);
  }
}
