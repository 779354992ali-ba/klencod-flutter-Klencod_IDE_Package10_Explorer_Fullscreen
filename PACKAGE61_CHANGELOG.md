# Package61 Changelog — Text Diff & Review

Package61 continues directly from Package60 and preserves its project backup/recovery workflow and all earlier files.

## Added
- `ProjectTextDiff`: dependency-free line-oriented diff engine with added, removed, and unchanged records.
- Old/new line-number mapping for every unchanged line and the relevant side for additions/removals.
- CRLF and classic CR newline normalization.
- Bounded LCS processing (maximum 250,000 table cells) with a prefix/suffix fallback for larger inputs to protect mobile memory.
- Dashboard tool **مقارنة النص**. It accepts a pasted earlier version, compares it to the current editor buffer, and displays colored additions/removals and counts.
- Focused unit tests for line classifications, line numbers, newline normalization, empty/identical input, whitespace sensitivity, and the large-input fallback.

## Safety and behavior
- The comparison is read-only; it never writes to the active tab or project files.
- The previous text is supplied by the user in the dialog and is not persisted.
- The large-input fallback intentionally reports the changed middle region as a replacement when exact LCS is too expensive; the UI labels this approximate mode.

## Verification status
- Static project/archive checks are recorded in `PACKAGE61_TEST_REPORT.md`.
- Flutter/Dart commands and unit tests were not run. No APK was built.
