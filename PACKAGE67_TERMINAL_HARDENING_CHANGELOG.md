# Bisho IDE Package 67 — Terminal Hardening

## Changes
- Fixed Windows-style backslash paths so they are normalized to project-relative `/` paths.
- Fixed `mkdir -p` when invoked from a nested current directory; it now resolves from the selected project root and keeps `..` inside that root.
- Added duplicate-name protection for `mkdir`.
- Added confirmation before `write` or `echo >` replaces an existing file.
- Added overwrite confirmation and same-file protection to `cp`.
- Enabled safe file and folder renaming with collision checks through `mv` / `rename`.
- Bounded `find` traversal to 1,000 inspected items and retained its depth and match limits.
- Limited unbounded `cat` output to files up to 2 MB; use `head` or `tail` for larger files.
- Updated application version to `1.0.0+67`.

## Scope and limitations
The terminal remains a project-scoped Storage Access Framework command interpreter. It does not execute Linux, Dart, Flutter, Git, Node, Python, Gradle, or arbitrary operating-system processes. A real shell requires a separately packaged Android execution runtime and is not claimed by this release.

## Validation
- Source-level checks and ZIP integrity checks are performed for this package.
- Flutter/Dart analysis, widget tests, and APK build were not run in this environment because the Flutter/Dart SDK is unavailable.
