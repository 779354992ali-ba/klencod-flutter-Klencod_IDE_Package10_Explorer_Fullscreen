# Bisho IDE — Package 26: Diagnostics & Source Navigation

## Changes
- Upgraded the dashboard diagnostics sheet to distinguish structured-data parser errors from lightweight structural diagnostics.
- Structural diagnostics now show their line and column.
- Tapping a structural diagnostic moves the shared editor controller selection to its source offset, closes the sheet, and opens the full-screen editor.
- The UI explicitly describes local structural checks as supplemental diagnostics, not a compiler or full language analyzer.
- Existing `EditorSyntaxDiagnostics` implementation and its previous language tests remain intact.

## Validation
- Existing diagnostics unit tests remain in the project.
- Flutter tests, Dart analysis, and Android release build require the Flutter SDK and are reported separately.
