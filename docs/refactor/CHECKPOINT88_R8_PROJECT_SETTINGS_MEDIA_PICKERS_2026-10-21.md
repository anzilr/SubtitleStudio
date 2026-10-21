# CP88 R8 — Project Settings media picker identity

Date: October 21, 2026  
Branch: `refactor/riverpod-architecture`  
Parent: CP88 R7 `764d74d354c28de2f02ff22facc0816fe337383b`

## Path-only caller audit

Inspected `FilePickerSAF.pickFile`, `FilePickerConvenience.pickSubtitleFile`,
`pickMsoneFile`, `pickVideoFile`, `pickVideoFileWithInfo` and their actual UI
callers. The legacy Android string-only picker still produces a presentation
path; it is **not** a native path and must not be used for file access.

| Caller | Observed Android selection | R8 action |
| --- | --- | --- |
| Project Settings fallback video replacement | `PlatformFileHandler.readFile(video/*)` eagerly read the entire file, then persisted `fileInfo.path` (a synthetic display hint) | Use the existing URI-only `pickVideoFile` route and persist its validated `accessLocator` |
| Project Settings secondary subtitle replacement | Parsed the picked bytes correctly but persisted `fileInfo.path` | Persist `fileInfo.pickedReference.accessLocator` while retaining picked display name for parsing |
| Editor and Edit Line video pickers | Existing `pickVideoFile` returned the source URI | Validate its URI-only `SafFileInfo` as a typed picked reference without changing the returned string contract |
| Video subtitle extraction | Already requested URI-only video info, but accepted a display path as a fallback | Require validated `accessLocator` for FFmpeg; keep legacy `uri` and `displayPath` map keys |
| `.msone` project import and comment import | Android branches already read document bytes through `PlatformFileHandler.readFile`, without opening display paths | Preserve behavior; desktop picker continues to return a native path |
| Home Source View and SRT import | Canonical document reader and real URI introduced in R7 | No change |
| Video font picker | Android reads font bytes through SAF, stores an app-owned copy; string-only API used only in desktop branch | No change |
| Legacy string-only `pickFile` | Still returns Android synthetic display hint | Preserve signature for compatibility; do not advertise it as a storage locator |

## Changes

- `SafFileInfo.pickedReference(isFromSaf:)` validates the real URI/native
  locator against the reported picker platform, without reading large video
  bytes. Its diagnostics no longer include document URIs or display paths.
- Both video picker convenience APIs use this reference. Bad document/locator
  combinations fail closed and show a generic selection error.
- Project Settings fallback video selection is URI-only on Android (no full
  MKV/MP4 memory read) and retains native desktop path behavior. The shared
  picker also keeps the legacy fallback's WMV/FLV choices available.
- Project Settings secondary subtitle selection stores a real SAF locator for
  reopening, while continuing to parse in-memory bytes immediately. Canceling
  the native dialog no longer attempts `File(null)`.
- The video extraction path no longer falls back from an absent source locator
  to a synthetic display path. User-facing Android file-location text now says
  a display hint does not prove a real filesystem path.
- Removed raw picked media locations from affected debug/log messages.

## Regression coverage

`test/saf_video_picker_identity_test.dart` verifies:

1. Real SAF URI survives despite a synthetic `/storage/...` display hint,
   with `content == null` for a large URI-only selection.
2. Native Windows and POSIX paths remain byte-for-byte unchanged.
3. Missing, malformed and substituted SAF locators fail closed.
4. Content URIs and remote URLs cannot impersonate native picker results.
5. Picker diagnostic text does not expose the URI/display path.

Pre-existing `studio_picked_file_reference_test.dart` additionally covers
`PlatformFileInfo.pickedReference` for selected secondary subtitle bytes.

## Verification and outstanding acceptance

- Local `git diff --check`: passed.
- Flutter analyzer and tests: **pending GitHub Actions result**.
- Android physical-device checks: **not yet performed**. Reopen Project
  Settings with and without the Editor callback, select a large video, then
  relaunch to confirm the saved `content://` locator remains usable; similarly
  replace, relaunch and restore a secondary subtitle.
- Windows native checks: **not yet performed**. Verify file dialog cancel,
  real drive/UNC paths, video reopen and secondary-subtitle selection.

R8 is a scoped migration, **not final CP88 native acceptance**. The next
file-identity audit should cover intent-supplied project sources and legacy
saved display-only paths, with recovery instructions rather than guessing a
grant from a synthetic path. Retain `.msone` and Isar schema compatibility.

No platform builds belong in GitHub Actions; `flutter pub get`,
`flutter analyze` and `flutter test` only.
