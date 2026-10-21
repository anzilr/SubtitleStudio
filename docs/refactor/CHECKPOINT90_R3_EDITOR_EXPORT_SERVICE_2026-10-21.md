# SubtitleStudio — CP90 R3: Editor Save As export ownership

Date: October 21, 2026
Branch: `refactor/riverpod-architecture`
Verification: Linux/Windows/macOS Flutter gates passed

## Findings and correction

The `ExportBottomSheet` had direct desktop file writes, duplicated Android/iOS
SRT compilation, constructed filenames from unchecked user input and used the
collection's embedded subtitle list, which might be stale after Editor/Source
View edits. The folder control was populated with the full source filename;
a canceled picker could throw because it force-unwrapped null. Rename-to-an
existing destination was also allowed to overwrite without an explicit
Replace decision.

CP90 R3 introduces an injectable `EditorExportService` and typed
`EditorExportPlan` that own:

1. The output filename (including the established `.MSone.srt` and
   `.original.srt` conventions), with single-component validation for
   platform separators, reserved punctuation and empty names.
2. Strict encoding before a picker or file write; deliberately empty edited
   cue text remains empty and original-only export remains explicit.
3. Typed local folder resolution including percent-escaped `file://` paths,
   no Android `content://` or remote path reinterpretation, and parent-folder
   suggestions only from an authoritative native/file URI.
4. A desktop write boundary with explicit Replace permission. Renaming to a
   different existing name returns an already-exists result; it does not
   silently overwrite that file. Actual writer errors propagate to UI.

The Save As sheet handles confirmation, notifications and platform pickers;
Android SAF and iOS file-provider pickers receive the same prevalidated byte
array. The Editor synchronizes Source View first, reloads current subtitle
lines and passes them directly to the export sheet. Canceling a folder picker
is now a no-op. Concurrent Save As taps are disabled while an export runs.

The mobile visual layout, Isar collections, `.msone` schema, checkpoint
history and deferred waveform/native-media work are unchanged.

## Regression coverage

`test/editor_export_service_test.dart` covers filename/tag conventions,
traversal rejection, UTF-16BE BOM with a blank edited cue, original-only
output, nonrepresentable encodings before I/O, existing destination safety,
rename collision safety, missing/remote/SAF folders, true native source
parent suggestions, Windows escaped file URIs and real-host byte export.

Linux full Flutter `pub get`, `analyze`, `test` and the Windows/macOS targeted
file-sensitive Flutter workflow are requested through separate markers.
Actions must **not build Android, Windows, Linux, macOS or iOS apps**.

## Automated verification, October 21

- [Linux full suite](https://github.com/anzilr/SubtitleStudio/actions/runs/39654883752):
  **661 Flutter tests passed**, analyzer clean.
- [Windows/macOS targeted workflow](https://github.com/anzilr/SubtitleStudio/actions/runs/39654883751):
  Windows and macOS each **130 targeted tests passed**, analyzers clean.
- These are Flutter host tests only, not application builds or native file
  provider/sandbox integration acceptance.

## Deferred/native acceptance

- Android real SAF Save As, cancellation, permission and round-trip.
- iOS file-provider byte export on device/simulator. Tests model the bytes,
  not native picker mechanics.
- Desktop file-system sandbox/grant, collisions and chosen folder behavior on
  real Windows, Linux and macOS installations.
- Structured export emits canonical SRT newline formatting. Raw Source View
  retains byte/newline fidelity; preserving original newline style through
  every structured edit/export requires a separate compatibility design.
- Continue CP90 media/controller isolation, CP91 visual checkpoint history,
  CP92 cleanup/performance and CP93 acceptance before production desktop
  workspace integration.
