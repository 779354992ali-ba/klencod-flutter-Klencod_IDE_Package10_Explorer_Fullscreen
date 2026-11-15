import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/github_upload_policy.dart';

void main() {
  group('GitHubUploadPolicy', () {
    test('excludes local build caches and credential folders', () {
      expect(GitHubUploadPolicy.shouldExcludeDirectory('.git'), isTrue);
      expect(GitHubUploadPolicy.shouldExcludeDirectory('build'), isTrue);
      expect(GitHubUploadPolicy.shouldExcludeDirectory('.ssh'), isTrue);
      expect(GitHubUploadPolicy.shouldExcludeDirectory('lib'), isFalse);
    });

    test('excludes private keys and local credentials', () {
      for (final name in [
        'local.properties', 'key.properties', '.env', '.env.production',
        '.npmrc', 'id_rsa.pem', 'upload-key.p12', 'signing.p8',
        'release.keystore', 'android-key.jks',
      ]) {
        expect(GitHubUploadPolicy.shouldExcludeFile(name), isTrue, reason: name);
      }
    });

    test('keeps safe environment templates and ordinary source files', () {
      expect(GitHubUploadPolicy.shouldExcludeFile('.env.example'), isFalse);
      expect(GitHubUploadPolicy.shouldExcludeFile('.env.sample'), isFalse);
      expect(GitHubUploadPolicy.shouldExcludeFile('main.dart'), isFalse);
      expect(GitHubUploadPolicy.shouldExcludeFile('README.md'), isFalse);
    });
  });
}
