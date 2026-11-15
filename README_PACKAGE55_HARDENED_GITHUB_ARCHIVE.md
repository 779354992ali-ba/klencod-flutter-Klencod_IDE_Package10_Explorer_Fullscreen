# Package 55 — GitHub upload, Flutter preflight, and archive hardening

Package 55 continues Package 54 without replacing the existing application structure.

## Main improvements

### GitHub upload
- Uploads Git blobs with a bounded three-worker queue instead of serial requests.
- Preserves file order in the Git tree even when upload responses complete out of order.
- Retries GitHub rate-limit responses (`429`, and rate-limit `403`) with bounded backoff and `Retry-After` support.
- Reports progress by completed file count.
- Validates all required Flutter, Android Gradle wrapper, manifest, and workflow files before creating a repository. This prevents creating a new repository for a project that cannot enter the configured build workflow.
- Centralizes exclusions for build caches and local credentials/private signing files.
- Keeps `.env.example` and `.env.sample` while excluding environment-specific `.env.*` files.

### Flutter build preflight
- Parses `pubspec.yaml` as YAML and checks the actual `dependencies.flutter.sdk: flutter` structure.
- Comments and unrelated text containing `sdk: flutter` can no longer pass the Flutter project check.
- Checks for the root Gradle build files and wrapper launcher in addition to the Android manifest, app module, and wrapper JAR/properties.

### ZIP export
- Enforces depth, entry-count, per-file, and total-size limits during traversal, before the whole archive is assembled.
- Moves the incremental export budget into the reusable `ProjectArchiveBudget` service and covers it with unit tests.
- Detects duplicate file/directory paths while traversing the SAF tree.
- Retains the existing archive path validation before writing the ZIP.

### One-build CI behavior
- The Bisho IDE repository workflow now runs only through `workflow_dispatch`.
- Removed the push trigger so a GitHub API upload followed by explicit dispatch does not intentionally start two builds.
- Added checks for Gradle wrapper JAR, wrapper properties, and launcher script before running Flutter analysis/tests/build.

## Security exclusions

The GitHub uploader skips `.git`, build/cache directories, local Gradle properties, common credential files, and private signing key/certificate formats. It does not upload `.env` or environment-specific `.env.*` files, but keeps `.env.example` and `.env.sample`.

## Verification status

Static checks performed for this package are listed in `PACKAGE55_TEST_REPORT.md`. Flutter/Dart analysis, Flutter tests, Android APK build, GitHub live API upload, and SAF device testing remain unverified until run in an environment with Flutter SDK and a real Android device/account.
