# Package59 — Project Intelligence & Change Tracking

## Added
- Added `ProjectInsightsAnalyzer`, a deterministic in-memory static analysis layer for open project files.
- Detects unresolved relative imports for Dart/JavaScript/TypeScript-family files, undeclared `package:` imports when a pubspec is available, maintenance markers, empty catch blocks, likely embedded credentials, Dart `print()` calls, missing Flutter entrypoint hints, and potentially unused declared dependencies.
- Added severity/category metadata, source path and line references, immutable reports, and summary counters.
- Added `ProjectChangeTracker` for deterministic in-memory project snapshots and added/modified/deleted/unchanged comparisons.
- Snapshot paths reject absolute paths, traversal, NULs, malformed segments, and duplicate normalized paths. UTF-8 byte lengths and FNV-1a 32-bit fingerprints are used; these are deterministic but non-cryptographic. The fingerprint is explicitly non-cryptographic.
- Integrated a new Arabic **فحص المشروع** dashboard action. It analyzes open tabs only, reports severity counts and file/line locations, and never modifies files.
- Added focused unit tests for both services.

## Preservation
- Built from Package58 without removing existing files or features.
- Existing SAF project management, project creation, archive, preview, editor, and GitHub workflows are retained.

## Verification boundaries
- Tests were added but not executed.
- No Dart/Flutter commands, dependency resolution, Android build, or APK build were run.
- The project quality panel intentionally analyzes only currently open tabs; it is not a full SAF disk scan.
