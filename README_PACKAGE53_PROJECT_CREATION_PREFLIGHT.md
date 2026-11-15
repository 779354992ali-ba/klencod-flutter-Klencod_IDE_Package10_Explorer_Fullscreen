# Package 53 — Project Creation Preflight

Package53 continues from Package52 and changes the in-app project creation flow (not the APK build workflow).

## Changes

- Adds `ProjectFilePlanValidator` to validate the complete generated file map before the app creates the project root through Android SAF.
- Rejects absolute paths, traversal segments, empty path segments, backslashes and null bytes.
- Rejects file/directory prefix collisions and a missing configured entry file.
- Enforces limits of 10,000 generated files, 16 MiB per generated file and 64 MiB total UTF-8 content.
- Adds unit tests for valid plans, unsafe paths, collisions, missing entry points and oversized files.

## Validation limits

The packaging environment does not have Flutter or Dart installed. The new tests are authored but have not been executed with `flutter test`; formatting, analyzer, APK build and device testing remain unverified. This change does not add an on-device Flutter SDK, generate the official Android platform locally, embed a Python interpreter/Chaquopy, or certify SAF providers. Those remain explicit release blockers rather than claimed features.
