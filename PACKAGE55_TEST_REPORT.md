# Package 55 test report

## Implemented
- [x] Bounded three-worker Git blob upload with stable Git tree ordering.
- [x] Bounded retry for GitHub rate-limit responses with `Retry-After` handling.
- [x] Preflight checks for required Flutter/Android/workflow files before repository creation.
- [x] Central GitHub upload exclusion policy for caches, credentials, and signing keys.
- [x] Unit tests for upload exclusions and safe `.env` templates.
- [x] YAML-structure-based Flutter pubspec validator.
- [x] Unit tests for valid Flutter dependency, false-positive comments/text, and malformed YAML.
- [x] Stronger Android folder inspection, including wrapper launcher and root Gradle files.
- [x] ZIP export traversal limits for depth, entries, individual file size, and total size.
- [x] Extracted reusable incremental ZIP export budget and added tests for duplicate paths and size ceilings.
- [x] Removed push trigger from Bisho IDE's own build workflow to avoid push + dispatch duplicate builds.
- [x] Added Gradle wrapper file checks to the CI workflow.
- [x] Updated app version to `1.0.0+55`.

## Static checks
- [x] `pubspec.yaml`, both GitHub workflow YAML documents, and actions lock YAML parse successfully with PyYAML.
- [x] All Flutter template assets declared in `pubspec.yaml` exist.
- [x] Bundled Gradle wrapper JAR passes ZIP integrity validation.
- [x] Generated Flutter workflow YAML parses and contains `workflow_dispatch` without a `push` trigger.
- [x] Bisho IDE CI workflow parses and contains `workflow_dispatch` without a `push` trigger.
- [x] Existing Android manifest and styles XML parse successfully.
- [x] Updated Dart source files pass a lightweight lexical delimiter/string-balance check (this is not a substitute for `dart analyze`).
- [x] Package version is `1.0.0+55`.

## Not run
- `flutter pub get`: Flutter SDK unavailable in authoring environment.
- `flutter analyze`: Dart/Flutter SDK unavailable.
- `flutter test`: Dart/Flutter SDK unavailable.
- Android release APK build: not run.
- GitHub repository creation/upload/dispatch: requires the user's PAT and a test repository.
- SAF import/export and project creation: requires testing on Android device/providers.

No claim is made that Package 55 is APK-build verified.
