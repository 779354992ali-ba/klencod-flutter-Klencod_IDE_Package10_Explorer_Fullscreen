# Package58 — Project creation and SAF reliability hardening

Package58 is an incremental continuation of Package57. It focuses on preventing
partial project folders and avoiding names that cannot be represented safely
on common development file systems.

## Changes

- Added a SAF subtree deletion operation that removes children before their
  parent, detects repeated document URIs, and enforces a maximum recursion depth.
- Project creation now attempts to remove the newly created project directory
  if writing generated source files or bundled Gradle wrapper assets fails.
  The project is retained once all scaffold files are written; failures while
  opening/saving project preferences do not delete a completed project.
- Explorer copy/move rollback now uses recursive SAF cleanup rather than
  attempting to delete a non-empty destination directory in one operation.
- Explorer subtree inspection and copy operations now stop at a bounded depth.
- Generated project paths are checked for case-insensitive collisions,
  file/directory collisions across case variants, Windows-reserved device names,
  invalid filename characters, and trailing dots/spaces.
- SAF create/write/rename operations apply the same portable child-name rules.
- Added regression tests for case collisions, reserved names, and non-portable
  filename characters. Tests are included but intentionally not run.

## Safety notes

- Project cleanup is only invoked for the new root directory created by the
  current wizard operation, and only before the generated scaffold is marked
  complete.
- Existing project directories are not passed to the rollback callback.
- A cleanup failure is surfaced to the user rather than reported as success.
- Cross-platform filename validation is intentionally conservative so a
  project created on Android can still be checked out on Windows/macOS/Linux.

## Verification

No `flutter pub get`, `flutter analyze`, `flutter test`, Dart test runner, or APK
build was run. SAF deletion and rollback still require device/provider testing.
