# CP89 R2 — Edited subtitle export and encoding round-trip

Date: October 21, 2026

Branch: `refactor/riverpod-architecture`

Predecessor: CP89 R1 Source View encoding and raw-byte preservation.

## Problem and change

The Edit Line workflow can persist `edited == ''` to deliberately clear a
caption. The prior SRT compiler selected an edit only when the value was
nonempty, causing an explicitly cleared caption to export its original text.
That was a silent change in content and could expose material deliberately
removed from the edited subtitle.

- One shared SRT serialization path now distinguishes **no edit** (`null`,
  export original) from **empty edit** (`''`, export blank caption), while
  `forceOriginal` continues to export the original by explicit choice.
- Desktop `compileSrt` delegates to the same asynchronous extended encoding
  codec as Android SAF/iOS byte exports. Its entire result is validated
  **before** storage permissions, directory creation, write probe or existing
  file access. Unrepresentable text cannot truncate the existing destination.
- No Isar model/schema, `.msone` project format, platform permission contract,
  native media code, or appearance surface changed.

## Regression coverage

- Unit: `null` / explicitly empty / nonempty edits and `forceOriginal`.
- Host filesystem: desktop compilation byte-equivalent to shared serializer
  for UTF-8 BOM, UTF-16BE BOM and Windows-1252.
- Host filesystem: incompatible ISO-8859-1 output preserves the old bytes and
  does not create a previously absent destination directory.
- Isar integration: import a BOM or legacy-encoded SRT, persist its charset,
  edit one caption and clear another, reload from Isar, export and parse again.
- Platform-sensitive check: Linux full suite, Windows/macOS targeted file and
  encoding suite because this changes saving/export behavior. iOS policy is
  represented through existing adapters and cannot replace native iOS tests.

## Verification status

- Local diff review and whitespace check completed.
- Flutter/Dart SDK is unavailable in this workspace. The GitHub Flutter-only
  analyzer and test workflows are the validation gates for this checkpoint.
- The previous CP89 R1 platform-sensitive run completed Windows successfully;
  its macOS job was still queued at the start of R2.
- [Linux full Flutter CI run 39640233941](https://github.com/anzilr/SubtitleStudio/actions/runs/39640233941):
  **624 tests passed**, analyzer successful.
- [Platform-sensitive CI run 39640233399](https://github.com/anzilr/SubtitleStudio/actions/runs/39640233399):
  **Windows 80 and macOS 80 tests passed**, both analyzers successful.
- No native platform application builds were run in Actions.

## Remaining acceptance

1. Native Android SAF and iOS document-provider round trips; Windows/macOS
   real picker/save dialogs, file grants and app lifecycles (CP88/CP93).
2. Raw line-ending preservation on direct Source View saves is implemented in
   R1; import → database → editor → SRT compilation still normalizes its line
   endings. Supporting original newline preferences requires an explicit
   compatibility decision, not an unreviewed Isar schema expansion.
3. Additional native charset families and substitution-prone converters need
   platform-qualified fixture tests. Offer explicit UTF-8 conversion when
   selected code page cannot represent an edit.
4. CP90: continue isolating editor controller, UI, filesystem and persistence
   responsibilities before CP91 history/compact Edit Line UX, CP92 cleanup and
   CP93 core acceptance. Desktop UI remains an isolated design preview.
