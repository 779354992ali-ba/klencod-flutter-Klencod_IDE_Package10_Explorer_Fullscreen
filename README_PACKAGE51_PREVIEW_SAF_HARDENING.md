# Bisho IDE — Package 51 Preview and SAF Hardening

Package51 continues Package50 without removing existing features.

## Changes in this package

- Added `PreviewProjectGuard` to bound recursive project staging for HTML/WebView preview.
- Preview staging now rejects projects deeper than 32 directory levels, projects with more than 3,000 entries, individual resources larger than 32 MiB, and aggregate staged resources larger than 128 MiB.
- Added unit tests for depth, entry-count, per-file, aggregate-size, and invalid-size boundaries.
- Reset preview limits for each full preview reload.
- Bumped app version to `1.0.0+51`.

## Important limitations (not marked complete)

- Local creation of the official Flutter `android/` platform still requires the Flutter SDK. The in-app wizard does not bundle Flutter or a Gradle toolchain. Generated Flutter projects therefore use the checked-in GitHub Actions workflow to run `flutter create --platforms=android .` remotely.
- Python projects are editable only. No Chaquopy plugin, embedded Python runtime, or successful Python-on-device execution is present in this package.
- SAF compatibility still requires device testing against Android DocumentsUI and third-party providers (for example Downloads/cloud providers). Unit tests cannot establish provider-specific behavior.
- HTML preview changes are source-level hardened but have not been exercised on Android devices with real SAF providers or large projects.
- No claim is made that every UI control or all Arabic/English screens have passed end-to-end testing.

## Validation status

The package should be checked with `flutter pub get`, `dart format`, `flutter analyze`, `flutter test`, and `flutter build apk --release` in a Flutter-enabled environment. Those commands cannot be run in the current packaging environment because Flutter and Dart are unavailable. Android runtime and SAF integration checks require physical/emulated Android devices.
