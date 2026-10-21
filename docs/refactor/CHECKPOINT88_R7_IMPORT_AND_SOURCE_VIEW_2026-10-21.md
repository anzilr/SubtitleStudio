# CP88 R7 — Canonical subtitle import and Source View file identity

Date: October 21, 2026
Branch: `refactor/riverpod-architecture`

## Scope

CP88 R6 added `StudioPickedFileReference.accessLocator` without modifying legacy consumers. R7 migrates the subtitle **raw-byte preview/import** path and the Home **Source View** Android picker path to use a valid Android document locator rather than inferring a file from SAF's synthetic `/storage/...` display hint.

## Implementation

- Added `SubtitleImportFileReference.resolve(filePath:, safUri:, accessLocator:)`: categorizes locators with existing `StudioFileIdentity`. A real explicit SAF URI wins over display path; a direct `content://` source works even without separate `safUri`. Mismatched direct-document/source-grant pairs, unknown remote/opaque schemes and malformed document identifiers fail closed. It preserves original locator strings, never fabricating an Android filesystem path.
- Added injectable `SubtitleImportFileReader` and `SubtitleImportByteAccess`: document bytes are read through `SafFileHandler.readFileFromUri` **only on Android**, native filesystem bytes through `File(path)`, and `file://` inputs through decoded `Uri.toFilePath`. Revoked document access cannot fall through to the display hint.
- `pickSRT` now passes `accessLocator` as an additional field while retaining existing `filePath`, `fileName`, `safUri`, and `bytes` fields, so legacy saved file paths remain unchanged.
- `SubtitleImportOptionsSheet` remembers the actual locator for imports and uses the same guarded raw-byte reader for both preview and final import when raw bytes are not already supplied. The final import derives `contentUri` from the validated source, keeping existing `originalFileUri` metadata. It does **not** change existing subtitle encoding or database schemas (that is CP89).
- Home Source View uses `fileInfo.uri` as its route-owned `filePath` (and `safUri`), still passes the visible file name and already read text. It no longer asks Source View to re-open a synthetic filesystem path. Logs and read errors no longer expose raw provider document IDs or full source paths.

## Automated coverage

`test/subtitle_import_file_reader_test.dart` verifies:
1. Synthetic Android display hint + actual grant routes only through a document reader, preserving raw non-UTF8 bytes.
2. Direct `content://` input without separate SAF metadata.
3. Revoked documents never fall through to `File(displayPath)`.
4. Reject mismatched direct document/grant identities.
5. Reject unsupported remote/opaque locators and malformed grants.
6. Native POSIX and encoded `file://` source routing on desktop.
7. Reject Android SAF document reads on non-Android.

The existing Source View file-target, saved-grant repository and project import integration suites remain in the full Flutter gate.

## Compatibility and remaining CP88 work

The old `displayPath` field is kept as a legacy presentation/persistence hint, not rewritten in the Isar collection. `originalFileUri` continues to record the authoritative document identity for future access. A direct content URI opened by Home Source View now becomes that route's file identity; the display name remains separate.

The legacy `FilePickerSAF.pickFile` string-returning Android helper still returns a synthetic display path. R7 does **not** silently change that contract for unidentified downstream callers; follow-up CP88 R8 must audit these and move them to typed/URI APIs. Existing project/comments pickers on Android already use SAF bytes and on desktop native paths, but full device grant verification remains outstanding.

No desktop preview or CP86 waveform code is changed. This checkpoint requires **Flutter dependency resolution + analyze + test only** in GitHub Actions, never native platform builds. Android SAF and Windows native smoke tests remain deferred to physical device and local PC.

## Quality gate

Final Flutter-only CI run and exact pass count will be added after successful verification.
