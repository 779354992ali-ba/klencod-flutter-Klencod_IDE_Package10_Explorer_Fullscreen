# Package59 — Project Intelligence

Package59 extends Bisho IDE with project-level static insights and safe change comparison while preserving the Package58 baseline.

## Project quality panel
Open the dashboard and choose **فحص المشروع**. The report analyzes the source text currently present in open tabs. It includes:

- unresolved local imports (Dart, JavaScript and TypeScript-family sources)
- package imports missing from an available `pubspec.yaml`
- TODO/FIXME/XXX maintenance markers
- empty catch blocks
- likely hard-coded secrets (the value is never copied into the report)
- Dart `print()` calls
- a Flutter entrypoint hint when a pubspec is open without `lib/main.dart`
- possibly unused direct dependencies, as advisory hints only

The panel shows severity totals and file/line references. It does not edit or save files. Because it uses open tabs, it must not be interpreted as a complete scan of the SAF project tree. Heuristic findings require developer review.

## Snapshot and change comparison API
`ProjectChangeTracker` accepts a map of relative file paths to text, creates immutable snapshots, and compares snapshots to classify added, modified, deleted and unchanged files. It is storage-agnostic and can be fed by a SAF reader or another project source. Paths are validated before snapshot creation. The FNV-1a fingerprint is for deterministic change detection only and is not a cryptographic integrity or security signature.

## Tests
New tests cover import resolution, dependency hints, maintenance/security heuristics, generated-folder exclusion, UTF-8 byte sizing, snapshot comparisons, and path validation. They are included but have not been run in this package preparation.
