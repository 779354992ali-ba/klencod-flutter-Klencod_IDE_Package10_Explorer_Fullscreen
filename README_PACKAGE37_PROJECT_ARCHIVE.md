# Bisho IDE Package 37 — Full Project ZIP Import / Export

## Implemented in this package
- Added ZIP archive support for complete project export, not only the active editor file.
- Export walks the selected SAF project folder recursively, includes nested folders and files, and writes a ZIP through Android's file picker.
- Added ZIP import through Android's file picker and SAF destination-folder picker.
- ZIP import creates a new project folder and restores nested directories/files while rejecting dot-segment traversal paths and file/folder collisions.
- Added dedicated dashboard and menu actions for full ZIP export and ZIP import.
- Kept the existing single-file export action.
- Updated GitHub Actions to run `flutter analyze` and `flutter test` before building the release APK.

## Important platform limitation
The Flutter project wizard currently creates Flutter source files (`pubspec.yaml`, `lib/main.dart`, and optional documentation/ignore files). It does not run the Flutter CLI and therefore does not generate a complete Android Gradle platform inside each newly created Flutter project. A complete Android platform still requires `flutter create --platforms=android .` using a Flutter SDK, or a configured cloud-build process. This package does not claim that this in-app platform-generation limitation has been solved.

## Validation status
- Source changes were reviewed and packaged.
- Flutter SDK is not available in the editing environment; `flutter analyze`, `flutter test`, and APK build have not been run here.
- The updated GitHub Actions workflow performs those checks when run in GitHub.
