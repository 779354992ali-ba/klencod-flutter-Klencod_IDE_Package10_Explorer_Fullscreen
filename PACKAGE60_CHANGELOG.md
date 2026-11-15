# Package60 — Verified Project Backup & Recovery

## Added
- Added a versioned, portable `.bisho-backup.json` format for complete project snapshots, including binary files and empty directories.
- Added per-file byte-length and FNV-1a checksum validation before any restore writes occur. The checksum detects accidental corruption; it is not a cryptographic authenticity mechanism.
- Added strict format/version validation, path traversal rejection, absolute-path rejection, duplicate and case-folded path collision checks, file/directory collision checks, Windows-reserved-name rejection, and resource limits (10,000 entries, 64 MiB per file, 256 MiB total).
- Added recursive SAF project backup export, including empty folders and binary assets. Backup creation saves project-backed open tabs first and refuses to silently omit unsaved standalone tabs.
- Added SAF restore into a newly created, uniquely named project folder. Existing files are never overwritten; failures trigger recursive cleanup of the partial destination tree.
- Added dashboard actions for **نسخ احتياطي** and **استعادة نسخة**.
- Hardened `ProjectChangeTracker` against case-insensitive path collisions and file/directory prefix conflicts; corrected its displayed checksum width to match its 32-bit FNV-1a implementation.
- Added regression tests for backup round trips, binary content, integrity tampering, format versions, path safety, case collisions, reserved names, and snapshot path conflicts.

## Preservation
- Built directly from Package59; all previous source files, editor features, SAF workflows, project archive flows, preview tools, and diagnostics are retained.
- Existing ZIP import/export remains available and unchanged as a separate workflow.

## Verification boundaries
- Static packaging checks only. Unit tests were added but not run.
- No `flutter pub get`, `dart format`, `flutter analyze`, `flutter test`, Gradle task, or APK build was run.
- SAF backup/restore, large-file behavior, Android document-provider compatibility, and failure rollback still require validation on a real Android device.
- The backup checksum detects accidental corruption but does not authenticate a backup against malicious modification.
