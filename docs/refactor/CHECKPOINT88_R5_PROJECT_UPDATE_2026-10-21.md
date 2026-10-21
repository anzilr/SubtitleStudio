# CP88 R5 — Typed existing-project file update boundary

**Date:** October 21, 2026
**Branch:** `refactor/riverpod-architecture`
**Status:** CP88 R5 Dart/Flutter quality gate **PASS**; native Android and Windows acceptance outstanding.

## Problem and scope

Existing `.msone` project updates in `ProjectFileService.updateExistingProject` previously checked for `content://` only when `Platform.isAndroid`, returned false on iOS, and otherwise invoked `File(projectFilePath).writeAsString` without first classifying the persisted locator. This could mishandle `file://` URIs, attempt desktop filesystem operations against unrelated URI schemes, and create a missing original file when the user expected an update rather than Save As.

The project document codec, checkpoint history, Isar records, original project locator and new-project creation APIs are unchanged.

## Implementation

- New injectable `ProjectDocumentUpdateService`, with `ProjectDocumentUpdateStorage` and the default device adapter.
- Classifies every existing-project locator through shared `StudioFileIdentity`.
- Routes Android `content://` documents exclusively through `SafFileHandler.writeSafUri` and never `File(contentUri)`. Non-Android cannot write Android document locators.
- Routes native POSIX, relative, Windows drive and UNC paths through an existing-file-only native writer; missing original returns false instead of creating a replacement.
- Converts `file://` URIs with `Uri.toFilePath` using the current platform before native writing.
- Rejects malformed, unsupported remote and opaque locators without writing. Preserves existing iOS Save As behavior.
- Returns a clear failure result on local file I/O and SAF provider failures, without logging source paths or document IDs.
- Reuses the existing `ProjectFileService.updateExistingProject(content:, projectFilePath:)` public signature; an optional typed updater permits testing without platform channels.

## Tests

`test/project_document_update_service_test.dart` uses a fake platform storage adapter to cover direct native and Windows drive/UNC locators, converted file URIs, Android SAF routing, wrong-platform and iOS rejection, malformed and remote source refusal, unavailable existing document, and `ProjectFileService` delegation.

A real temporary desktop file is also updated to verify UTF-8 project data round-trips and to assert a missing existing target is **not** created.

## Limits and next work

This is a routing and error-handling refactor, not a new file format or conversion feature. True Android SAF read/write/revocation, non-UTF-8 native filesystem encodings, Windows native dialogs, app-level Save As prompts, and real `.msone` roundtrip under Android/Windows still need local acceptance.

**CP88 next:** complete audit of project Save As/new-file selection, import path vs document URI identity, video bookmark/reference metadata and remaining direct `File(locator)` use; then CP89 broader subtitle encoding. No changes to `feature/desktop-workspace-preview` or the frozen progressive waveform branch.

Only `flutter pub get`, `flutter analyze` and `flutter test` run in GitHub Actions; no platform builds.

## CI

[Final CP88 R5 Flutter-only CI 39615780906](https://github.com/anzilr/SubtitleStudio/actions/runs/39615780906) — **SUCCESS** on October 21, 2026: **587 Flutter tests passed**, and `flutter analyze` reported **No issues found** (zero errors, warnings or informational lints). Only Flutter dependency resolution, analysis and tests ran; **no platform builds**. The first run [39615099160](https://github.com/anzilr/SubtitleStudio/actions/runs/39615099160) passed 587 tests but flagged an `unawaited_return_in_try_block` warning; this was fixed by awaiting the file-URI update inside the `try` block and verified in the final run.
