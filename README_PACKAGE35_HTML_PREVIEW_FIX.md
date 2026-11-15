# Package35 — HTML Preview SAF Read Fix

## Root cause addressed
The previous recursive SAF copy routine only recorded the target HTML path after its bytes were read successfully. A read exception was swallowed as if it were an ordinary optional-resource failure, causing the UI to report that the HTML file did not exist.

## Changes
- Identify and record the target HTML path before reading its bytes.
- Compare SAF document URIs exactly first, then compare decoded URI forms to tolerate provider encoding differences.
- If the target HTML is found but cannot be read, stop with a specific permission/read error instead of the misleading "not found" message.
- Continue past unreadable non-HTML resources and log them, so one missing optional image/script does not prevent the page from opening.
- Preserve the original relative folder structure for CSS, JavaScript, images, and nested HTML files.
- Improve the not-found message with actionable guidance.

## Build
Cloud workflow remains `flutter pub get` then `flutter build apk --release`. No test or analyzer steps are added.
