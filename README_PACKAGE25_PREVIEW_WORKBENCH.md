# Bisho IDE — Package 25: Preview & Runner Workbench

## Changes
- Added copy-to-clipboard for filtered HTML preview console output.
- Added copy-to-clipboard for JavaScript runner output.
- Preserved existing console filtering, clearing, refresh, navigation, and bounded log buffers.
- Corrected the Flutter preview status so it does not imply that an APK build is running when no build provider is connected.
- Flutter preview now states explicitly that no local build is performed and provides copyable build-status logs.
- Kept HTML project preview and JavaScript execution behavior unchanged.

## Validation
- Source-level wiring and YAML checks are performed during packaging.
- Flutter tests, Dart analysis, and Android release build require the SDK and remain NOT RUN if unavailable.
