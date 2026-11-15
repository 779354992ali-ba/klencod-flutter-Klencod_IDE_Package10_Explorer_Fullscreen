
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/project_input_validator.dart';
import '../../core/services/project_file_plan_validator.dart';
import '../../core/languages/language_identity.dart';

/// معلومات مجلد الحفظ الذي يختاره المستخدم عبر SAF.
class ProjectSaveLocation {
  final String uri;
  final String name;

  const ProjectSaveLocation({
    required this.uri,
    required this.name,
  });
}

/// معلومات المشروع بعد إنشائه.
class CreatedProjectInfo {
  final String name;
  final String rootUri;
  final String language;
  final String entryFile;
  final bool isFlutterSourceOnly;

  const CreatedProjectInfo({
    required this.name,
    required this.rootUri,
    required this.language,
    required this.entryFile,
    this.isFlutterSourceOnly = false,
  });
}

/// معالج إنشاء المشاريع.
class NewProjectWizard extends StatefulWidget {
  final Future<ProjectSaveLocation?> Function() pickLocation;

  final Future<String> Function(
    String parentUri,
    String directoryName,
  ) createDirectory;

  final Future<void> Function(
    String parentUri,
    String fileName,
    String mimeType,
    List<int> bytes,
  ) writeFile;

  final Future<void> Function(CreatedProjectInfo project) onCreated;
  final Future<void> Function(String rootUri)? deleteDirectoryTree;

  const NewProjectWizard({
    super.key,
    required this.pickLocation,
    required this.createDirectory,
    required this.writeFile,
    required this.onCreated,
    this.deleteDirectoryTree,
  });

  static Future<void> show(
    BuildContext context, {
    required Future<ProjectSaveLocation?> Function() pickLocation,
    required Future<String> Function(
      String parentUri,
      String directoryName,
    ) createDirectory,
    required Future<void> Function(
      String parentUri,
      String fileName,
      String mimeType,
      List<int> bytes,
    ) writeFile,
    required Future<void> Function(CreatedProjectInfo project) onCreated,
    Future<void> Function(String rootUri)? deleteDirectoryTree,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return NewProjectWizard(
          pickLocation: pickLocation,
          createDirectory: createDirectory,
          writeFile: writeFile,
          onCreated: onCreated,
          deleteDirectoryTree: deleteDirectoryTree,
        );
      },
    );
  }

  @override
  State<NewProjectWizard> createState() => _NewProjectWizardState();
}

class _NewProjectWizardState extends State<NewProjectWizard> {
  final PageController _pageController = PageController();

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _descriptionController =
      TextEditingController();

  final TextEditingController _packageController = TextEditingController();

  final TextEditingController _versionController =
      TextEditingController(text: '1.0.0');

  final TextEditingController _authorController = TextEditingController();

  final TextEditingController _entryController = TextEditingController();

  final TextEditingController _pythonVersionController =
      TextEditingController(text: '3.11');

  final TextEditingController _nodeVersionController =
      TextEditingController(text: '20');

  final TextEditingController _goModuleController = TextEditingController();

  final TextEditingController _rustEditionController =
      TextEditingController(text: '2021');

  final TextEditingController _sdkConstraintController =
      TextEditingController(text: '>=3.0.0 <4.0.0');

  int _currentStep = 0;

  bool _includeReadme = true;
  bool _includeGitignore = true;
  bool _isCreating = false;
  bool _isPickingLocation = false;

  String? _errorMessage;

  ProjectSaveLocation? _saveLocation;

  String _selectedLanguage = 'Flutter';
  String _projectMode = 'basic';
  String _selectedTemplate = 'basic';

  List<String> get _availableTemplates {
    switch (_selectedLanguage) {
      case 'Flutter': return const ['basic', 'multi_page', 'login', 'firebase', 'multilingual'];
      case 'HTML': case 'JavaScript': case 'TypeScript': case 'CSS':
        return const ['basic', 'multi_page', 'dashboard'];
      case 'Python': return const ['basic', 'cli', 'flask', 'fastapi'];
      case 'Java': case 'Kotlin': return const ['basic', 'multi_file', 'android'];
      default: return const ['basic', 'multi_file'];
    }
  }

  String _templateLabel(String value) {
    const labels = <String, String>{
      'basic': 'أساسي', 'multi_page': 'متعدد الصفحات', 'login': 'تسجيل دخول',
      'firebase': 'Firebase', 'multilingual': 'متعدد اللغات',
      'dashboard': 'لوحة تحكم', 'cli': 'سطر أوامر', 'flask': 'Flask',
      'fastapi': 'FastAPI', 'multi_file': 'متعدد الملفات', 'android': 'Android',
    };
    return labels[value] ?? value;
  }

  static const List<String> _languages = [
    'Flutter',
    'Dart',
    'Python',
    'JavaScript',
    'TypeScript',
    'Java',
    'Kotlin',
    'Swift',
    'C',
    'C++',
    'HTML',
    'CSS',
    'JSON',
    'SQL',
    'Bash',
    'Go',
    'Rust',
    'PHP',
    'C#',
    'Ruby',
    'XML',
    'YAML',
  ];

  String get _projectName => _nameController.text.trim();

  /// اسم صالح للاستخدام في أسماء الحزم والمجلدات البرمجية.
  ///
  /// نستخدم الشرطة السفلية بدل الشرطة العادية حتى يكون الاسم
  /// مناسبًا أيضًا لأسماء حزم Dart وFlutter.
  String get _safeProjectName =>
      ProjectInputValidator.safeProjectName(_projectName);

  bool get _isFlutter => _selectedLanguage == 'Flutter';

  /// مسار ملف البداية الحقيقي الذي سيتم إنشاؤه.
  ///
  /// Java يعتمد على اسم الحزمة، لذلك لا نستخدم المسار العام
  /// الموجود في حقل ملف البداية لتحديد موقع Main.java.
  String get _actualEntryFile {
    if (_selectedLanguage == 'Java' || _selectedLanguage == 'Kotlin') {
      final packagePath = _packageController.text.trim().replaceAll('.', '/');
      if (_selectedTemplate == 'android') {
        return 'app/src/main/java/$packagePath/MainActivity.${_selectedLanguage == 'Java' ? 'java' : 'kt'}';
      }
      if (_selectedLanguage == 'Java') return 'src/$packagePath/Main.java';
    }

    return _entryController.text.trim();
  }

