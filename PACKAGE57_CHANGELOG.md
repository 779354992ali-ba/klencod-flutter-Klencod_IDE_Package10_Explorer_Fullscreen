# Bisho IDE Package57

## Preserved baseline
- Built from the complete Package56 Development Continuation archive after path-level comparison with the Package55 archive.
- No Package56 baseline paths were intentionally removed.

## Added
- Centralized filename resolution is now shared by the editor language resolver, explorer file badges, and editor tabs.
- Expanded extension mappings and filename tests.
- Basic/integrated project mode and language-aware template selection.
- Flutter: multi-page, login, Firebase setup placeholder/instructions, and localization resource templates.
- Web: multi-page and dashboard resources.
- Python: CLI, Flask, and FastAPI starter layouts.
- Java/Kotlin: multi-file and native Android Gradle/Activity templates.
- SAF recursive explorer copy and move, with destination collision protection and open-tab URI remapping.
- Project health diagnostics and pre/post repair reports; selectable Android/Gradle and Flutter entry-point repair.
- New project health analyzer tests.

## Safety
- Existing project files are not overwritten by the additive repair workflow.
- Copy/move rejects an existing same-name destination. Move completes the copy before deleting the source.
- GitHub, preview, SAF persistence, editor tabs, and Package56 functionality remain in the baseline.

## Verification status
- No Flutter commands or APK build were run, per request.
- Added tests are included but have not been executed.
- Device SAF operations, Gradle wrapper execution, and generated native Android projects remain unverified in this environment.
