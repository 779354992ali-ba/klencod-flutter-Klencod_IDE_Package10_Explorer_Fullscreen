# Bisho IDE — Package63 Changelog

## New-project navigation and black-screen fix

- Fixed the new-project completion flow: opening the generated entry file no longer pops the wizard route from the parent editor context.
- The project wizard remains responsible for closing its own route exactly once after `onCreated` completes. This prevents the extra pop from removing the IDE screen and exposing the previous route (which appeared as a black screen).
- Added an explicit `closeOverlay` option to `openProjectFile`; normal explorer navigation retains its previous drawer/dialog behavior while automatic entry-file opening does not close a parent route.
- Kept project URI/name persistence, explorer activation, entry-file discovery, and tab creation in the existing SAF flow.

## Exit protection and session durability

- Added a confirmation dialog for Android/system Back from the main IDE.
- Exit choices include cancel, save linked project files and exit, or exit while retaining the recoverable editor session.
- The dialog reports the number of unsaved tabs. Tabs without a linked project file remain included in the saved editor session and are not falsely described as written to disk.
- Made concurrent session-save requests await the in-flight write and perform a final follow-up write when needed, so exit does not race a pending preference save.
- Preserved lifecycle-triggered session saving and existing tab/cursor restoration.

## Compatibility

- Package62 project backup repository, restore history, comparison, and all existing source files are retained.
- No dependencies were added.
- Package version advanced to `1.0.0+63`.

