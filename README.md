## Package 55

Package 55 hardens GitHub uploads, Flutter project preflight, full-project ZIP export limits, and one-build CI behavior. See `README_PACKAGE55_HARDENED_GITHUB_ARCHIVE.md` and `PACKAGE55_TEST_REPORT.md`.

# Klencod IDE – Package 15

Package 15 adds a dedicated full-screen editor route for Android phones. Tap the `</>` editor icon in the top app bar to open the active file in a separate screen with a maximized editing area. The same editor controller is retained, and Back returns to the main IDE without losing the current editing state.

See `README_PACKAGE15_FULLSCREEN_EDITOR.md` for details.


## Package 37 — Full project ZIP

Package 37 adds complete recursive project ZIP import/export, retains single-file export, and runs analyzer/tests before the CI APK build. See `README_PACKAGE37_PROJECT_ARCHIVE.md` for details and the remaining Flutter Android platform-generation limitation.

## Package 52 — One-build pipeline

Package 52 hardens the GitHub Actions release pipeline to run dependency resolution, Android project checks, Dart analysis, tests, and one universal release APK build. It verifies the APK and uploads it with a SHA-256 checksum. See `README_PACKAGE52_ONE_BUILD_PIPELINE.md` and `PACKAGE52_TEST_REPORT.md` for exact scope and validation limits.


## Package 53 — In-app project creation preflight

Package 53 adds a complete generated-file-plan validation pass before the wizard creates any SAF project folders. See `README_PACKAGE53_PROJECT_CREATION_PREFLIGHT.md` and `PACKAGE53_TEST_REPORT.md`. This is an incremental source update, not a claim that local Flutter Android generation, Python execution, or real-device SAF testing is complete.


## Package 54 — GitHub connection and local Android project generation

Package 54 adds a Flutter Android platform template (Gradle settings/build files,
wrapper scripts and wrapper JAR, manifest, styles, and Kotlin MainActivity) that
is written into the selected SAF project folder when the Flutter project wizard
finishes. It also adds GitHub PAT connection with Android secure storage, account
verification, private repository creation, recursive project upload using the Git
Data API, and automatic workflow dispatch. Upload excludes local SDK paths,
keystores, `.env`, and generated build/cache directories. The app limits automatic
upload to 1,200 files, 50 MiB total, 10 MiB per file, and 32 directory levels.

GitHub linking currently uses a Classic Personal Access Token (scopes `repo` and
`workflow`), not OAuth browser sign-in. GitHub account creation is not automated.
The repository is created as private. The Android platform is a generated
Flutter-compatible template and still requires validation on a real Flutter SDK
and Android build runner before it can be declared production verified.


## Package56 — Smart project scaffolding and language identities

Package56 builds on Package55 and adds:

- A centralized, offline-safe language identity catalog for all 18 project wizard languages.
- Consistent branded language marks in the project language picker and selected-language settings.
- An additive Flutter Android repair workflow in Build & Preview.
- The repair workflow creates missing Android folders, Gradle configuration, manifest,
  MainActivity, styles, wrapper properties, and bundled Gradle wrapper files.
- Existing files are never overwritten. Existing entries are reported as present;
  name/type collisions are reported as conflicts.
- A repair report lists created entries, already-present entries, and conflicts.

The repair workflow requires a writable SAF folder permission. It does not download
Gradle distributions or Flutter SDK files; Gradle downloads its configured distribution
when a build is run. It repairs the local Android platform scaffold only.

Validation status for this archive:
- Source-level structural checks are performed during packaging.
- Flutter analyze, Flutter tests, Android APK build, and device-level SAF behavior
  must still be run in a Flutter-enabled environment before release.


## Package 57 — Project templates, diagnostics, and explorer operations

Package57 preserves the complete Package56 baseline and adds:

- Expanded centralized filename-to-language identities, including additional JS/TS, shell, PHP, Python, and configuration extensions. The editor language resolver now uses the same catalog as tabs and explorer badges.
- Project mode selection (basic/integrated) and language-aware template selection. Added Flutter multi-page/login/Firebase-setup/multilingual scaffolds, Web multi-page/dashboard files, Python CLI/Flask/FastAPI scaffolds, and Java/Kotlin multi-file/native Android starter layouts.
- Native Android Java/Kotlin templates include Gradle configuration, manifest, Activity source, and wrapper files copied from bundled assets.
- SAF-based recursive copy and move actions in the explorer. Move copies the full tree before deleting the source and remaps open tab and selected-folder URIs. Existing destination names are not overwritten.
- A non-destructive Flutter project health analyzer and pre/post repair reporting. The repair screen offers separate Android/Gradle and Flutter entry-point repair selections. Missing files are created only when absent; existing content is preserved.
- Added unit tests for project health diagnostics and expanded filename identity cases.

Validation: tests were added but not run. As requested, `flutter pub get`, `flutter analyze`, `flutter test`, and APK builds were not run. SAF behavior, Gradle compatibility, native Android templates, and the new template flows still require device/toolchain validation.


## Package58 — Project creation and SAF reliability hardening

Package58 improves rollback when project generation fails, recursive SAF cleanup for explorer copy/move, bounded tree traversal, and portable filename validation across common file systems. Regression tests were added but not run. See `README_PACKAGE58_RELIABILITY_HARDENING.md` and `PACKAGE58_CHANGELOG.md`.

## Package 60 — Verified project backup and recovery

Package60 adds a versioned full-project backup format with binary assets, empty directories, per-file integrity checks, strict path validation, and bounded resource use. Backups can be restored into a new SAF folder without overwriting existing files. See `README_PACKAGE60_BACKUP_RECOVERY.md` and `PACKAGE60_CHANGELOG.md`. Flutter tests and Android SAF device validation have not been run.

Package60 packaging checks and explicit unexecuted-test boundaries are recorded in `PACKAGE60_TEST_REPORT.md`.


## Package61 — Text Diff & Review

Package61 adds a line-by-line comparison tool for the active editor tab. Open **الأدوات** ثم **مقارنة النص**, paste the earlier version, and review additions, removals, unchanged lines, and line-number pairs. The comparison is read-only and does not modify the editor buffer. Large inputs switch to a bounded-memory prefix/suffix fallback rather than allocating an unbounded LCS matrix. See `README_PACKAGE61_TEXT_DIFF.md` for details.


## Package62 — مستودع النسخ ونقاط الاستعادة

- حفظ نسخ احتياطية متعددة داخل مجلد `.bisho-backups` في جذر المشروع عبر SAF.
- سجل زمني يعرض تاريخ كل نقطة استعادة وعدد الملفات والمجلدات والحجم.
- استعادة نقطة محددة إلى مجلد مشروع جديد؛ لا تستبدل الاستعادة ملفات مشروع قائم.
- مقارنة نسختين محفوظتين على مستوى الملفات: المضافة والمحذوفة والمعدلة والثابتة.
- تحقق من بصمة manifest قبل المقارنة أو الاستعادة، وفهرس بإصدار مستقل وحد أقصى 20 نقطة.
- لا يُضمّن مجلد المستودع داخل النسخ اللاحقة، لتجنب تضخم النسخ بصورة متكررة.
- حذف نقطة الاستعادة يتطلب تأكيدًا، ويُحدّث الفهرس قبل حذف ملف النسخة.

راجع `README_PACKAGE62_BACKUP_REPOSITORY.md` للتفاصيل والقيود.
