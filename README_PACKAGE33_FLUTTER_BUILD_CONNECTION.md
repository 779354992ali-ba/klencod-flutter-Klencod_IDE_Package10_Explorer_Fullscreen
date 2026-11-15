# Package33 — Flutter Project Detection & Real GitHub Actions Build Connection

## Implemented
- Flutter preview now receives the active SAF project folder and checks the actual root directory.
- Detects `pubspec.yaml` and verifies the Flutter SDK dependency before marking the folder as a Flutter project.
- Adds project-folder selection from the preview screen and refreshes detection afterward.
- Replaces the static disconnected placeholder with a GitHub Actions workflow-dispatch client.
- Accepts repository (`owner/repo`), workflow filename, branch, Flutter version, and a GitHub Personal Access Token.
- Sends a real `workflow_dispatch` request through GitHub REST API.
- Refreshes workflow runs, identifies the newly dispatched run, and displays run ID, status, conclusion, commit, branch, timestamp, and URL.
- Opens the actual GitHub Actions run page, where the uploaded APK artifact can be downloaded.
- The token is obscured, held only in memory for the current screen, never written to preferences, and cleared when the screen is disposed.
- Adds the Android INTERNET permission and `http` / `url_launcher` dependencies.
- For unsupported languages, displays a truthful capability dialog and provides a diagnostics action instead of implying that a runtime exists.

## Required GitHub token permissions
Use a fine-grained Personal Access Token scoped only to the target repository:
- Actions: Read and write
- Contents: Read (needed to inspect workflow/repository context)
- Metadata: Read (GitHub's mandatory repository metadata permission)

Never paste the token into chat, source code, or a public repository.

## Important behavior and limitations
- GitHub Actions builds the latest committed code in the selected remote repository/branch. It does not upload unsaved or local-only files from the phone.
- The workflow must exist on the selected repository's default branch and support `workflow_dispatch`.
- The workflow input `flutter_version` is sent as configured by the repository workflow.
- Successful builds are opened in GitHub Actions; the user downloads the APK from the workflow's uploaded artifact.
- The preview screen does not execute an APK inside Bisho IDE. It connects to a real remote build and opens the run page.
- A generic local compiler for Dart, Python, Java, C/C++, Rust, etc. is not included. Those languages remain editable and saveable; execution requires their actual runtime/toolchain. JavaScript/HTML/CSS preview paths already supported by the app remain available.
- No Flutter test/analyze commands were added to the cloud workflow.

## Manual checks still required
Build this package with the repository's GitHub Actions workflow. Verify:
1. `flutter pub get` resolves `http` and `url_launcher`.
2. APK release build succeeds.
3. A fine-grained GitHub token can dispatch the workflow.
4. The run appears and its URL opens.
