# Bisho IDE — Package 24: Project Creation Safety

## Changes
- Extracted project name normalization and input validation into the pure-Dart `ProjectInputValidator` service.
- The project wizard now delegates name, relative-path, package identifier, semantic version, Dart SDK constraint, Go module, Python version, and Node version validation to the shared service.
- Relative paths reject absolute paths, parent traversal (`..`), empty path segments, backslashes, and NUL bytes before writing files through SAF.
- Existing project templates, language-specific metadata fields, save-location selection, and project creation callbacks remain in the wizard.
- No dependency changes.

## Tests added
- `test/project_input_validator_test.dart`
- Covers project-name normalization, unsafe names, path traversal, package identifiers, version strings, and language-specific version/module values.

## Validation
Flutter tests and static analysis require a Flutter/Dart SDK. These are not marked as passed when the SDK is unavailable.
