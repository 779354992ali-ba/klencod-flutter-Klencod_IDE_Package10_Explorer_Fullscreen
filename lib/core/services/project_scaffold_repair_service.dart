import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:saf/saf.dart';

import 'saf_file_service.dart';
import 'project_health_analyzer.dart';

class ProjectRepairReport {
  final List<String> created;
  final List<String> alreadyPresent;
  final List<String> conflicts;
  final List<ProjectHealthIssue> beforeIssues;
  final List<ProjectHealthIssue> afterIssues;
  const ProjectRepairReport({
    required this.created,
    required this.alreadyPresent,
    required this.conflicts,
    this.beforeIssues = const [],
    this.afterIssues = const [],
  });
  bool get changed => created.isNotEmpty;
}

/// Adds only missing Flutter/Android scaffold entries. Existing files are
/// never overwritten; conflicting file/folder names are reported instead.
class ProjectScaffoldRepairService {
  final SafFileService saf;
  final ProjectHealthAnalyzer analyzer;
  ProjectScaffoldRepairService(this.saf, {this.analyzer = const ProjectHealthAnalyzer()});

  Future<List<ProjectHealthIssue>> inspectProject(String projectRootUri) async {
    final paths = <String>{};
    String? pubspecContent;
    Future<void> visit(String uri, String prefix, {int depth = 0}) async {
      if (depth > 32) return;
      final children = await saf.listDirectory(uri);
      for (final child in children) {
        final path = prefix.isEmpty ? child.name : '$prefix/${child.name}';
        if (child.isDir) {
          paths.add('$path/');
          await visit(child.uri, path, depth: depth + 1);
        } else {
          paths.add(path);
          if (path.toLowerCase() == 'pubspec.yaml') {
            pubspecContent = utf8.decode(await saf.readFile(child.uri), allowMalformed: true);
          }
        }
      }
    }
    await visit(projectRootUri, '');
    return analyzer.analyze(paths: paths, pubspecContent: pubspecContent);
  }