  String get _defaultEntryFile {
    switch (_selectedLanguage) {
      case 'Flutter':
      case 'Dart':
        return 'lib/main.dart';
      case 'Python':
        return 'main.py';
      case 'JavaScript':
        return 'src/index.js';
      case 'TypeScript':
        return 'src/index.ts';
      case 'Java':
        return 'src/Main.java';
      case 'Kotlin':
        return 'src/Main.kt';
      case 'Swift':
        return 'Sources/main.swift';
      case 'C':
        return 'src/main.c';
      case 'C++':
        return 'src/main.cpp';
      case 'HTML':
        return 'index.html';
      case 'CSS':
        return 'styles.css';
      case 'JSON':
        return 'data.json';
      case 'SQL':
        return 'database.sql';
      case 'Bash':
        return 'scripts/main.sh';
      case 'Go':
        return 'main.go';
      case 'Rust':
        return 'src/main.rs';
      case 'PHP':
        return 'public/index.php';
      case 'C#':
        return 'src/Program.cs';
      case 'Ruby':
        return 'main.rb';
      case 'XML':
        return 'document.xml';
      case 'YAML':
        return 'config.yaml';
      default:
        return 'README.md';
    }
  }

  @override
  void initState() {
    super.initState();

    _entryController.text = _defaultEntryFile;
    _packageController.text = 'com.example.app';
  }

  @override
  void dispose() {
    _pageController.dispose();

    _nameController.dispose();
    _descriptionController.dispose();
    _packageController.dispose();
    _versionController.dispose();
    _authorController.dispose();
    _entryController.dispose();
    _pythonVersionController.dispose();
    _nodeVersionController.dispose();
    _goModuleController.dispose();
    _rustEditionController.dispose();
    _sdkConstraintController.dispose();

    super.dispose();
  }

  void _selectLanguage(String language) {
    setState(() {
      _selectedLanguage = language;
      _selectedTemplate = 'basic';
      _entryController.text = _defaultEntryFile;
      _errorMessage = null;

      if (language == 'Java' || language == 'Kotlin' || language == 'Flutter') {
        _packageController.text = 'com.example.$_safeProjectName';
      } else {
        _packageController.text = _safeProjectName;
      }

      if (language == 'Go') {
        _goModuleController.text =
            'example.com/$_safeProjectName';
      }
    });
  }

  bool _isValidProjectName(String name) =>
      ProjectInputValidator.isValidProjectName(name);

  bool _isValidRelativePath(String path) =>
      ProjectInputValidator.isValidRelativePath(path);

  bool _isValidPackageName(String value) =>
      ProjectInputValidator.isValidPackageName(value);

  bool _isValidVersion(String value) =>
      ProjectInputValidator.isValidVersion(value);

  bool _isValidSdkConstraint(String value) =>
      ProjectInputValidator.isValidSdkConstraint(value);

  bool _isValidGoModule(String value) =>
      ProjectInputValidator.isValidGoModule(value);

  bool _isValidPythonVersion(String value) =>
      ProjectInputValidator.isValidPythonVersion(value);

