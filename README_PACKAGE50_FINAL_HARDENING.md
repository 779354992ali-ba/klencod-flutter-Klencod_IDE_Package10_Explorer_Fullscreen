# Bisho IDE — Package 50 Consolidated Hardening

Package50 is a consolidated continuation of Package38. It preserves the existing application structure and features and includes the following changes:

## Included changes

- Retained Package38's Flutter starter-template import correction.
- Retained the generated Flutter project's GitHub Actions workflow, which creates the Android platform using the official Flutter CLI during cloud build. It does **not** create the Android platform locally inside Bisho IDE.
- Retained ZIP path traversal checks and archive entry/expanded-size limits.
- Added ZIP file-path collision checks: duplicate files and a regular file used as the parent of another file are rejected before extraction.
- Applied the same archive entry, expanded-size, and path-collision validation to project ZIP export.
- Corrected export status semantics: exporting a copy of the active editor buffer no longer marks the original document as saved.
- Added tests for duplicate ZIP paths, file/directory collisions, and valid independent nested paths.
- Updated the main GitHub Actions build workflow to run on pushes to both `main` and `master`.
- Bumped application version to `1.0.0+50`.

## Not claimed as completed

The following requirements remain unverified or incomplete and must not be described as fixed:

- Creating a complete local Flutter Android platform folder from inside the Android editor. Package50 still relies on the official Flutter CLI in GitHub Actions for generated Flutter projects.
- A full device-side Flutter/Gradle build workflow for arbitrary imported projects.
- Actual Python execution through Chaquopy. The current dependency and native integration path has not been demonstrated by a successful device test.
- Full SAF compatibility across document providers, including provider-specific rename/delete/recursive traversal behavior.
- End-to-end HTML preview with all relative resources, large projects, and provider edge cases.
- End-to-end tests for every UI action and every language template.

## Validation performed for this package

- ZIP structure and file inventory inspected.
- YAML syntax parsed for the package's GitHub Actions workflows and `pubspec.yaml`.
- Android manifest XML parsed.
- ZIP archive integrity checked with `unzip -t`.
- Source-level assertions checked for the new validator calls and version.

## Validation not performed

Flutter and Dart CLIs are not installed in the packaging environment. Therefore `flutter pub get`, `dart format`, `flutter analyze`, `flutter test`, and `flutter build apk --release` were **not** executed here. Package50 is a consolidated development package, not a claim of a fully tested production release. Run the included GitHub Actions workflow to obtain the authoritative build/test result.
