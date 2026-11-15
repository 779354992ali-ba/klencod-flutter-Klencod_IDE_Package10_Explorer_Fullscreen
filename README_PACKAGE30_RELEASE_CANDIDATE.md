# Bisho IDE — Package 30 Release Candidate

Package 30 is the cumulative continuation of Package 22 through Packages 23–30. It retains the original Flutter project, Android configuration, SAF integration, project wizard, editor services, preview screens, and all prior tests.

## Cumulative scope
- Package 23: dashboard workspace metrics, project explorer filtering, persisted workspace settings, diagnostics entry point.
- Package 24: centralized pure-Dart project input validation and path traversal tests.
- Package 25: preview/runner console copy and honest Flutter build-provider status.
- Package 26: diagnostics with line/column and tap-to-source navigation.
- Package 27: persisted Word Wrap preference.
- Package 28: Ctrl+F and Ctrl+H search shortcuts.
- Package 29: language capability catalog driven by the runtime registry.
- Package 30: cumulative integration, audit, and release-candidate packaging.

## Important runtime limitation
No Flutter/Dart SDK was available in the packaging environment. Unit tests, static analysis, and Android APK build are therefore marked NOT RUN. Do not publish an APK from this archive until those checks pass in Klencod or another Flutter-enabled environment.

## Known gaps intentionally not represented as completed
- No remote/local Flutter build provider is connected; the Flutter preview remains an honest integration placeholder and does not generate APKs.
- A complete app-wide light theme has not been implemented; the current UI remains predominantly dark.
- Full English localization and a complete translation catalog are not yet included.
- A plugin marketplace/runtime is not implemented; the capability catalog describes existing functionality only.
- Advanced recursive project search, file watcher/hot reload, and performance profiling remain future work.
