# Bisho IDE Package 69 — Performance, tools, terminal, themes, project essentials

## Performance
- Cursor line/column is computed with an allocation-free scan instead of `substring` + regex on every rebuild.
- Undo history is now bounded by total characters (about 4M) as well as entry count, so large files do not keep ~100 full copies alive.

## Tools dashboard
- "All tools" sheet now has a live search field, an empty-state message, and keyboard-safe padding.
- The "Theme" tool now toggles light/dark.

## Terminal
- Touch-friendly quick bar: Tab completion, history up/down, ls, pwd, tree, cd .., cat, help, copy output, clear.
- Tab completion for command names and for files/folders of the current directory (also bound to the hardware Tab key).
- Copy whole terminal output to the clipboard.

## Light / dark theme
- New light theme and a persisted mode (`BishoThemeController`), toggled from the app bar or the tools dashboard.
- Dialogs, sheets, menus, app bar, language bar and status bar follow the selected theme.
- The code workspace (editor, tab bar, explorer, dashboard, bottom panel, terminal, previews and runners) stays dark by design because it is hand-styled with fixed colors.

## New project wizard — essential build/preview files
Every new project now also gets `.editorconfig`. Flutter projects additionally get:
`analysis_options.yaml`, `test/widget_test.dart` (the generated CI runs `flutter test`, which fails without a test folder), `assets/images/.gitkeep`, `.gitattributes` (keeps `gradlew` LF), `android/.gitignore`, debug and profile manifests with INTERNET permission, `drawable/launch_background.xml`, `drawable/ic_launcher.xml`, and the manifest now references the launcher icon.
HTML/CSS/JS/TS projects get `assets/images/`; Python projects get `requirements.txt`. Existing files are never overwritten and case-insensitive collisions are skipped so the file-plan preflight still passes.

## Validation
- Static only: imports resolve and brackets balance in every Dart file (Dart-aware check).
- Flutter analyze, tests, and the APK build were NOT run (no Flutter SDK here). Run the GitHub workflow to confirm.
