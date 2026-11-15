# Bisho IDE — Package 23: Workspace Dashboard & Project Experience

## Scope
Package 23 continues directly from Package 22. It improves the workspace/dashboard, project explorer, settings entry point, and local diagnostics surface instead of limiting work to the code editor.

## Changes
- Added `WorkspaceMetrics`, a dependency-free service that calculates open-tab count, lines, words, and characters from the in-memory editor sources. It does not claim to scan the project directory.
- Added a dashboard metrics panel with an explicit note that values describe open tabs only.
- Added a case-insensitive filter to the project explorer for items in each currently displayed directory level. It does not recursively search collapsed folders.
- Connected the workspace explorer visibility preference to the actual navigation drawer.
- Added a workspace settings sheet for explorer visibility and editor font size, persisting through the existing SharedPreferences preference flow.
- Connected both the diagnostics and code-analysis dashboard actions to the existing local diagnostics function and clearly labels the results as local checks, not a compiler replacement.
- Kept the existing project wizard, SAF storage service, previews, editor controllers, and Package 22 keyboard/editing behavior in place.

## New tests
- `test/workspace_metrics_test.dart`
  - multiple open sources
  - empty source handling
  - no open tabs

## Validation
- ZIP integrity and source-preservation checks are performed when packaging.
- Flutter tests, Dart analysis, and Android build require a Flutter SDK. If unavailable in the execution environment, they are explicitly marked NOT RUN.
