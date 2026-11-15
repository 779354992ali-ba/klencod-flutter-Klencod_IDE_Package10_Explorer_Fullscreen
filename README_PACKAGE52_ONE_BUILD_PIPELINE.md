# Bisho IDE — Package 52: One-Build Pipeline Hardening

Package52 keeps the existing Package51 application source and tightens the single release-build workflow.

## CI changes

- Uses Ubuntu 24.04 and Java 17.
- Keeps the Flutter stable version selectable at workflow dispatch; default is 3.47.2.
- Caches Pub dependencies.
- Resolves dependencies once, then runs analysis and tests without resolving them again.
- Validates the required Android Gradle, manifest, and Kotlin activity files before building.
- Parses the Android manifest and theme XML before Gradle starts.
- Builds one universal release APK (not split APKs).
- Fails if the APK is missing or empty.
- Publishes the APK and its SHA-256 checksum as one workflow artifact.
- Prevents duplicate builds for the same branch/ref from consuming runners concurrently.
- Adds a root `.gitignore` for generated Flutter, Gradle, and local signing files.

## What this does not claim

- This does not add an embedded Flutter SDK to Bisho IDE. Flutter projects created inside Bisho IDE still need the Flutter CLI to generate the official Android platform template; their generated workflow does that in GitHub Actions.
- This does not add Chaquopy or execute Python on-device. Python source editing is not Python runtime execution.
- SAF compatibility across Android versions and cloud/document providers still requires real-device testing.
- The HTML preview resource guard is source-level protection; large-project behavior and local asset loading still need Android runtime testing.
- This package has not been certified as error-free. Flutter analysis, tests, and the release build must pass in GitHub Actions, followed by device checks.

## Single-build instructions

1. Push this package to the repository's `main` branch (or `master`). The workflow runs automatically.
2. Alternatively, use Actions → Build Flutter APK → Run workflow and keep Flutter version `3.47.2`.
3. Wait for the `Validate and build one release APK` job.
4. Download `Bisho-IDE-Release-APK` from the completed workflow's Artifacts section.

The workflow runs analysis, tests, and exactly one universal APK build in that run. If validation fails, no APK artifact is uploaded.