  Future<ProjectRepairReport> repairFlutterAndroid({
    required String projectRootUri,
    required String projectName,
    String? applicationId,
    bool includeAndroid = true,
    bool includeEntryPoint = true,
  }) async {
    final beforeIssues = await inspectProject(projectRootUri);
    final created = <String>[];
    final present = <String>[];
    final conflicts = <String>[];

    Future<String?> ensureDirectory(String parent, String name, String path) async {
      final old = await saf.findChild(parentUri: parent, name: name);
      if (old != null) {
        if (!old.isDir) { conflicts.add('$path (يوجد ملف بالاسم نفسه)'); return null; }
        present.add(path);
        return old.uri;
      }
      final made = await saf.createFolder(parentUri: parent, folderName: name);
      created.add(path);
      return made.uri;
    }

    Future<void> ensureFile(String parent, String name, String path, List<int> bytes,
        {String mime = 'text/plain'}) async {
      var old = await saf.findChild(parentUri: parent, name: name);
      if (old == null) {
        // Recover files created by older SAF implementations that appended
        // .txt to Gradle/config filenames despite the requested display name.
        final legacy = await saf.findChild(parentUri: parent, name: '$name.txt');
        if (legacy != null && !legacy.isDir) {
          try {
            old = await saf.renameItem(uri: legacy.uri, newName: name);
          } catch (_) {
            conflicts.add('$path (تعذر تصحيح الاسم القديم ${legacy.name})');
            return;
          }
        }
      }
      if (old != null) {
        if (old.isDir) conflicts.add('$path (يوجد مجلد بالاسم نفسه)');
        else present.add(path);
        return;
      }
      await saf.saveFile(
        parentUri: parent, fileName: name,
        bytes: Uint8List.fromList(bytes), mimeType: mime, overwrite: false,
      );
      created.add(path);
    }

    Future<void> writePath(String relative, String content,
        {String mime = 'text/plain'}) async {
      final parts = relative.split('/');
      var parent = projectRootUri;
      var path = '';
      for (final segment in parts.take(parts.length - 1)) {
        path = path.isEmpty ? segment : '$path/$segment';
        final next = await ensureDirectory(parent, segment, path);
        if (next == null) return;
        parent = next;
      }
      final name = parts.last;
      await ensureFile(parent, name, relative, utf8.encode(content), mime: mime);
    }

    var detectedId = 'com.example.app';
    final androidFolder = await saf.findChild(parentUri: projectRootUri, name: 'android');
    final appFolder = androidFolder == null || !androidFolder.isDir
        ? null : await saf.findChild(parentUri: androidFolder.uri, name: 'app');
    final appBuildFile = appFolder == null || !appFolder.isDir
        ? null : await saf.findChild(parentUri: appFolder.uri, name: 'build.gradle');
    if (appBuildFile != null && !appBuildFile.isDir) {
      final gradleText = utf8.decode(await saf.readFile(appBuildFile.uri), allowMalformed: true);
      final match = RegExp(r"""(?:applicationId|namespace)\s*(?:=\s*)?[\"']([^\"']+)[\"']""").firstMatch(gradleText);
      if (match != null) detectedId = match.group(1)!;
    }
    final idCandidate = applicationId ?? detectedId;
    final id = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z_][a-zA-Z0-9_]*)+$')
        .hasMatch(idCandidate) ? idCandidate : 'com.example.app';
    final packagePath = id.replaceAll('.', '/');
    final templates = <String, String>{
      'android/settings.gradle': '''
pluginManagement {
    def flutterSdkPath = {
        def properties = new Properties()
        file("local.properties").withInputStream { properties.load(it) }
        def path = properties.getProperty("flutter.sdk")
        assert path != null, "flutter.sdk not set in local.properties"
        return path
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
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G
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
    namespace = "$id"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    defaultConfig {
        applicationId = "$id"
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
    <application android:label="${_xmlLabel(projectName)}" android:name="\${applicationName}">
        <activity android:name=".MainActivity" android:exported="true"
            android:launchMode="singleTop" android:theme="@style/LaunchTheme"
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
      'android/app/src/main/res/values/styles.xml': '''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Material.Light.NoActionBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
''',
    };

    if (includeAndroid) {
      for (final entry in templates.entries) {
        await writePath(entry.key, entry.value,
          mime: entry.key.endsWith('.xml') ? 'application/xml' : 'text/plain');
      }
    }

    // Restore a missing Flutter entry point without touching an existing file.
    if (includeEntryPoint) {
      await writePath('lib/main.dart', '''import 'package:flutter/material.dart';\n\nvoid main() => runApp(const BishoStarterApp());\n\nclass BishoStarterApp extends StatelessWidget {\n  const BishoStarterApp({super.key});\n  @override\n  Widget build(BuildContext context) => MaterialApp(\n    title: '${_xmlLabel(projectName)}',\n    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),\n    home: Scaffold(appBar: AppBar(title: const Text('${_xmlLabel(projectName)}')), body: const Center(child: Text('Your Flutter project is ready.'))),\n  );\n}\n''');
    }

    if (includeAndroid) {
    Future<bool> hasActivity(String directoryUri, {int depth = 0}) async {
      if (depth > 14) return false;
      final children = await saf.listDirectory(directoryUri);
      for (final child in children) {
        if (child.isDir) {
          if (await hasActivity(child.uri, depth: depth + 1)) return true;
        } else if (child.name == 'MainActivity.kt' ||
            child.name == 'MainActivity.java') {
          return true;
        }
      }
      return false;
    }

    final androidApp = await saf.findChild(
      parentUri: projectRootUri, name: 'android');
    final appDir = androidApp == null || !androidApp.isDir
        ? null
        : await saf.findChild(parentUri: androidApp.uri, name: 'app');
    final srcDir = appDir == null || !appDir.isDir
        ? null
        : await saf.findChild(parentUri: appDir.uri, name: 'src');

    // Search the complete Android source tree, not only src/main. Some valid
    // projects keep a Java/Kotlin activity under a flavor-specific source set.
    final activityExists = srcDir != null && srcDir.isDir
        ? await hasActivity(srcDir.uri)
        : false;

    if (!activityExists) {
      await writePath(
        'android/app/src/main/kotlin/$packagePath/MainActivity.kt',
        'package $id\\n\\n'
        'import io.flutter.embedding.android.FlutterActivity\\n\\n'
        'class MainActivity : FlutterActivity()\\n',
      );
    }

    // Copy the official wrapper scripts/JAR bundled with Bisho. Only missing
    // files are copied, preserving user-modified wrapper files.
    for (final asset in <String, String>{
      'assets/templates/android/gradle/wrapper/gradle-wrapper.jar':
          'android/gradle/wrapper/gradle-wrapper.jar',
      'assets/templates/android/gradlew': 'android/gradlew',
      'assets/templates/android/gradlew.bat': 'android/gradlew.bat',
    }.entries) {
      final parts = asset.value.split('/');
      var parent = projectRootUri;
      var path = '';
      for (final segment in parts.take(parts.length - 1)) {
        path = path.isEmpty ? segment : '$path/$segment';
        final next = await ensureDirectory(parent, segment, path);
        if (next == null) { parent = ''; break; }
        parent = next;
      }
      if (parent.isEmpty) continue;
      final name = parts.last;
      var old = await saf.findChild(parentUri: parent, name: name);
      if (old == null) {
        final legacy = await saf.findChild(parentUri: parent, name: '$name.txt');
        if (legacy != null && !legacy.isDir) {
          try {
            old = await saf.renameItem(uri: legacy.uri, newName: name);
          } catch (_) {
            conflicts.add('${asset.value} (تعذر تصحيح الاسم القديم)');
            continue;
          }
        }
      }
      if (old != null) {
        if (old.isDir) conflicts.add(asset.value);
        else present.add(asset.value);
        continue;
      }
      final data = await rootBundle.load(asset.key);
      await saf.saveFile(
        parentUri: parent, fileName: name,
        bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        mimeType: name.endsWith('.jar') ? 'application/java-archive' : 'application/octet-stream',
        overwrite: false,
      );
      created.add(asset.value);
    }
    }

    final afterIssues = await inspectProject(projectRootUri);
    return ProjectRepairReport(
      created: List.unmodifiable(created),
      alreadyPresent: List.unmodifiable(present),
      conflicts: List.unmodifiable(conflicts),
      beforeIssues: beforeIssues,
      afterIssues: afterIssues,
    );
  }

  String _xmlLabel(String value) => value
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;').replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
