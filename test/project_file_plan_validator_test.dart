import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/project_file_plan_validator.dart';

void main() {
  group('ProjectFilePlanValidator', () {
    test('accepts a valid nested project with its entry point', () {
      expect(
        () => ProjectFilePlanValidator.validate(
          files: const {
            'pubspec.yaml': 'name: sample',
            'lib/main.dart': 'void main() {}',
            '.github/workflows/build.yml': 'name: build',
          },
          entryFile: 'lib/main.dart',
        ),
        returnsNormally,
      );
    });

    test('rejects unsafe and absolute paths', () {
      for (final path in [
        '../escape.dart',
        '/absolute.dart',
        r'lib\\main.dart',
        'lib/./main.dart',
        'lib//main.dart',
      ]) {
        expect(
          () => ProjectFilePlanValidator.validate(
            files: {path: 'code'},
            entryFile: path,
          ),
          throwsFormatException,
          reason: path,
        );
      }
    });

    test('rejects file-directory path collisions', () {
      expect(
        () => ProjectFilePlanValidator.validate(
          files: const {'lib': 'file', 'lib/main.dart': 'code'},
          entryFile: 'lib/main.dart',
        ),
        throwsFormatException,
      );
    });

    test('rejects a missing entry point', () {
      expect(
        () => ProjectFilePlanValidator.validate(
          files: const {'README.md': 'project'},
          entryFile: 'lib/main.dart',
        ),
        throwsFormatException,
      );
    });


    test('rejects paths that collide by letter case', () {
      expect(
        () => ProjectFilePlanValidator.validate(
          files: const {
            'lib/Main.dart': 'void main() {}',
            'LIB/main.dart': 'void main() {}',
          },
          entryFile: 'lib/Main.dart',
        ),
        throwsFormatException,
      );
    });

    test('rejects parent folders that differ only by letter case', () {
      expect(
        () => ProjectFilePlanValidator.validate(
          files: const {
            'Lib/main.dart': 'void main() {}',
            'lib/helper.dart': 'class Helper {}',
          },
          entryFile: 'Lib/main.dart',
        ),
        throwsFormatException,
      );
    });

    test('rejects a file that collides with a parent directory by case', () {
      expect(
        () => ProjectFilePlanValidator.validate(
          files: const {'Lib': 'file', 'lib/main.dart': 'code'},
          entryFile: 'lib/main.dart',
        ),
        throwsFormatException,
      );
    });

    test('rejects non-portable and reserved file names', () {
      for (final path in [
        'src/bad:name.dart',
        'src/trailing./main.dart',
        'src/CON.txt',
        'src/Lpt1.log',
      ]) {
        expect(
          () => ProjectFilePlanValidator.validate(
            files: {path: 'code'},
            entryFile: path,
          ),
          throwsFormatException,
          reason: path,
        );
      }
    });

    test('rejects oversized generated payloads', () {
      final large = List<String>.filled(
        ProjectFilePlanValidator.maxSingleFileBytes + 1,
        'x',
      ).join();
      expect(
        () => ProjectFilePlanValidator.validate(
          files: {'main.txt': large},
          entryFile: 'main.txt',
        ),
        throwsFormatException,
      );
    });
  });
}
