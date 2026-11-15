# Package 54 — GitHub integration and local Android platform

## In-app GitHub workflow

1. Open Build and Preview for a Flutter project.
2. Create a GitHub Classic Personal Access Token with `repo` and `workflow` scopes.
3. Paste it into the GitHub token field and select **Connect GitHub**.
4. Enter a repository name and select **Create repository, upload project, and build**.
5. Bisho IDE verifies the token, reads the selected SAF project recursively, creates a private repository, uploads the Git tree, creates the `main` branch, and dispatches `build-android.yml`.
6. The screen shows the Actions page and refreshes the run status.

The token is stored using `flutter_secure_storage` (Android Keystore-backed storage). It is not written to preferences or logs. Disconnect removes the stored token.

## Local Flutter Android files

The Flutter project wizard now writes the Android Gradle project, Gradle wrapper JAR/scripts, manifest, Kotlin activity, and styles into `android/` before reporting project creation as complete. The wrapper JAR and launcher scripts are bundled as Flutter assets. The workflow checks that the Android platform exists instead of creating it in CI.

## Upload safeguards

- Maximum 1,200 files.
- Maximum 50 MiB total.
- Maximum 10 MiB per file.
- Maximum 32 directory levels.
- Skips `.git`, build/cache folders, `android/local.properties`, `key.properties`, `.env`, `.jks`, and `.keystore` files.
- Marks `android/gradlew` as executable in the Git tree.

## Required manual action

The GitHub token must be created by the account owner. For Classic PAT, enable `repo` and `workflow`. The repository is private by default. GitHub may reject repository creation if the account policy or token permissions do not allow it.

## Validation limits

Flutter and Dart SDKs are not installed in the authoring environment. `flutter pub get`, `flutter analyze`, `flutter test`, and a real APK build were not run here. SAF behavior and the generated Gradle project must be tested on Android/Flutter tooling before production use. This package is a code update, not a claim of device-level verification.
