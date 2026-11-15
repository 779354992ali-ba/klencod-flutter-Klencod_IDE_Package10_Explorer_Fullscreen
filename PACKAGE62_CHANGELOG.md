# Bisho IDE — Package62 Changelog

## Project backup repository and restore points

- Added `ProjectBackupRepository`, a versioned catalog for immutable project backup snapshots.
- Backup export now stores a restore point under `.bisho-backups/` in the active project through Storage Access Framework (SAF), while retaining the existing portable JSON export flow.
- Added a chronological restore-point history with per-snapshot metadata (timestamp, file count, directory count, total project bytes).
- Added explicit restore-point deletion with confirmation. The catalog is updated before deleting the corresponding snapshot file.
- Added restore of a selected snapshot after checksum validation. Restore always creates a new project directory and never overwrites an existing project.
- Added comparison between two saved snapshots, reporting added, removed, changed, and unchanged files based on per-file checksums.
- Excluded `.bisho-backups` from project traversal so repository contents are not recursively backed up.
- Retention is capped at 20 snapshots. Old snapshots are pruned only after the updated catalog has been written.
- Added unit tests for catalog serialization, invalid metadata, retention, manifest integrity, and snapshot comparison.

## Compatibility and safety

- Preserved Package61 text-diff features, existing portable backup format, and existing restore action.
- The catalog and snapshot files are stored through SAF; no raw filesystem path assumptions were introduced.
- FNV-1a 32-bit is used only for accidental-corruption detection, not cryptographic authenticity.
