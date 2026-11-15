import 'package:yaml/yaml.dart';

/// Validates the actual dependency structure of a Flutter pubspec.
/// Text matches inside comments or unrelated sections are not accepted.
class FlutterPubspecValidator {
  const FlutterPubspecValidator._();

  static bool hasFlutterSdkDependency(String source) {
    try {
      final dynamic document = loadYaml(source);
      if (document is! YamlMap) return false;
      final dynamic dependencies = document['dependencies'];
      if (dependencies is! YamlMap) return false;
      final dynamic flutter = dependencies['flutter'];
      return flutter is YamlMap && flutter['sdk'] == 'flutter';
    } on YamlException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
