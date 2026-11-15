# Bisho IDE Package 21 — Cursor Controls & Keyboard Shortcuts

## Changes
- Added a compact cursor-control strip to the full-screen editor.
- Left/right controls move the caret by one character.
- Up/down controls move the caret to the previous/next line while retaining the closest possible column.
- Added external keyboard shortcuts:
  - Ctrl+S / Cmd+S: save the current file.
  - Ctrl+Space / Cmd+Space: open code completion.
  - Ctrl+Plus / Ctrl+=: increase editor font size.
  - Ctrl+Minus: decrease editor font size.
- No new dependencies, paid APIs, subscriptions, or hosted services.

## Behavior notes
- Cursor controls collapse any active selection and move from its active end.
- Vertical movement clamps to the target line's available length.
- Hardware keyboard shortcuts are handled by the editor's focus ancestor and are intended for physical keyboards.
- Existing mobile symbol bar and editor actions are retained.

## Validation
- ZIP archive structure verified.
- Dart/Flutter analysis and APK build must still be run in the project's GitHub Actions environment; this environment does not have Flutter SDK available.
