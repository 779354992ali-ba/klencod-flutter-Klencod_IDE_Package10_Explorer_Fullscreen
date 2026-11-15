import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/flutter_pubspec_validator.dart';

void main() {
  group('FlutterPubspecValidator', () {
    test('accepts a real Flutter SDK dependency', () {
      const source = '''
name: sample_app
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.0
''';
      expect(FlutterPubspecValidator.hasFlutterSdkDependency(source), isTrue);
    });

    test('does not accept comments or unrelated text as Flutter dependency', () {
      const source = '''
name: sample_app
# flutter:
#   sdk: flutter
dependencies:
  http: ^1.0.0
notes: "sdk: flutter"
''';
      expect(FlutterPubspecValidator.hasFlutterSdkDependency(source), isFalse);
    });

    test('rejects malformed YAML safely', () {
      expect(
        FlutterPubspecValidator.hasFlutterSdkDependency('dependencies: [\n  flutter:'),
        isFalse,
      );
    });
  });
}
