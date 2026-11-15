import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:saf/saf.dart';

import 'saf_file_service.dart';
import 'github_upload_policy.dart';

class GitHubAccount {
  final String login;
  final String avatarUrl;

  const GitHubAccount({required this.login, required this.avatarUrl});
}

class GitHubRepositoryResult {
  final String owner;
  final String repository;
  final String htmlUrl;
  final String branch;
  final int uploadedFiles;

  const GitHubRepositoryResult({
    required this.owner,
    required this.repository,
    required this.htmlUrl,
    required this.branch,
    required this.uploadedFiles,
  });
}

/// GitHub integration: token is kept in Android Keystore-backed secure storage.
/// Never write the token to logs, preferences, project files, or exceptions.
class GitHubRepositoryService {
  GitHubRepositoryService({http.Client? client}) : _client = client ?? http.Client();

  static const _tokenKey = 'bisho_github_pat_v1';
  static const _storage = FlutterSecureStorage();
  final http.Client _client;

  void close() => _client.close();

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token.trim());

  Future<void> disconnect() => _storage.delete(key: _tokenKey);

  Map<String, String> _headers(String token) => {
    'Accept': 'application/vnd.github+json',
    'Authorization': 'Bearer $token',
    'X-GitHub-Api-Version': '2022-11-28',
    'Content-Type': 'application/json',
    'User-Agent': 'Bisho-IDE',
  };

  Future<GitHubAccount> verifyToken(String token) async {
    final response = await _client.get(
      Uri.https('api.github.com', '/user'),
      headers: _headers(token),
    ).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw StateError(_apiError(response));
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final login = data['login']?.toString() ?? '';
    if (login.isEmpty) throw StateError('لم يُرجع GitHub اسم الحساب.');
    return GitHubAccount(
      login: login,
      avatarUrl: data['avatar_url']?.toString() ?? '',
    );
  }

  String _apiError(http.Response response) {
    var message = 'HTTP ${response.statusCode}';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}
    if (response.statusCode == 401) return 'رمز GitHub غير صالح أو منتهي الصلاحية.';
    if (response.statusCode == 403) {
      final remaining = response.headers['x-ratelimit-remaining'];
      if (remaining == '0' || response.body.toLowerCase().contains('rate limit')) {
        return 'وصل حساب GitHub إلى حد الطلبات المؤقت. انتظر قليلًا ثم أعد المحاولة.';
      }
      return 'رفض GitHub العملية. تحقق من صلاحيات الرمز وإمكانية إنشاء المستودعات.';
    }
    if (response.statusCode == 429) return 'GitHub يطلب تهدئة الطلبات. انتظر قليلًا ثم أعد المحاولة.';
    if (response.statusCode == 404) return 'لم يتم العثور على المورد أو لا يملك الرمز صلاحية الوصول.';
    return 'GitHub: $message';
  }

  Future<GitHubRepositoryResult> createAndPushProject({
    required String token,
    required String projectUri,
    required String repositoryName,
    required String description,
    required bool isPrivate,
    required String workflowFile,
    required SafFileService safFiles,
    void Function(String message)? onProgress,
  }) async {
    final account = await verifyToken(token);
    final repoName = _validateRepositoryName(repositoryName);

    onProgress?.call('جارٍ قراءة ملفات المشروع من مساحة التخزين...');
    final files = <_ProjectFile>[];
    var totalBytes = 0;
    await _collectFiles(
      safFiles: safFiles,
      directoryUri: projectUri,
      prefix: '',
      files: files,
      onFile: (file) {
        files.add(file);
        totalBytes += file.bytes.length;
        if (totalBytes > 50 * 1024 * 1024) {
          throw StateError('حجم المشروع يتجاوز 50 ميجابايت.');
        }
      },
    );
    if (files.isEmpty) throw StateError('المشروع لا يحتوي على ملفات قابلة للرفع.');
    final workflowPath = _normalizeWorkflowPath(workflowFile);
    final availablePaths = files.map((file) => file.path).toSet();
    final requiredPaths = <String>{
      'pubspec.yaml',
      'android/settings.gradle',
      'android/build.gradle',
      'android/gradle.properties',
      'android/app/build.gradle',
      'android/app/src/main/AndroidManifest.xml',
      'android/app/src/main/res/values/styles.xml',
      'android/gradlew',
      'android/gradlew.bat',
      'android/gradle/wrapper/gradle-wrapper.jar',
      'android/gradle/wrapper/gradle-wrapper.properties',
      workflowPath,
    };
    final missingPaths = requiredPaths.difference(availablePaths).toList()..sort();
    final hasMainActivity = files.any((file) =>
        (file.path.startsWith('android/app/src/main/kotlin/') ||
            file.path.startsWith('android/app/src/main/java/')) &&
        (file.path.endsWith('/MainActivity.kt') ||
            file.path.endsWith('/MainActivity.java')));
    if (!hasMainActivity) {
      missingPaths.add('android/app/src/main/{kotlin,java}/**/MainActivity');
    }
    if (missingPaths.isNotEmpty) {
      throw StateError('المشروع غير جاهز للرفع والبناء. الملفات الناقصة: ${missingPaths.join(', ')}');
    }
    final uniquePaths = <String>{};
    for (final file in files) {
      if (!uniquePaths.add(file.path)) {
        throw StateError('يوجد مسار مكرر في المشروع: ${file.path}');
      }
    }
    if (files.length > 1200) throw StateError('المشروع كبير جدًا: الحد الأقصى 1200 ملف.');
    if (totalBytes > 50 * 1024 * 1024) {
      throw StateError('حجم المشروع يتجاوز حد الرفع الآمن البالغ 50 ميجابايت.');
    }

    onProgress?.call('جارٍ إنشاء مستودع خاص على GitHub...');
    final create = await _client.post(
      Uri.https('api.github.com', '/user/repos'),
      headers: _headers(token),
      body: jsonEncode({
        'name': repoName,
        'description': description,
        'private': isPrivate,
        'auto_init': false,
      }),
    ).timeout(const Duration(seconds: 30));
    if (create.statusCode != 201) throw StateError(_apiError(create));
    final repo = jsonDecode(create.body) as Map<String, dynamic>;
    final owner = (repo['owner'] as Map?)?['login']?.toString() ?? account.login;
    final branch = 'main';

    // Upload a small bounded number of blobs in parallel. This is much faster
    // than one request at a time while avoiding an aggressive burst that can
    // trigger GitHub secondary rate limits on mobile networks.
    final tree = List<Map<String, dynamic>?>.filled(files.length, null);
    var nextIndex = 0;
    var completed = 0;
    Object? uploadError;
    StackTrace? uploadStack;
    final workerCount = files.length < 3 ? files.length : 3;

    Future<void> uploadWorker() async {
      while (uploadError == null) {
        final index = nextIndex++;
        if (index >= files.length) return;
        final file = files[index];
        try {
          final blob = await _postJsonWithRetry(
            Uri.https('api.github.com', '/repos/$owner/$repoName/git/blobs'),
            token: token,
            body: {
              'content': base64Encode(file.bytes),
              'encoding': 'base64',
            },
            timeout: const Duration(seconds: 45),
          );
          if (blob.statusCode != 201) throw StateError(_apiError(blob));
          final sha = (jsonDecode(blob.body) as Map<String, dynamic>)['sha']?.toString();
          if (sha == null || sha.isEmpty) {
            throw StateError('تعذر إنشاء Git blob للملف ${file.path}.');
          }
          tree[index] = {
            'path': file.path,
            'mode': file.path == 'android/gradlew' ? '100755' : '100644',
            'type': 'blob',
            'sha': sha,
          };
          completed++;
          if (completed == 1 || completed % 10 == 0 || completed == files.length) {
            onProgress?.call('تم رفع $completed من ${files.length} ملفًا...');
          }
        } catch (error, stack) {
          uploadError ??= error;
          uploadStack ??= stack;
          return;
        }
      }
    }

    await Future.wait(List.generate(workerCount, (_) => uploadWorker()));
    if (uploadError != null) {
      Error.throwWithStackTrace(uploadError!, uploadStack!);
    }
    final completedTree = tree.whereType<Map<String, dynamic>>().toList();
    if (completedTree.length != files.length) {
      throw StateError('لم يكتمل رفع جميع ملفات المشروع إلى GitHub.');
    }

    onProgress?.call('جارٍ إنشاء شجرة Git والالتزام الأول...');
    final treeResponse = await _client.post(
      Uri.https('api.github.com', '/repos/$owner/$repoName/git/trees'),
      headers: _headers(token),
      body: jsonEncode({'tree': completedTree}),
    ).timeout(const Duration(seconds: 45));
    if (treeResponse.statusCode != 201) throw StateError(_apiError(treeResponse));
    final treeSha = (jsonDecode(treeResponse.body) as Map<String, dynamic>)['sha'] as String;

    final commitResponse = await _client.post(
      Uri.https('api.github.com', '/repos/$owner/$repoName/git/commits'),
      headers: _headers(token),
      body: jsonEncode({
        'message': 'Initial project upload from Bisho IDE',
        'tree': treeSha,
      }),
    ).timeout(const Duration(seconds: 45));
    if (commitResponse.statusCode != 201) throw StateError(_apiError(commitResponse));
    final commitSha = (jsonDecode(commitResponse.body) as Map<String, dynamic>)['sha'] as String;

    final refResponse = await _client.post(
      Uri.https('api.github.com', '/repos/$owner/$repoName/git/refs'),
      headers: _headers(token),
      body: jsonEncode({'ref': 'refs/heads/$branch', 'sha': commitSha}),
    ).timeout(const Duration(seconds: 30));
    if (refResponse.statusCode != 201) throw StateError(_apiError(refResponse));

    return GitHubRepositoryResult(
      owner: owner,
      repository: repoName,
      htmlUrl: repo['html_url']?.toString() ?? 'https://github.com/$owner/$repoName',
      branch: branch,
      uploadedFiles: files.length,
    );
  }

  Future<void> dispatchBuild({
    required String token,
    required String owner,
    required String repository,
    required String workflow,
    required String branch,
    required String flutterVersion,
  }) async {
    final uri = Uri.https('api.github.com', '/repos/$owner/$repository/actions/workflows/${Uri.encodeComponent(workflow)}/dispatches');
    http.Response? response;
    for (var attempt = 0; attempt < 3; attempt++) {
      response = await _client.post(
        uri,
        headers: _headers(token),
        body: jsonEncode({
          'ref': branch,
          'inputs': {'flutter_version': flutterVersion},
        }),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 204) return;
      if (attempt < 2 && (response.statusCode == 404 || response.statusCode == 422)) {
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }
      break;
    }
    throw StateError(_apiError(response!));
  }

  Future<http.Response> _postJsonWithRetry(
    Uri uri, {
    required String token,
    required Map<String, Object?> body,
    required Duration timeout,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final response = await _client.post(
        uri,
        headers: _headers(token),
        body: jsonEncode(body),
      ).timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      final remaining = response.headers['x-ratelimit-remaining'];
      final rateLimited = response.statusCode == 429 ||
          (response.statusCode == 403 &&
              (remaining == '0' || response.body.toLowerCase().contains('secondary rate limit')));
      if (!rateLimited || attempt == 2) return response;
      final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
      final waitSeconds = retryAfter ?? (2 << attempt);
      await Future<void>.delayed(Duration(seconds: waitSeconds.clamp(1, 20).toInt()));
    }
    throw StateError('تعذر إكمال طلب GitHub بعد محاولات إعادة الاتصال.');
  }

  Future<void> _collectFiles({
    required SafFileService safFiles,
    required String directoryUri,
    required String prefix,
    required List<_ProjectFile> files,
    required void Function(_ProjectFile file) onFile,
    int depth = 0,
  }) async {
    if (depth > 32) throw StateError('تداخل مجلدات المشروع يتجاوز 32 مستوى.');
    final items = await safFiles.listDirectory(directoryUri);
    for (final item in items) {
      final name = item.name;
      if (name.isEmpty || name == '.' || name == '..' || name.contains('/') || name.contains('\\')) continue;
      if (item.isDir) {
        if (GitHubUploadPolicy.shouldExcludeDirectory(name)) continue;
        await _collectFiles(
          safFiles: safFiles,
          directoryUri: item.uri,
          prefix: prefix.isEmpty ? name : '$prefix/$name',
          files: files,
          onFile: onFile,
          depth: depth + 1,
        );
      } else {
        if (GitHubUploadPolicy.shouldExcludeFile(name)) continue;
        if (files.length >= 1200) throw StateError('المشروع يتجاوز الحد الأقصى البالغ 1200 ملف.');
        final bytes = await safFiles.readFile(item.uri);
        if (bytes.length > 10 * 1024 * 1024) {
          throw StateError('الملف $name أكبر من 10 ميجابايت ولا يمكن رفعه بهذه الطريقة.');
        }
        final path = prefix.isEmpty ? name : '$prefix/$name';
        onFile(_ProjectFile(path, bytes));
      }
    }
  }

  String _normalizeWorkflowPath(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.startsWith('/') ||
        trimmed.contains('\\') || trimmed.split('/').any((part) => part == '..' || part == '.')) {
      throw ArgumentError('مسار ملف Workflow غير صالح.');
    }
    final path = trimmed.startsWith('.github/workflows/')
        ? trimmed
        : '.github/workflows/$trimmed';
    final lowerPath = path.toLowerCase();
    if (!lowerPath.endsWith('.yml') && !lowerPath.endsWith('.yaml')) {
      throw ArgumentError('ملف Workflow يجب أن ينتهي بـ .yml أو .yaml.');
    }
    return path;
  }

  String _validateRepositoryName(String value) {
    final name = value.trim();
    if (name.isEmpty || name.length > 100 ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(name) ||
        name == '.' || name == '..') {
      throw ArgumentError('اسم المستودع غير صالح. استخدم أحرفًا وأرقامًا وشرطة أو نقطة أو شرطة سفلية.');
    }
    return name;
  }
}

class _ProjectFile {
  final String path;
  final List<int> bytes;
  const _ProjectFile(this.path, this.bytes);
}
