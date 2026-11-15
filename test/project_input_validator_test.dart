import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/project_input_validator.dart';

void main() {
  group('ProjectInputValidator', () {
    test('normalizes project names for generated package paths', () {
      expect(ProjectInputValidator.safeProjectName(' My Cool App '), 'my_cool_app');
      expect(ProjectInputValidator.safeProjectName('123 demo'), 'project_123_demo');
      expect(ProjectInputValidator.safeProjectName('!!!'), 'my_project');
    });

    test('rejects unsafe project names', () {
      expect(ProjectInputValidator.isValidProjectName(''), isFalse);
      expect(ProjectInputValidator.isValidProjectName('../escape'), isFalse);
      expect(ProjectInputValidator.isValidProjectName('folder\\file'), isFalse);
      expect(ProjectInputValidator.isValidProjectName('safe app'), isTrue);
    });

    test('rejects absolute and traversal relative paths', () {
      expect(ProjectInputValidator.isValidRelativePath('lib/main.dart'), isTrue);
      expect(ProjectInputValidator.isValidRelativePath('/root/file.dart'), isFalse);
      expect(ProjectInputValidator.isValidRelativePath('../outside.dart'), isFalse);
      expect(ProjectInputValidator.isValidRelativePath('lib/../outside.dart'), isFalse);
      expect(ProjectInputValidator.isValidRelativePath('lib\\main.dart'), isFalse);
      expect(ProjectInputValidator.isValidRelativePath('lib//main.dart'), isFalse);
    });

    test('validates language-specific metadata', () {
      expect(ProjectInputValidator.isValidPackageName('com.example.app'), isTrue);
      expect(ProjectInputValidator.isValidPackageName('com.123.app'), isFalse);
      expect(ProjectInputValidator.isValidVersion('1.2.3+build.4'), isTrue);
      expect(ProjectInputValidator.isValidVersion('1.2'), isFalse);
      expect(ProjectInputValidator.isValidPythonVersion('3.12'), isTrue);
      expect(ProjectInputValidator.isValidPythonVersion('3'), isFalse);
      expect(ProjectInputValidator.isValidNodeVersion('20'), isTrue);
      expect(ProjectInputValidator.isValidNodeVersion('v20'), isFalse);
      expect(ProjectInputValidator.isValidGoModule('example.com/group/app'), isTrue);
      expect(ProjectInputValidator.isValidGoModule('/absolute/module'), isFalse);
    });
  });
}
