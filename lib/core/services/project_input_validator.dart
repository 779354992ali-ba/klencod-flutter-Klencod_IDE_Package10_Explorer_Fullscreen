/// Validation and normalization helpers used by the project creation wizard.
/// Kept independent from Flutter and storage so the rules can be unit tested.
class ProjectInputValidator {
  const ProjectInputValidator._();

  static String safeProjectName(String input) {
    var value = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    if (value.isEmpty) value = 'my_project';
    if (RegExp(r'^[0-9]').hasMatch(value)) value = 'project_$value';
    return value;
  }

  static bool isValidProjectName(String name) {
    if (name.trim().isEmpty || name == '.' || name == '..') return false;
    return !name.contains('/') &&
        !name.contains('\\') &&
        !name.contains(':') &&
        !name.contains('\u0000');
  }

  static bool isValidRelativePath(String path) {
    if (path.isEmpty || path.startsWith('/') || path.startsWith('\\')) {
      return false;
    }
    if (path.contains('\\') || path.contains('\u0000')) return false;
    final segments = path.split('/');
    return !segments.any((segment) =>
        segment.isEmpty || segment == '.' || segment == '..');
  }

  static bool isValidPackageName(String value) {
    if (value.isEmpty) return false;
    final parts = value.split('.');
    if (parts.length < 2) return false;
    final identifier = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');
    return parts.every(identifier.hasMatch);
  }

  static bool isValidVersion(String value) => RegExp(
        r'^\d+\.\d+\.\d+([+-][0-9A-Za-z.-]+)?$',
      ).hasMatch(value);

  static bool isValidSdkConstraint(String value) => value.isNotEmpty &&
      RegExp(r'^[0-9a-zA-Z.<>=^~+\-\s]+$').hasMatch(value);

  static bool isValidGoModule(String value) =>
      value.isNotEmpty &&
      !value.contains(' ') &&
      !value.startsWith('/') &&
      !value.endsWith('/') &&
      !value.contains('\\');

  static bool isValidPythonVersion(String value) =>
      RegExp(r'^\d+\.\d+$').hasMatch(value);

  static bool isValidNodeVersion(String value) =>
      RegExp(r'^\d+$').hasMatch(value);
}
