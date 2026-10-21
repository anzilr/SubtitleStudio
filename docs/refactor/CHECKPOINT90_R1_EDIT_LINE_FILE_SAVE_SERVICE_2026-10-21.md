# SubtitleStudio — CP90 R1: Edit Line file-save ownership

Date: October 21, 2026
Branch: `refactor/riverpod-architecture`
Verification: pending GitHub Flutter analysis/tests, no platform builds

## Scope

This is the first CP90 extraction of mixed responsibility from Edit Line.

Before R1, `edit_line_persistence.dart` contained approximately 300 lines of
platform-specific writing and picking, repeated success dialogs, direct
`File.writeAsString` UTF-8 writes regardless of selected project encoding, and
an Android content-URI fallback to a possibly synthetic display path.

The new `EditLineFileSaveService` has two injectable I/O boundaries:

1. `SourceViewFileAccess` handles existing file or Android SAF document writes;
   known `file://` sources resolve to native paths at the I/O boundary.
2. `EditLineSaveAsPicker` handles Android SAF Create Document, iOS's byte-based
   file-provider picker, and desktop paths selected through the save dialog.

The service compiles **all** output bytes using the shared validated charset
codec before attempting any write or displaying the file picker. The existing
Isar file-path and original-document fields are only updated after Save As
returns a result and the existing repository accepts the metadata change.

An authoritative `originalFileUri` no longer redirects to `filePath` on an
access failure; `filePath` remains the compatibility fallback only when an
original URI is not stored. This prevents a revoked Android grant from
silently writing to a display hint or unrelated local file. No Isar schema or
`.msone` format changes were made.

Manual Save and navigation autosave now accept clearing previously entered
edited text, including an explicitly empty string. A checkpoint before-state
keeps the prior edited value, comment, mark and resolution metadata.

## Regression evidence and checks

- Empty edited SRT cue exported as blank, not replaced with original.
- UTF-16 BOM encoding, UTF-8 BOM real-file byte save.
- Nonrepresentable script aborts before any destination write or picker.
- Android content URI success and revoked-grant failure without writing the
  legacy cached path; absent original URI falls back to existing native path.
- Windows escaped `file://` locator, Save As cancellation and authority capture.
- Targeted Windows/macOS workflow includes `edit_line_file_save_service_test`.
- Only Flutter `pub get`, `analyze`, and `test` run in CI; no platform builds.

## Deferred / native verification

1. On Android, open an SAF subtitle, edit, enable direct-file save, and verify
   both authorized write and revoked-grant Save As prompt.
2. On iOS, verify file-provider Save As with encoded bytes and returned path
   handling. A Flutter fake adapter is not native iOS validation.
3. On macOS, verify a security-scoped bookmark-backed file and File Picker
   access; Windows/Linux verify existing file and Save As without truncation.
4. Retaining imported SRT line endings across structured Edit Line export
   still needs explicit persisted metadata/compatibility design. Raw Source
   View already preserves original newline style.
5. Full CP90 extraction of other Editor controller/media and Edit Line
   persistence methods remains underway.
