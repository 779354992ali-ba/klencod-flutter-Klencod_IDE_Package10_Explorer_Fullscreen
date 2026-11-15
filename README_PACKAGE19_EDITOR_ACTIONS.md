# Bisho IDE Package 19 — Editor Actions & Honest Tooling

## Changes
- The dashboard's **Replace** tile now opens the search dialog with replace mode enabled.
- Search and replace remains local to the active file and uses the existing implementation; no network service or API key is introduced.
- The **Save all files** tile now invokes the existing `saveAllTabs` action.
- Dashboard entries that previously opened code completion while claiming to be plugins, diagnostics, or other tools now show a clear availability message instead of pretending the feature is implemented.
- Added an editor information dialog describing currently available capabilities.
- No new dependencies, paid APIs, subscriptions, or licenses were added.

## Validation
- ZIP structure and required project files checked.
- Dart source changes inspected for balanced edits.
- Flutter/Dart SDK is not available in this execution environment, so `flutter analyze`, tests, and APK compilation still need to be run through the project's GitHub Actions workflow.
