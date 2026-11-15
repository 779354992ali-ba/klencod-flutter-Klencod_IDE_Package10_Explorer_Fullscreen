# Package60 — Project Backup & Recovery

Package60 adds a dedicated project backup workflow alongside the existing ZIP export/import features.

## Create a backup
1. Open a project folder in Bisho IDE.
2. Choose **نسخ احتياطي** from the tools dashboard.
3. Select where to save the generated `.bisho-backup.json` file.

The backup recursively includes project files, binary assets, and empty directories. Project-backed open tabs are saved first. If an unsaved standalone tab is open, the operation stops rather than silently excluding that work.

## Restore a backup
1. Choose **استعادة نسخة**.
2. Select a `.bisho-backup.json` file.
3. Select a destination parent folder through Android's Storage Access Framework.

The backup is validated before a destination is created. Restore creates a new project folder and never overwrites an existing project. If writing fails, the partial folder is removed when the SAF provider permits cleanup.

## Format and safety
- Versioned JSON manifest with Base64 file bytes, original byte lengths, and per-file FNV-1a checksums.
- Maximum 10,000 file/folder entries, 64 MiB per file, and 256 MiB total uncompressed file data.
- Rejects absolute paths, traversal segments, malformed paths, duplicate paths, case-only collisions, file/directory collisions, and common Windows-reserved names.
- Checksums are for accidental corruption detection, not cryptographic authenticity or encryption. Backups may contain source code, credentials, and other private data; store them securely.

## Scope and verification
The workflow reads and restores the complete selected SAF project tree. It does not automatically schedule backups or encrypt them. Unit tests were added but not run; Android SAF behavior and rollback must be tested on-device before production use.
