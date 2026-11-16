# Bisho IDE Package 70 — Dart constructor compile fix

## Fix
- Removed the `const` modifier from `ProjectTextDiffReport` because its initializer calls `List.unmodifiable`, which is not a constant expression.
- Preserved the immutable result-list behavior.
- Added a regression test that verifies callers cannot mutate the report's line list.
- Updated the Android app build number to `1.0.0+70`.

## Validation
- ZIP integrity, YAML parsing, Android XML parsing, and source-level import/path checks were run.
- Flutter/Dart analysis, unit/widget tests, and release APK build were not run because the Flutter and Dart SDKs are not installed in this environment. The GitHub Actions workflow remains the authoritative full validation.
