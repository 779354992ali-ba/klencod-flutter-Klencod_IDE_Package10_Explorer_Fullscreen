# Bisho IDE Package 71 — Dart analyzer repairs

## Fixes
- Corrected symbol source offsets to use the full regular-expression match start plus the captured identifier's position; this avoids calling `RegExpMatch.start` as a function.
- Passed the selected entry-file path and project version into `_appendTemplateFiles`, fixing undefined `entry` and `version` references in generated HTML, Python, and native Android templates.
- Renamed the Flutter preview panel color constant to `_panelColor`, removing its collision with the `_panel()` widget builder.
- Removed the unsupported `mainAxisSize` argument from `Wrap` in the restore-point actions.
- Removed two unused `saf` imports.
- Updated the app build number to `1.0.0+71`.

## Validation status
- Source-level checks confirm the reported identifiers and member-name collision are corrected.
- Flutter/Dart SDK is not installed in this environment, so `flutter analyze`, `flutter test`, and release APK build still require GitHub Actions validation.
