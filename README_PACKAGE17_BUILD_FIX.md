Bisho IDE Package 17 - Build Fix

Changes:
- Fixed the missing closing bracket for the main Column children list in lib/main.dart.
- Kept all existing project files and features unchanged.

Validation:
- Verified the edited Dart source has balanced (), [] and {} delimiters.
- A Flutter/Dart SDK was not available in the editing environment, so a full Flutter build was not run.
- Build the APK using the existing GitHub Actions workflow.
