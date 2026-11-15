# Package36 — Import Existing Project

## Real Android import workflow
- Added a dedicated "استيراد مشروع" dashboard action with a folder-upload icon.
- Shows a clear confirmation explaining that import links an existing folder; it does not duplicate, move, or overwrite user files.
- Opens Android's Storage Access Framework directory picker through the existing `SafFileService.pickProjectFolder()` implementation.
- Requests write access and persistable URI permission (already implemented by the SAF service).
- Uses the existing project-opening pipeline to save the selected folder URI/name in SharedPreferences, update the active workspace, reset selected subfolder state, and refresh the explorer.
- Verifies the selected root with `stat` and reads its top-level children before reporting successful import.
- Existing tabs retain their original document URIs; existing unsaved-tab confirmation remains in place.

## Important behavior
This imports an existing folder into Bisho IDE's workspace by linking its Android document-tree URI. It does not extract ZIP archives. The selected folder remains at its original storage location and edits are saved there using SAF.

## Build workflow
`flutter pub get` then `flutter build apk --release`. No tests or analyzer steps are added to GitHub Actions.