  bool _isValidNodeVersion(String value) =>
      ProjectInputValidator.isValidNodeVersion(value);

  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      _errorMessage = message;
    });
  }

  Future<void> _nextStep() async {
    if (_currentStep == 0) {
      if (!_isValidProjectName(_projectName)) {
        _showError('اسم المشروع غير صالح. أدخل اسمًا صحيحًا.');
        return;
      }
      if (_isFlutter && (_packageController.text.trim().isEmpty ||
          _packageController.text.trim() == 'com.example.app')) {
        _packageController.text = 'com.example.$_safeProjectName';
      }
    }

    if (_currentStep == 1) {
      _entryController.text = _defaultEntryFile;
    }

    if (_currentStep == 2) {
      // Java يستخدم مسارًا مشتقًا من اسم الحزمة.
      if (_selectedLanguage != 'Java') {
        final entry = _entryController.text.trim();

        if (!_isValidRelativePath(entry)) {
          _showError('مسار ملف البداية غير صالح.');
          return;
        }
      }

      if (!_isValidVersion(_versionController.text.trim())) {
        _showError('صيغة إصدار المشروع غير صحيحة. مثال: 1.0.0');
        return;
      }

      if (_isFlutter || _selectedLanguage == 'Dart') {
        if (!_isValidSdkConstraint(
          _sdkConstraintController.text.trim(),
        )) {
          _showError('قيد إصدار Dart SDK غير صالح.');
          return;
        }
      }

      if (_selectedLanguage == 'Python') {
        if (!_isValidPythonVersion(
          _pythonVersionController.text.trim(),
        )) {
          _showError('أدخل إصدار Python بالشكل 3.11.');
          return;
        }
      }

      if (_selectedLanguage == 'JavaScript' ||
          _selectedLanguage == 'TypeScript') {
        if (!_isValidNodeVersion(
          _nodeVersionController.text.trim(),
        )) {
          _showError('أدخل إصدار Node.js بالشكل 20.');
          return;
        }
      }

      if (_selectedLanguage == 'Java' || _isFlutter) {
        if (!_isValidPackageName(
          _packageController.text.trim(),
        )) {
          _showError(
            'اسم حزمة Java غير صالح. مثال: com.example.app',
          );
          return;
        }
      }

      if (_selectedLanguage == 'Go') {
        if (!_isValidGoModule(
          _goModuleController.text.trim(),
        )) {
          _showError('اسم Go module غير صالح.');
          return;
        }
      }

      if (_selectedLanguage == 'Rust') {
        if (!['2015', '2018', '2021', '2024'].contains(
          _rustEditionController.text.trim(),
        )) {
          _showError('إصدار Rust edition غير مدعوم.');
          return;
        }
      }

      if (_selectedLanguage == 'PHP') {
        final author = _authorController.text.trim();

        if (author.isNotEmpty &&
            !RegExp(r'^[a-z0-9_.-]+$').hasMatch(author)) {
          _showError('اسم ناشر PHP غير صالح.');
          return;
        }
      }
    }

    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
        _errorMessage = null;
      });

      await _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      await _chooseLocation();
    }
  }

  Future<void> _previousStep() async {
    if (_currentStep <= 0 || _isCreating || _isPickingLocation) {
      return;
    }

    setState(() {
      _currentStep--;
      _errorMessage = null;
    });

    await _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _chooseLocation() async {
    if (_isCreating || _isPickingLocation) return;

    setState(() {
      _isPickingLocation = true;
      _errorMessage = null;
    });

    try {
      final location = await widget.pickLocation();

      if (!mounted || location == null) return;

      setState(() {
        _saveLocation = location;
      });

      await _createProject();
    } catch (e) {
      _showError('تعذر اختيار مكان الحفظ: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPickingLocation = false;
        });
      }
    }
  }

  String _mimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower == 'gradlew') return 'text/x-shellscript';
    if (lower.endsWith('.jar')) return 'application/java-archive';
    if (lower.endsWith('.bat') || lower.endsWith('.properties')) return 'text/plain';

    if (lower.endsWith('.dart')) return 'text/x-dart';
    if (lower.endsWith('.py')) return 'text/x-python';
    if (lower.endsWith('.js')) return 'application/javascript';
    if (lower.endsWith('.ts')) return 'application/typescript';
    if (lower.endsWith('.html')) return 'text/html';
    if (lower.endsWith('.css')) return 'text/css';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.xml')) return 'application/xml';
    if (lower.endsWith('.sql')) return 'application/sql';
    if (lower.endsWith('.md')) return 'text/markdown';
    if (lower.endsWith('.sh')) return 'text/x-shellscript';
    if (lower.endsWith('.java')) return 'text/x-java';
    if (lower.endsWith('.kt')) return 'text/x-kotlin';
    if (lower.endsWith('.swift')) return 'text/x-swift';

    if (lower.endsWith('.c') || lower.endsWith('.h')) {
      return 'text/x-c';
    }

    if (lower.endsWith('.cpp') || lower.endsWith('.hpp')) {
      return 'text/x-c++';
    }

    if (lower.endsWith('.go')) return 'text/x-go';
    if (lower.endsWith('.rs')) return 'text/x-rust';
    if (lower.endsWith('.php')) return 'application/x-httpd-php';
    if (lower.endsWith('.cs')) return 'text/plain';
    if (lower.endsWith('.rb')) return 'text/x-ruby';
    if (lower.endsWith('.toml')) return 'application/toml';
    if (lower.endsWith('.yaml') || lower.endsWith('.yml')) {
      return 'application/yaml';
    }

    if (lower.endsWith('.gitignore')) return 'text/plain';

    return 'text/plain';
  }

  Future<void> _writeRelativeBytes(
    String rootUri,
    String relativePath,
    List<int> bytes,
  ) async {
    if (!_isValidRelativePath(relativePath)) {
      throw Exception('مسار ملف غير آمن: $relativePath');
    }
    final segments = relativePath.split('/');
    var currentUri = rootUri;
    for (var i = 0; i < segments.length - 1; i++) {
      currentUri = await widget.createDirectory(currentUri, segments[i]);
    }
    await widget.writeFile(
      currentUri,
      segments.last,
      _mimeType(segments.last),
      bytes,
    );
  }

  Future<void> _writeRelativeFile(
    String rootUri,
    String relativePath,
    String content,
  ) async {
    if (!_isValidRelativePath(relativePath)) {
      throw Exception('مسار ملف غير آمن: $relativePath');
    }

    final segments = relativePath.split('/');

    var currentUri = rootUri;

    for (var i = 0; i < segments.length - 1; i++) {
      currentUri = await widget.createDirectory(
        currentUri,
        segments[i],
      );
    }

    final fileName = segments.last;

    await widget.writeFile(
      currentUri,
      fileName,
      _mimeType(fileName),
      utf8.encode(content),
    );
  }

  Future<void> _createProject() async {
    final location = _saveLocation;
    String? createdRootUri;
    var projectFilesCommitted = false;

    if (location == null || _isCreating) return;

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final files = _generateProjectFiles();

      // تتم إضافة README من هنا فقط حتى نحترم اختيار المستخدم
      // لجميع اللغات، بما فيها Java.
      if (_includeReadme) {
        files['README.md'] = _generateReadme();
      }

      if (_includeGitignore) {
        files['.gitignore'] = _generateGitignore();
      }

      // تحقق من شجرة الملفات كاملة قبل إنشاء أي مجلد عبر SAF؛
      // يمنع المسارات المتعارضة أو ملف بداية غير موجود من ترك مشروع جزئي.
      ProjectFilePlanValidator.validate(
        files: files,
        entryFile: _actualEntryFile,
      );

      final rootUri = await widget.createDirectory(
        location.uri,
        _safeProjectName,
      );
      createdRootUri = rootUri;

      for (final entry in files.entries) {
        await _writeRelativeFile(rootUri, entry.key, entry.value);
      }

      final needsAndroidWrapper = _isFlutter ||
          ((_selectedLanguage == 'Java' || _selectedLanguage == 'Kotlin') &&
              _selectedTemplate == 'android');
      if (needsAndroidWrapper) {
        final wrapperAssets = _isFlutter
            ? <String, String>{
                'assets/templates/android/gradle/wrapper/gradle-wrapper.jar': 'android/gradle/wrapper/gradle-wrapper.jar',
                'assets/templates/android/gradlew': 'android/gradlew',
                'assets/templates/android/gradlew.bat': 'android/gradlew.bat',
              }
            : <String, String>{
                'assets/templates/android/gradle/wrapper/gradle-wrapper.jar': 'gradle/wrapper/gradle-wrapper.jar',
                'assets/templates/android/gradlew': 'gradlew',
                'assets/templates/android/gradlew.bat': 'gradlew.bat',
              };
        for (final asset in wrapperAssets.entries) {
          final data = await rootBundle.load(asset.key);
          await _writeRelativeBytes(
            rootUri,
            asset.value,
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
        }
      }

      projectFilesCommitted = true;

      final project = CreatedProjectInfo(
        name: _projectName,
        rootUri: rootUri,
        language: _selectedLanguage,
        entryFile: _actualEntryFile,
        isFlutterSourceOnly: _isFlutter,
      );

      await widget.onCreated(project);

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      var recoveryMessage =
          'قد يكون قد تم إنشاء بعض الملفات قبل حدوث الخطأ.';
      if (createdRootUri != null && !projectFilesCommitted) {
        final cleanup = widget.deleteDirectoryTree;
        if (cleanup != null) {
          try {
            await cleanup(createdRootUri);
            recoveryMessage = 'تم حذف مجلد المشروع الجزئي بعد فشل الإنشاء.';
          } catch (cleanupError) {
            recoveryMessage = 'تعذر حذف المجلد الجزئي تلقائيًا: $cleanupError';
          }
        }
      }
      _showError('فشل إنشاء المشروع: $e\n$recoveryMessage');
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Map<String, String> _generateFlutterAndroidFiles() {
    final appId = _packageController.text.trim();
    final namespacePath = appId.replaceAll('.', '/');
    return {
      'android/settings.gradle': '''
pluginManagement {
    def flutterSdkPath = {
        def properties = new Properties()
        file("local.properties").withInputStream { properties.load(it) }
        def flutterSdkPath = properties.getProperty("flutter.sdk")
        assert flutterSdkPath != null, "flutter.sdk not set in local.properties"
        return flutterSdkPath
    }()
    includeBuild("\${flutterSdkPath}/packages/flutter_tools/gradle")
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.11.1" apply false
    id "org.jetbrains.kotlin.android" version "2.2.20" apply false
}
include ":app"
''',
      'android/build.gradle': '''
allprojects { repositories { google(); mavenCentral() } }
rootProject.buildDir = "../build"
subprojects { project.buildDir = "\${rootProject.buildDir}/\${project.name}" }
subprojects { project.evaluationDependsOn(":app") }
tasks.register("clean", Delete) { delete rootProject.buildDir }
''',
      'android/gradle.properties': '''
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
android.enableJetifier=true
''',
      'android/gradle/wrapper/gradle-wrapper.properties': '''
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\\://services.gradle.org/distributions/gradle-8.14-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
''',
      'android/app/build.gradle': '''
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}
android {
    namespace = "$appId"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    defaultConfig {
        applicationId = "$appId"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    buildTypes { release { signingConfig = signingConfigs.debug } }
}
flutter { source = "../.." }
''',
      'android/app/src/main/AndroidManifest.xml': '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application android:label="${_xmlEscape(_projectName)}" android:name="${r'${applicationName}'}">
        <activity android:name=".MainActivity" android:exported="true"
            android:launchMode="singleTop" android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true" android:windowSoftInputMode="adjustResize">
            <meta-data android:name="io.flutter.embedding.android.NormalTheme" android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        <meta-data android:name="flutterEmbedding" android:value="2" />
    </application>
</manifest>
''',
      'android/app/src/main/kotlin/$namespacePath/MainActivity.kt': '''
package $appId

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
''',
      'android/app/src/main/res/values/styles.xml': '''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
''',
    };
  }

  String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  Map<String, String> _generateProjectFiles() {
    final files = <String, String>{};

    final entry = _selectedLanguage == 'Java'
        ? _actualEntryFile
        : _entryController.text.trim();

    final version = _versionController.text.trim();
    final description = _descriptionController.text.trim();

    final jsonDescription = jsonEncode(description);
    final jsonProjectName = jsonEncode(_projectName);

    switch (_selectedLanguage) {
      case 'Flutter':
        files['pubspec.yaml'] = '''
name: $_safeProjectName
description: ${_yamlString(description.isEmpty ? 'A Flutter application.' : description)}
publish_to: 'none'
version: $version+1

environment:
  sdk: '${_sdkConstraintController.text.trim()}'

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
''';

        files[entry] = '''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: $jsonProjectName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text($jsonProjectName),
      ),
      body: const Center(
        child: Text(
          'Welcome to your new Flutter project!',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
''';
        // Android platform files are generated locally from a bundled template.
        files['.github/workflows/build-android.yml'] = r'''name: Build Android APK

on:
  workflow_dispatch:
    inputs:
      flutter_version:
        description: Flutter SDK version
        required: true
        default: '3.47.2'
        type: string

permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Setup Java 17
        uses: actions/setup-java@v5
        with:
          distribution: temurin
          java-version: '17'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: ${{ inputs.flutter_version || '3.47.2' }}
          cache: true

      - name: Cache Pub packages
        uses: actions/cache@v5
        with:
          path: ~/.pub-cache
          key: ${{ runner.os }}-pub-${{ hashFiles('pubspec.yaml') }}
          restore-keys: |
            ${{ runner.os }}-pub-

      - name: Cache Gradle
        uses: actions/cache@v5
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: ${{ runner.os }}-gradle-${{ hashFiles('android/**/*.gradle*', 'android/gradle/wrapper/gradle-wrapper.properties') }}
          restore-keys: |
            ${{ runner.os }}-gradle-

      - name: Verify local Android platform
        run: test -f android/app/src/main/AndroidManifest.xml && test -f android/settings.gradle

      - name: Ensure Internet permission
        run: |
          python3 - <<'PYTHON'
          from pathlib import Path
          manifest = Path('android/app/src/main/AndroidManifest.xml')
          text = manifest.read_text()
          permission = '<uses-permission android:name="android.permission.INTERNET" />'
          if permission not in text:
              text = text.replace('<application', permission + '\n    <application', 1)
          manifest.write_text(text)
          PYTHON

      - name: Get dependencies
        run: flutter pub get

      - name: Analyze
        run: flutter analyze

      - name: Test
        run: flutter test

      - name: Build release APK
        run: flutter build apk --release

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: ${{ github.event.repository.name }}-apk
          path: build/app/outputs/flutter-apk/app-release.apk
          if-no-files-found: error
          retention-days: 14
''';
        files.addAll(_generateFlutterAndroidFiles());
        files['.metadata'] = '''
version:
  revision: ''
  channel: stable
project_type: app
''';
        break;

      case 'Dart':
        files['pubspec.yaml'] = '''
name: $_safeProjectName
description: ${_yamlString(description)}
version: $version

environment:
  sdk: '${_sdkConstraintController.text.trim()}'
''';

        files[entry] = '''
void main() {
  print('Hello from ${_dartString(_projectName)}!');
}
''';
        break;

      case 'Python':
        files['pyproject.toml'] = '''
[project]
name = "$_safeProjectName"
version = "$version"
description = ${_tomlString(description)}
requires-python = ">=${_pythonVersionController.text.trim()}"
''';

        files[entry] = '''
def main():
    print("Hello from ${_pythonString(_projectName)}!")


if __name__ == "__main__":
    main()
''';
        break;

      case 'JavaScript':
        files['package.json'] = '''
{
  "name": ${jsonEncode(_safeProjectName)},
  "version": ${jsonEncode(version)},
  "description": $jsonDescription,
  "main": ${jsonEncode(entry)},
  "scripts": {
    "start": "node ${_jsonSafeCommand(entry)}"
  },
  "engines": {
    "node": ">=${_nodeVersionController.text.trim()}"
  }
}
''';

        files[entry] = '''
console.log("Hello from ${_jsString(_projectName)}!");
''';
        break;

      case 'TypeScript':
        files['package.json'] = '''
{
  "name": ${jsonEncode(_safeProjectName)},
  "version": ${jsonEncode(version)},
  "description": $jsonDescription,
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/node": "^20.0.0"
  }
}
''';

        files['tsconfig.json'] = '''
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "CommonJS",
    "rootDir": "src",
    "outDir": "dist",
    "strict": true,
    "esModuleInterop": true
  }
}
''';

        files[entry] = '''
function main(): void {
  console.log("Hello from ${_jsString(_projectName)}!");
}

main();
''';
        break;

      case 'Java':
        final packageName = _packageController.text.trim();

        files[entry] = '''
package $packageName;

public class Main {
    public static void main(String[] args) {
        System.out.println("Hello from ${_javaString(_projectName)}!");
    }
}
''';
        break;

      case 'Kotlin':
        files[entry] = '''
fun main() {
    println("Hello from ${_kotlinString(_projectName)}!")
}
''';
        break;

      case 'Swift':
        files[entry] = '''
import Foundation

print("Hello from ${_swiftString(_projectName)}!")
''';
        break;

      case 'C':
        files[entry] = '''
#include <stdio.h>

int main(void) {
    printf("Hello from ${_cString(_projectName)}!\\n");
    return 0;
}
''';
        break;

      case 'C++':
        files[entry] = '''
#include <iostream>

int main() {
    std::cout << "Hello from ${_cppString(_projectName)}!" << std::endl;
    return 0;
}
''';
        break;

      case 'HTML':
        files[entry] = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${_htmlEscape(_projectName)}</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <main>
        <h1>Welcome to ${_htmlEscape(_projectName)}</h1>
        <p>Your new HTML project is ready.</p>
    </main>
    <script src="script.js"></script>
</body>
</html>
''';

        files['style.css'] = '''
body {
    font-family: Arial, sans-serif;
    margin: 0;
    padding: 40px;
    background: #f5f5f5;
    color: #222;
}

main {
    max-width: 700px;
    margin: auto;
}
''';

        files['script.js'] = '''
console.log("${_jsString(_projectName)} is ready!");
''';
        break;

      case 'CSS':
        files[entry] = '''
:root {
    font-family: Arial, sans-serif;
    color: #222;
    background: #f5f5f5;
}

body {
    margin: 0;
    padding: 24px;
}

.container {
    max-width: 900px;
    margin: auto;
}
''';
        break;

      case 'JSON':
        files[entry] = '''
{
  "name": ${jsonEncode(_safeProjectName)},
  "version": ${jsonEncode(version)},
  "description": $jsonDescription,
  "created": true
}
''';
        break;

      case 'SQL':
        files[entry] = '''
-- ${_sqlComment(_projectName)} database

CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE
);

-- Add your SQL queries below.
''';
        break;

      case 'Bash':
        files[entry] = '''
#!/usr/bin/env bash

set -e

echo '${_shellString('Hello from $_projectName!')}'
''';
        break;

      case 'Go':
        final module = _goModuleController.text.trim();

        files['go.mod'] = '''
module $module

go 1.23
''';

        files[entry] = '''
package main

import "fmt"

func main() {
    fmt.Println("${_goString('Hello from $_projectName!')}")
}
''';
        break;

      case 'Rust':
        files['Cargo.toml'] = '''
[package]
name = "$_safeProjectName"
version = "$version"
edition = "${_rustEditionController.text.trim()}"

[dependencies]
''';

        files[entry] = '''
fn main() {
    println!("Hello from ${_rustString(_projectName)}!");
}
''';
        break;

      case 'PHP':
        final author = _authorController.text.trim().isEmpty
            ? 'app'
            : _authorController.text.trim().toLowerCase();

        files['composer.json'] = '''
{
    "name": ${jsonEncode('$author/$_safeProjectName')},
    "description": $jsonDescription,
    "type": "project",
    "require": {
        "php": ">=8.1"
    }
}
''';

        files[entry] = '''
<?php

echo "${_phpString('Hello from $_projectName!')}";

''';
        break;

      case 'C#':
        files['$_safeProjectName.csproj'] = '''
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
</Project>
''';
        files[entry] = '''
Console.WriteLine("${_jsString('Hello from $_projectName!')}");
''';
        break;

      case 'Ruby':
        files['Gemfile'] = '''
source 'https://rubygems.org'

# Add project dependencies here.
''';
        files[entry] = '''
puts ${jsonEncode('Hello from $_projectName!')}
''';
        break;

      case 'XML':
        files[entry] = '''
<?xml version="1.0" encoding="UTF-8"?>
<project name="${_htmlEscape(_projectName)}">
  <description>${_htmlEscape(description)}</description>
</project>
''';
        break;

      case 'YAML':
        files[entry] = '''
name: ${jsonEncode(_safeProjectName)}
version: ${jsonEncode(version)}
description: ${jsonEncode(description)}
''';
        break;
    }

    _appendTemplateFiles(files);
    if (_projectMode == 'integrated') {
      files.putIfAbsent('.vscode/settings.json', () => '''{\n  \"files.trimTrailingWhitespace\": true,\n  \"editor.insertSpaces\": true,\n  \"editor.tabSize\": 2\n}\n''');
      files.putIfAbsent('docs/PROJECT_OVERVIEW.md', () => '# $_projectName\n\nProject overview and development notes.\n');
      files.putIfAbsent('.editorconfig', () => 'root = true\n\n[*]\ncharset = utf-8\nend_of_line = lf\ninsert_final_newline = true\n');
    }
    return files;
  }

  void _appendTemplateFiles(Map<String, String> files) {
    final entry = _actualEntryFile.isEmpty ? _defaultEntryFile : _actualEntryFile;
    final version = _versionController.text.trim().isEmpty
        ? '1.0.0'
        : _versionController.text.trim();
    switch (_selectedLanguage) {
      case 'Flutter':
        if (_selectedTemplate == 'multi_page') {
          files['lib/main.dart'] = '''import 'package:flutter/material.dart';\nimport 'screens/home_screen.dart';\nimport 'screens/settings_screen.dart';\n\nvoid main() => runApp(const ProjectApp());\nclass ProjectApp extends StatelessWidget {\n  const ProjectApp({super.key});\n  @override Widget build(BuildContext context) => MaterialApp(\n    title: '$_projectName', initialRoute: '/', routes: {\n      '/': (_) => const HomeScreen(), '/settings': (_) => const SettingsScreen(),\n    },\n  );\n}\n''';
          files['lib/screens/home_screen.dart'] = '''import 'package:flutter/material.dart';\n\nclass HomeScreen extends StatelessWidget {\n  const HomeScreen({super.key});\n  @override\n  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Home')), body: const Center(child: Text('Home screen')));\n}\n''';
          files['lib/screens/settings_screen.dart'] = '''import 'package:flutter/material.dart';\n\nclass SettingsScreen extends StatelessWidget {\n  const SettingsScreen({super.key});\n  @override\n  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings')), body: const Center(child: Text('Settings screen')));\n}\n''';
          files['lib/routes/app_routes.dart'] = '''class AppRoutes {\n  static const home = '/';\n  static const settings = '/settings';\n}\n''';
        } else if (_selectedTemplate == 'login') {
          files['lib/main.dart'] = '''import 'package:flutter/material.dart';\nimport 'screens/login_screen.dart';\nvoid main() => runApp(const MaterialApp(home: LoginScreen()));\n''';
          files['lib/screens/login_screen.dart'] = '''import 'package:flutter/material.dart';\n\nclass LoginScreen extends StatelessWidget {\n  const LoginScreen({super.key});\n  @override\n  Widget build(BuildContext context) => Scaffold(body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: const Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Welcome back'), TextField(decoration: InputDecoration(labelText: 'Email')), TextField(obscureText: true, decoration: InputDecoration(labelText: 'Password')), SizedBox(height: 16), FilledButton(onPressed: null, child: Text('Sign in'))])))));\n}\n''';
          files['lib/services/auth_service.dart'] = '''abstract interface class AuthService {\n  Future<bool> signIn(String email, String password);\n}\n''';
        } else if (_selectedTemplate == 'firebase') {
          files['lib/firebase_options.dart'] = '''// Replace this placeholder with generated Firebase options from FlutterFire CLI.\nclass DefaultFirebaseOptions {\n  static const configured = false;\n}\n''';
          files['FIREBASE_SETUP.md'] = 'Run `flutterfire configure`, add Firebase packages, then initialize Firebase in main.dart.\n';
        } else if (_selectedTemplate == 'multilingual') {
          files['pubspec.yaml'] = files['pubspec.yaml']!.replaceFirst(
            '  uses-material-design: true',
            '  uses-material-design: true\n  generate: true',
          );
          files['lib/l10n/app_en.arb'] = jsonEncode({'@@locale': 'en', 'appTitle': _projectName});
          files['lib/l10n/app_ar.arb'] = jsonEncode({'@@locale': 'ar', 'appTitle': _projectName});
          files['l10n.yaml'] = 'arb-dir: lib/l10n\ntemplate-arb-file: app_en.arb\noutput-localization-file: app_localizations.dart\n';
        }
        break;
      case 'HTML': case 'JavaScript': case 'TypeScript': case 'CSS':
        if (_selectedTemplate == 'multi_page') {
          if (_selectedLanguage == 'HTML') {
            files[entry] = '''<!doctype html>\n<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>$_projectName</title><link rel="stylesheet" href="style.css"></head><body><nav><a href="index.html">Home</a> <a href="pages/about.html">About</a> <a href="pages/contact.html">Contact</a></nav><main><h1>$_projectName</h1><p>Multi-page starter project.</p></main><script src="script.js"></script></body></html>\n''';
          }
          files['pages/about.html'] = '<!doctype html>\n<html lang="en"><meta charset="utf-8"><title>About</title><body><main><h1>About</h1><p>About this project.</p></main></body></html>\n';
          files['pages/contact.html'] = '<!doctype html>\n<html lang="en"><meta charset="utf-8"><title>Contact</title><body><main><h1>Contact</h1><p>Contact information.</p></main></body></html>\n';
          files['assets/css/pages.css'] = 'main { max-width: 960px; margin: 2rem auto; padding: 1rem; }\n';
        } else if (_selectedTemplate == 'dashboard') {
          if (_selectedLanguage == 'HTML') {
            files[entry] = '''<!doctype html>\n<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>$_projectName Dashboard</title><link rel="stylesheet" href="assets/css/dashboard.css"></head><body><main id="dashboard" class="dashboard-grid"></main><script src="src/dashboard.js"></script></body></html>\n''';
            files['src/dashboard.js'] = 'document.getElementById("dashboard").innerHTML = "<section><h1>Dashboard</h1><p>Welcome to your workspace.</p></section>";\n';
          } else {
            files['src/dashboard.js'] = 'export function renderDashboard(root) {\n  root.innerHTML = \"<section><h1>Dashboard</h1><p>Welcome to your workspace.</p></section>\";\n}\n';
          }
          files['assets/css/dashboard.css'] = '.dashboard-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 1rem; }\n';
        }
        break;
      case 'Python':
        if (_selectedTemplate == 'cli') {
          files[entry] = '''from src.commands import build_parser\n\ndef main():\n    args = build_parser().parse_args()\n    if args.version:\n        print("$_projectName 1.0.0")\n    else:\n        print("Hello from $_projectName!")\n\nif __name__ == "__main__":\n    main()\n''';
          files['src/commands.py'] = 'import argparse\n\ndef build_parser():\n    parser = argparse.ArgumentParser(description=${jsonEncode(_projectName)})\n    parser.add_argument("--version", action="store_true")\n    return parser\n';
          files['tests/test_commands.py'] = 'from src.commands import build_parser\n\ndef test_parser_accepts_version():\n    assert build_parser().parse_args(["--version"]).version is True\n';
        } else if (_selectedTemplate == 'flask') {
          files[entry] = 'from app import app\n\nif __name__ == "__main__":\n    app.run(debug=True)\n';
          files['requirements.txt'] = 'Flask>=3.0,<4.0\n';
          files['app.py'] = 'from flask import Flask, jsonify\n\napp = Flask(__name__)\n\n@app.get("/")\ndef index():\n    return jsonify(message="Hello from $_projectName")\n\nif __name__ == "__main__":\n    app.run(debug=True)\n';
        } else if (_selectedTemplate == 'fastapi') {
          files[entry] = 'import uvicorn\nfrom app.main import app\n\nif __name__ == "__main__":\n    uvicorn.run(app, host="127.0.0.1", port=8000)\n';
          files['requirements.txt'] = 'fastapi>=0.110,<1.0\nuvicorn[standard]>=0.27,<1.0\n';
          files['app/main.py'] = 'from fastapi import FastAPI\n\napp = FastAPI(title=${jsonEncode(_projectName)})\n\n@app.get("/")\ndef read_root():\n    return {"message": "Hello from $_projectName"}\n';
        }
        break;
      case 'Java': case 'Kotlin':
        if (_selectedTemplate == 'multi_file') {
          final isJava = _selectedLanguage == 'Java';
          final packageName = _packageController.text.trim();
          final sourcePrefix = isJava ? 'src/${packageName.replaceAll('.', '/')}/' : 'src/';
          files['${sourcePrefix}AppConfig.${isJava ? 'java' : 'kt'}'] = isJava
              ? 'package $packageName;\n\npublic final class AppConfig {\n    public static final String APP_NAME = "${_javaString(_projectName)}";\n    private AppConfig() {}\n}\n'
              : 'object AppConfig {\n    const val APP_NAME = "${_kotlinString(_projectName)}"\n}\n';
          files['${sourcePrefix}GreetingService.${isJava ? 'java' : 'kt'}'] = isJava
              ? 'package $packageName;\n\npublic class GreetingService {\n    public String greeting() { return "Hello from ${_javaString(_projectName)}!"; }\n}\n'
              : 'class GreetingService {\n    fun greeting() = "Hello from ${_kotlinString(_projectName)}!"\n}\n';
        } else if (_selectedTemplate == 'android') {
          final isJava = _selectedLanguage == 'Java';
          final appId = _packageController.text.trim();
          final packagePath = appId.replaceAll('.', '/');
          files['settings.gradle'] = '''pluginManagement {\n    repositories { google(); mavenCentral(); gradlePluginPortal() }\n}\ndependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }\nrootProject.name = "$_safeProjectName"\ninclude ':app'\n''';
          files['build.gradle'] = '''plugins {\n    id 'com.android.application' version '8.7.3' apply false\n}\n''';
          files['gradle.properties'] = 'org.gradle.jvmargs=-Xmx2G\nandroid.useAndroidX=true\n';
          files['gradle/wrapper/gradle-wrapper.properties'] = 'distributionBase=GRADLE_USER_HOME\ndistributionPath=wrapper/dists\ndistributionUrl=https\\://services.gradle.org/distributions/gradle-8.9-bin.zip\nzipStoreBase=GRADLE_USER_HOME\nzipStorePath=wrapper/dists\n';
          files['app/build.gradle'] = '''plugins { id 'com.android.application' }\n\nandroid {\n    namespace '$appId'\n    compileSdk 35\n    defaultConfig { applicationId '$appId'; minSdk 23; targetSdk 35; versionCode 1; versionName '$version' }\n}\n''';
          files['app/src/main/AndroidManifest.xml'] = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="${_xmlEscape(_projectName)}" android:theme="@android:style/Theme.Material.Light.NoActionBar"><activity android:name=".MainActivity" android:exported="true"><intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter></activity></application></manifest>\n''';
          files['app/src/main/java/$packagePath/MainActivity.${isJava ? 'java' : 'kt'}'] = isJava
              ? '''package $appId;\n\nimport android.app.Activity;\nimport android.os.Bundle;\nimport android.widget.TextView;\n\npublic class MainActivity extends Activity {\n    @Override public void onCreate(Bundle state) {\n        super.onCreate(state);\n        TextView view = new TextView(this);\n        view.setText("Welcome to ${_javaString(_projectName)}");\n        view.setTextSize(22);\n        setContentView(view);\n    }\n}\n'''
              : '''package $appId\n\nimport android.app.Activity\nimport android.os.Bundle\nimport android.widget.TextView\n\nclass MainActivity : Activity() {\n    override fun onCreate(state: Bundle?) {\n        super.onCreate(state)\n        val view = TextView(this).apply { text = "Welcome to ${_kotlinString(_projectName)}"; textSize = 22f }\n        setContentView(view)\n    }\n}\n''';
          files['README_ANDROID.md'] = 'Native Android starter generated with Gradle and a real Activity entry point. Open the project root in Android Studio or build with a compatible Android SDK.\n';
        }
        break;
    }
  }

  String _yamlString(String value) {
    return jsonEncode(value);
  }

  String _tomlString(String value) {
    return jsonEncode(value);
  }

  String _dartString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  String _jsString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\$', r'\$');
  }

  String _pythonString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  String _javaString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  String _kotlinString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\$', r'\$');
  }

  String _swiftString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  String _cString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  String _cppString(String value) {
    return _cString(value);
  }

  String _goString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  String _rustString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  String _phpString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\$', r'\$');
  }

  String _shellString(String value) {
    return value.replaceAll("'", "'\\''");
  }

  String _sqlComment(String value) {
    return value
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');
  }

  String _htmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _jsonSafeCommand(String value) {
    return value.replaceAll('"', r'\"');
  }

  String _generateReadme() {
    final description = _descriptionController.text.trim();

    final packageInfo = _selectedLanguage == 'Java'
        ? '\n- Java package: `${_packageController.text.trim()}`\n'
        : '';

    return '''
# $_projectName

${description.isEmpty ? 'A new $_selectedLanguage project.' : description}

## Project information

- Language: $_selectedLanguage
- Version: ${_versionController.text.trim()}
- Entry file: $_actualEntryFile
$packageInfo
${_isFlutter ? '''
## Flutter note

This project includes its Flutter source and a locally generated Android platform
with Gradle wrapper files. The GitHub Actions workflow at
`.github/workflows/build-android.yml` verifies the Android files, analyzes, tests,
and builds a release APK.
''' : ''}

## Getting started

Open the project files in your preferred development environment.
''';
  }

  String _generateGitignore() {
    switch (_selectedLanguage) {
      case 'Flutter':
        return '''
.dart_tool/
.packages
.pub-cache/
.pub/
build/
.flutter-plugins
.flutter-plugins-dependencies
android/.gradle/
android/local.properties
''';
      case 'Dart':
        return '''
.dart_tool/
.packages
.pub-cache/
.pub/
build/
.flutter-plugins
.flutter-plugins-dependencies
''';

      case 'Python':
        return '''
__pycache__/
*.py[cod]
.venv/
venv/
.env
dist/
build/
''';

      case 'JavaScript':
      case 'TypeScript':
        return '''
node_modules/
dist/
.env
npm-debug.log*
''';

      case 'Java':
        return '''
*.class
build/
target/
.gradle/
.idea/
''';

      case 'Kotlin':
        return '''
*.class
build/
.gradle/
.idea/
''';

      case 'Go':
        return '''
/bin/
/vendor/
*.exe
*.test
''';

      case 'Rust':
        return '''
/target/
''';

      case 'PHP':
        return '''
/vendor/
/.env
''';
      case 'C#':
        return '''
bin/
obj/
.vs/
*.user
''';
      case 'Ruby':
        return '''
.bundle/
vendor/bundle/
*.gem
.env
''';

      default:
        return '''
.DS_Store
Thumbs.db
.env
''';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Icon(
                  Icons.create_new_folder_outlined,
                  color: colors.primary,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'إنشاء مشروع جديد',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isCreating || _isPickingLocation
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          _buildProgress(colors),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: colors.onErrorContainer,
                  ),
                ),
              ),
            ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildNameStep(),
                _buildLanguageStep(),
                _buildSettingsStep(),
                _buildSummaryStep(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildProgress(ColorScheme colors) {
    const labels = [
      'الاسم',
      'اللغة',
      'الإعدادات',
      'الحفظ',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = index <= _currentStep;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 4,
                    decoration: BoxDecoration(
                      color: active
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 11,
                      color: active
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNameStep() {
    return _stepContent(
      title: 'ما اسم مشروعك؟',
      subtitle: 'أدخل اسمًا واضحًا للمشروع.',
      children: [
        _field(
          controller: _nameController,
          label: 'اسم المشروع',
          hint: 'My Awesome Project',
          icon: Icons.drive_file_rename_outline,
        ),
        const SizedBox(height: 14),
        _field(
          controller: _descriptionController,
          label: 'وصف المشروع (اختياري)',
          hint: 'اكتب وصفًا مختصرًا',
          icon: Icons.description_outlined,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildLanguageStep() {
    return _stepContent(
      title: 'اختر لغة المشروع',
      subtitle: 'ستظهر إعدادات خاصة باللغة التي تختارها.',
      children: [
        ..._languages.map((language) {
          final selected = language == _selectedLanguage;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: _isCreating || _isPickingLocation
                  ? null
                  : () => _selectLanguage(language),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    LanguageBrandBadge(language: language, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        language,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  IconData _languageIcon(String language) {
    switch (language) {
      case 'Flutter':
        return Icons.phone_android;
      case 'Dart':
        return Icons.code;
      case 'Python':
        return Icons.terminal;
      case 'JavaScript':
      case 'TypeScript':
        return Icons.javascript;
      case 'Java':
      case 'Kotlin':
        return Icons.android;
      case 'Swift':
        return Icons.apple;
      case 'HTML':
      case 'CSS':
        return Icons.web;
      case 'SQL':
      case 'JSON':
        return Icons.data_object;
      default:
        return Icons.code;
    }
  }

  Widget _buildSettingsStep() {
    return _stepContent(
      title: 'إعدادات $_selectedLanguage',
      subtitle: 'هذه القيم ستُستخدم عند إنشاء ملفات المشروع.',
      children: [
        Row(children: [
          LanguageBrandBadge(language: _selectedLanguage, size: 48),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_selectedLanguage,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(LanguageIdentity.of(_selectedLanguage).family,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
          )),
        ]),
        const SizedBox(height: 14),
        Text('نوع المشروع', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'basic', label: Text('أساسي'), icon: Icon(Icons.bolt_outlined)),
            ButtonSegment(value: 'integrated', label: Text('متكامل'), icon: Icon(Icons.layers_outlined)),
          ],
          selected: {_projectMode},
          onSelectionChanged: (values) => setState(() => _projectMode = values.first),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _selectedTemplate,
          decoration: const InputDecoration(labelText: 'قالب المشروع', border: OutlineInputBorder()),
          items: _availableTemplates.map((value) => DropdownMenuItem(value: value, child: Text(_templateLabel(value)))).toList(),
          onChanged: (value) => setState(() {
            _selectedTemplate = value ?? 'basic';
            if (_selectedLanguage == 'Kotlin') {
              _entryController.text = _selectedTemplate == 'android'
                  ? _actualEntryFile : _defaultEntryFile;
            }
          }),
        ),
        const SizedBox(height: 14),
        if (_selectedLanguage == 'Java')
          _infoCard(
            'سيتم إنشاء ملف البداية تلقائيًا وفق اسم الحزمة:\n'
            '$_actualEntryFile',
          )
        else
          _field(
            controller: _entryController,
            label: 'ملف البداية',
            hint: _defaultEntryFile,
            icon: Icons.insert_drive_file_outlined,
          ),
        const SizedBox(height: 14),
        _field(
          controller: _versionController,
          label: 'إصدار المشروع',
          hint: '1.0.0',
          icon: Icons.tag,
        ),
        if (_selectedLanguage == 'Flutter' ||
            _selectedLanguage == 'Dart') ...[
          const SizedBox(height: 14),
          _field(
            controller: _sdkConstraintController,
            label: 'قيد إصدار Dart SDK',
            hint: '>=3.0.0 <4.0.0',
            icon: Icons.settings_ethernet,
          ),
        ],
        if (_selectedLanguage == 'Flutter') ...[
          const SizedBox(height: 14),
          _field(
            controller: _packageController,
            label: 'معرّف تطبيق Android (Application ID)',
            hint: 'com.example.my_app',
            icon: Icons.android,
          ),
          _infoCard(
            'سيتم إنشاء مجلد android وملفات Gradle وMainActivity وGradle Wrapper محليًا تلقائيًا عند إنشاء المشروع.',
          ),
        ],
        if (_selectedLanguage == 'Python') ...[
          const SizedBox(height: 14),
          _field(
            controller: _pythonVersionController,
            label: 'أقل إصدار Python مطلوب',
            hint: '3.11',
            icon: Icons.terminal,
          ),
        ],
        if (_selectedLanguage == 'JavaScript' ||
            _selectedLanguage == 'TypeScript') ...[
          const SizedBox(height: 14),
          _field(
            controller: _nodeVersionController,
            label: 'أقل إصدار Node.js مطلوب',
            hint: '20',
            icon: Icons.memory,
          ),
        ],
        if (_selectedLanguage == 'Go') ...[
          const SizedBox(height: 14),
          _field(
            controller: _goModuleController,
            label: 'Go module',
            hint: 'example.com/my_project',
            icon: Icons.account_tree_outlined,
          ),
        ],
        if (_selectedLanguage == 'Rust') ...[
          const SizedBox(height: 14),
          _field(
            controller: _rustEditionController,
            label: 'Rust edition',
            hint: '2021',
            icon: Icons.settings,
          ),
        ],
        if (_selectedLanguage == 'Java') ...[
          const SizedBox(height: 14),
          _field(
            controller: _packageController,
            label: 'اسم حزمة Java',
            hint: 'com.example.myapp',
            icon: Icons.inventory_2_outlined,
          ),
        ],
        if (_selectedLanguage == 'PHP') ...[
          const SizedBox(height: 14),
          _field(
            controller: _authorController,
            label: 'اسم الناشر',
            hint: 'your-vendor',
            icon: Icons.person_outline,
          ),
        ],
        const SizedBox(height: 18),
        _optionTile(
          title: 'إنشاء README.md',
          subtitle: 'ملف يشرح المشروع ومعلوماته.',
          value: _includeReadme,
          onChanged: (value) {
            setState(() => _includeReadme = value);
          },
        ),
        _optionTile(
          title: 'إنشاء .gitignore',
          subtitle: 'تجاهل الملفات غير المطلوبة في Git.',
          value: _includeGitignore,
          onChanged: (value) {
            setState(() => _includeGitignore = value);
          },
        ),
      ],
    );
  }

  Widget _buildSummaryStep() {
    return _stepContent(
      title: 'مكان حفظ المشروع',
      subtitle: 'سيتم إنشاء مجلد باسم المشروع داخل المكان الذي تختاره.',
      children: [
        _infoCard(
          'اسم المشروع: $_projectName\n'
          'اسم المجلد: $_safeProjectName\n'
          'اللغة: $_selectedLanguage\n'
          'النوع: ${_projectMode == 'integrated' ? 'متكامل' : 'أساسي'}\n'
          'القالب: ${_templateLabel(_selectedTemplate)}\n'
          'ملف البداية: $_actualEntryFile',
        ),
        const SizedBox(height: 14),
        if (_saveLocation != null)
          _infoCard(
            'مكان الحفظ:\n${_saveLocation!.name}',
          )
        else
          _infoCard(
            'عند الضغط على إنشاء المشروع، ستفتح نافذة اختيار مجلد الحفظ.',
          ),
        if (_isFlutter) ...[
          const SizedBox(height: 14),
          _infoCard(
            'تنبيه: مشروع Flutter الناتج يحتوي ملفات المصدر والإعدادات '
            'الأساسية فقط، وليس scaffold أصليًا كاملًا قابلًا للبناء.',
          ),
        ],
      ],
    );
  }

  Widget _stepContent({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      enabled: !_isCreating && !_isPickingLocation,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _infoCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(height: 1.6),
      ),
    );
  }

  Widget _optionTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: _isCreating || _isPickingLocation
          ? null
          : onChanged,
    );
  }

  Widget _buildBottomBar() {
    final busy = _isCreating || _isPickingLocation;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: Row(
          children: [
            if (_currentStep > 0)
              OutlinedButton.icon(
                onPressed: busy ? null : _previousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('السابق'),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : _currentStep == 3
                      ? _chooseLocation
                      : _nextStep,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      _currentStep == 3
                          ? Icons.create_new_folder
                          : Icons.arrow_forward,
                    ),
              label: Text(
                _isCreating
                    ? 'جارٍ الإنشاء...'
                    : _isPickingLocation
                        ? 'جارٍ اختيار المكان...'
                        : _currentStep == 3
                            ? 'اختيار المكان وإنشاء'
                            : 'التالي',
              ),
            ),
          ],
        ),
      ),
    );
  }
}