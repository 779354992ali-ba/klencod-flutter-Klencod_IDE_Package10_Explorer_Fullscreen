import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/languages/language_identity.dart';

void main() {
  test('language identities cover every project wizard language', () {
    const expected = [
      'Flutter', 'Dart', 'Python', 'JavaScript', 'TypeScript', 'Java',
      'Kotlin', 'Swift', 'C', 'C++', 'HTML', 'CSS', 'JSON', 'SQL',
      'Bash', 'Go', 'Rust', 'PHP', 'C#', 'Ruby', 'XML', 'YAML',
    ];
    final names = LanguageIdentity.all.map((item) => item.name).toSet();
    for (final language in expected) {
      expect(names.contains(language), isTrue, reason: '$language has no identity');
    }
    expect(names.length, LanguageIdentity.all.length,
        reason: 'Language identities must be unique');
  });

  test('every language identity has a visible brand mark', () {
    for (final identity in LanguageIdentity.all) {
      expect(identity.mark.trim(), isNotEmpty);
    }
  });

  test('file names resolve to language identities by extension', () {
    const cases = <String, String>{
      'main.dart': 'Dart',
      'app.py': 'Python',
      'MainActivity.kt': 'Kotlin',
      'main.cpp': 'C++',
      'Program.cs': 'C#',
      'icon.svg': 'SVG',
      'notes.txt': 'Plain Text',
      'index.tsx': 'TypeScript',
      'index.html': 'HTML',
      'styles.scss': 'CSS',
      'config.yaml': 'YAML',
      'layout.xml': 'XML',
      'query.sql': 'SQL',
      'script.sh': 'Bash',
      'Gemfile': 'Ruby',
      'Dockerfile': 'Dockerfile',
      'gradlew.bat': 'PowerShell',
      'README.md': 'Markdown',
      'build.gradle': 'Kotlin',
      'server.mjs': 'JavaScript',
      'main.phtml': 'PHP',
      'script.zsh': 'Bash',
      'Cargo.toml': 'TOML',
      'MainActivity.java': 'Java',
      'native.mm': 'Objective-C',
      'build.gradle.kts': 'Kotlin',
      'main.scala': 'Scala',
      'terraform.tf': 'Terraform',
      'script.pl': 'Perl',
    };
    for (final entry in cases.entries) {
      expect(
        LanguageIdentity.fromFileName(entry.key).name,
        entry.value,
        reason: 'Unexpected identity for ${entry.key}',
      );
    }
  });

  test('unknown extensions use the safe Other identity', () {
    expect(LanguageIdentity.fromFileName('binary.unknown').name, 'Other');
    expect(LanguageIdentity.fromFileName('LICENSE').name, 'Other');
  });
}
