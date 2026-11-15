# Bisho IDE Package58

## Reliability hardening
- Added recursive SAF subtree cleanup for safe rollback of newly created folders.
- Added rollback to the project wizard when scaffold or bundled wrapper writes fail.
- Improved recursive explorer copy/move cleanup and bounded recursive traversal.
- Hardened generated path validation against case-only collisions, file/directory
  collisions across case variants, invalid portable filename characters,
  trailing dots/spaces, and reserved Windows device names.
- Applied portable filename validation to SAF child create/write/rename flows.
- Added regression tests; tests have not been executed.

## Verification status
- No Flutter dependency resolution, analysis, tests, or APK build was run.
- Real Android SAF provider behavior, especially recursive deletion, remains
  subject to device testing.
