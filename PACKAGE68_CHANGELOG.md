# Bisho IDE Package 68 — Fixes and UI refresh

## Fixes
- Replaced 14+ deprecated `Color.withOpacity` calls with `withValues(alpha:)` (main.dart, language_identity.dart). These made `flutter analyze` report infos.
- Removed `android.builtInKotlin` and `android.newDsl` from `android/gradle.properties`. They are AGP 9 flags and conflict with AGP 8.11.1 plus the `kotlin-android` plugin.
- Added `analysis_options.yaml` (flutter_lints was a dependency but unused).
- CI: `flutter analyze` now uses `--no-fatal-infos` so style infos do not fail the APK build.
- Removed a duplicated "فحص المشروع" entry in the dashboard tools list.

## UI
- New centralized design system: `lib/core/theme/bisho_theme.dart` (colors, AppBar, menus, inputs, buttons, bottom sheets, snackbars, chips, tooltips, dividers).
- App menu now has icons and grouped sections with dividers.
- File/language bar: file icon, bolder name, bottom border, compact rounded language dropdown.
- Status bar: top border, dot is green when saved and amber when unsaved.

## Validation
- Static only: all imports resolve, brackets balance (Dart-aware check) in every lib/ and test/ file.
- Flutter analyze, tests, and APK build were NOT run (no Flutter SDK in this environment). Run the GitHub workflow to confirm.
