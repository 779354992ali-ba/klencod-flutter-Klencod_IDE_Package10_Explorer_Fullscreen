# Bisho IDE Package 66 — Advanced Project Terminal

## Improvements
- Added quoted argument parsing with escaped quotes and validation of unmatched quotes.
- Added nested relative/absolute path resolution for file and directory commands.
- Added sorted `ls`, long listing, and bounded recursive `tree`.
- Added `head`, `tail`, `grep`, `find`, `wc`, and `stat`.
- Added `mkdir -p`, `write`, `append`, `cp`, and `rename`/`mv` for files.
- Added recursive `rm -r` with an explicit confirmation dialog and root protection.
- Added bounded command/output history, Ctrl+L clearing, and command suggestions.
- Added operation limits for recursive scans and output to protect mobile performance.
- Kept arbitrary host shell execution disabled and documented honestly.
