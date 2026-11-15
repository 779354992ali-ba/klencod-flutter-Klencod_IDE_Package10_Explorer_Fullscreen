# Package34 — Editor Preview Integration

## Fixes
- HTML preview no longer stops with a generic "open project folder" message. If no project root is active, the app opens the Android Storage Access Framework folder picker and continues automatically after a folder is selected.
- Before launching preview, the app verifies that the active HTML file URI is actually contained in the selected project tree. This prevents selecting an unrelated folder and copying the wrong resources.
- If the HTML file is unsaved/unlinked or outside the chosen project, the app gives a precise recovery message.
- Existing preview pipeline remains local on Android: project resources are copied to a temporary app directory, the current unsaved HTML editor text replaces the copied HTML file, then WebView loads it.

## Preview controls moved into the editor
- Removed the Flutter preview shortcut from the dashboard app bar.
- Removed preview actions from the dashboard tools collection.
- Added two actions to the full-screen editor app bar:
  - Run / Preview current file (HTML, supported web files, JSON, or honest unsupported-language capability message).
  - Flutter build / preview screen (project inspection and configured GitHub Actions build workflow).
- Both actions use the same existing callbacks and preview screens; no preview capability is faked.

## Constraints
- HTML preview stays local and does not upload project files.
- Flutter APK building remains cloud-based through the configured GitHub Actions workflow.
- No flutter test or flutter analyze commands were added.
