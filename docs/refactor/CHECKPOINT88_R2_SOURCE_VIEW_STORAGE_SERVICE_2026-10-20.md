# CP88 R2 — Injectable Source View storage boundary

Date: 2026-10-20
Active branch: `refactor/riverpod-architecture`
Goal: finish reusable cross-platform application core before desktop UI

## Changes

Source View previously contained `File(config.filePath)`, Android `MethodChannel` SAF reads, direct `SafFileHandler` writes and "Save As" document creation within its Riverpod controller. R1 introduced the typed `SourceViewFileTarget` identity. R2 now extracts runtime storage from the presentation/controller layer:

- `SourceViewFileAccess` exposes typed `read`, `write`, `createDocument` and `writeCreatedDocument` methods. A Riverpod `sourceViewFileAccessProvider` permits test overrides and future platform-specific implementations.
- `SourceViewDeviceFileOperations` isolates Android `readFileFromContentUri`, existing `SafFileHandler` methods, and native Dart `File` access. No new Android platform channel, dependencies, Isar schema or preferences keys are introduced.
- `SourceViewFileAccessImpl` prefers the document URI on Android; on provider failure or empty data, it may use **only** the explicitly identified local native source file. Direct `content://`, remote URLs, file URIs and opaque non-files never become `File(locator)` fallback paths.
- Saved writes retain the original-SAF-first and existing-local-cache fallback distinction. Saves cannot create a new unintended local file in place of a missing original. Created-document writes validate `content://` identities before they reach the existing SAF writer.
- Source View's own `SourceViewController` retains source text, parsing, raw-edit state and encoding decisions, but no longer knows how to read, write or create native or SAF files. Save/reload state remains on the current route.
- Logging no longer derives source document identifiers as filenames from the original path when no explicit user-facing name is available.
- `test/source_view_file_access_test.dart` uses a fake storage backend to test SAF-first read/write, revoked access to a direct content URI, native-cache fallback, invalid and absent file locators, non-Android behavior, Save As cancellation, and refusal to write to invalid created-document destinations.

[Storage code](https://github.com/anzilr/SubtitleStudio/commit/137ef971b70fa1f83d6be4081d70030416ed9735) · [CI/test matcher fix](https://github.com/anzilr/SubtitleStudio/commit/a87ca941ccdfd484705325d85fc0eac27f48cb3b)

## Deliberately deferred and acceptance limits

- Existing SharedPreferences `saf_uri_${filePath}` storage remains directly in the controller; migrate via a testable access-grant preference repository in **CP88 R3**, retaining compatibility with old keys and checking mismatched/revoked grants.
- Source View still uses UTF-8/Latin-1 fallback; unified encoding/BOM preservation and Save As parity belong to **CP89**. No claim of lossless encoding across code pages yet.
- Android native permission revocation, real direct-document imports and writes, Windows/file-URI handling and consistency with secondary subtitle/project import remain pending platform qualification.
- Existing full-screen navigation/gesture fix remains unaffected; frozen CP86 progressive waveform branch is not merged.
- Only Flutter analyzer and tests run in GitHub Actions. Physical Android and desktop builds must be run locally. Automated tests prove Dart-side routing and fallback, **not** device-grant behavior.

## R2 test outcome

Initial Flutter-only Actions run [39481454982](https://github.com/anzilr/SubtitleStudio/actions/runs/39481454982) found an undefined convenience matcher `throwsFileSystemException`; this was corrected to `throwsA(isA<FileSystemException>())` alongside import cleanup. Final rerun: [39481786195](https://github.com/anzilr/SubtitleStudio/actions/runs/39481786195). Record final count and analyzer result after successful completion.

## Next active sequence

CP88 R3: extract the saved SAF locator preference storage, inject it through Riverpod, preserve existing preference keys and validate document-to-grant association. Continue converging file-access boundaries for import, video and secondary subtitles. Then CP89 encoding. No further waveform work is planned before CP93 and the desktop UI.
