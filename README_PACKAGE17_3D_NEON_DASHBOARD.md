# Bisho IDE Package 17 – 3D Neon Dashboard

## Changes
- Moved the legacy horizontal editor action strip out of the main screen.
- Consolidated project, file, editing, navigation, font, completion, preview, diagnostics, theme and extensions shortcuts in the scrollable dashboard below the file/language header.
- Added layered glossy icon treatment with gradient surfaces, highlights, shadows and neon glow.
- Added an animated Bisho IDE launch screen with logo entrance, glow effects and a smooth fade/scale transition into the existing editor.
- Preserved the existing editor controllers, tabs, SAF project/file handling, save/export operations, preview routes and editing services.

## Notes
- The 3D appearance is rendered natively with Flutter gradients, stacked icon highlights and shadows; no network, remote icon service, or additional package is required.
- Existing feature handlers are reused. Some existing shortcuts such as theme, extensions and quick tools retain their original current behavior.
- Build using the existing Klencod Flutter workflow.
