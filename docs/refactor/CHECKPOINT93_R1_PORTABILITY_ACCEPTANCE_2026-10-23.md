# SubtitleStudio — CP93 R1: Project portability acceptance

Date: October 23, 2026  
Active branch: `refactor/riverpod-architecture`  
Status: automated checks passed; native device qualification outstanding

## Scope

CP93 is the core-refactor acceptance gate before wiring the separate desktop
workspace preview to real data and media. R1 adds cross-boundary compatibility
coverage, inventories existing safety tests, and prepares reproducible native
smoke steps. The feature implementation, Isar schema, Android SAF contract,
mobile layout, player lifecycle and `.msone` wire format remain unchanged.

## New project portability integration coverage

`test/cp93_project_portability_acceptance_test.dart` exercises these real
production boundaries together:

1. `ProjectDocumentBuilder.build` exports a project with two cues, one
   deliberately empty and the other Malayalam/multiline, comments, edit
   markers, and UTF-16LE BOM encoding.
2. `ProjectDocumentCodec.encode/decode` round-trips the portable `.msone`
   payload, including a detached HEAD, two named branches and a bookmark.
3. `SessionProjectImportRepository.importAsNewSession` writes the archive into
   an isolated real Isar database, remaps parent/checkpoint IDs, and restores
   the original data and each named reference to its correct destination.
4. A separate legacy v1.0 `.msone` fixture without checkpoint/ref sections
   imports an explicitly empty cue, preserves its empty edit and UTF-8 BOM
   preference, and does not fabricate history.

The test is synthetic and contains no personal subtitle content. It is not a
substitute for testing SAF grants or app lifecycle on the actual device.

## Existing automated gates retained

| Acceptance area | Established test coverage |
| --- | --- |
| Isar session/project import and recovery | `session_project_import_repository_integration_test.dart`, `project_repository_integration_test.dart` |
| Checkpoint integrity, HEAD, branches, bookmarks | `checkpoint_*`, `history_ref_persistence_integration_test.dart` |
| Encoding and blank subtitle preservation | `srt_encoding_integration_test.dart`, `subtitle_import_file_reader_test.dart`, `subtitle_encoding_decoder_test.dart` |
| Android document identity and grant boundaries | `saf_video_picker_identity_test.dart`, `source_view_saf_grant_repository_test.dart` |
| Editor saves, unsaved dialog, MSone route return | `editor_direct_save_service_test.dart`, `edit_line_unsaved_changes_dialog_test.dart`, `msone_submission_flow_navigation_test.dart` |
| Waveform cache/source revision and lifecycle | `waveform_*` regression tests |

## Native smoke checklist — awaiting the user/device

Use a clean checkout of `refactor/riverpod-architecture` at the verified
CP93 commit on the user's Windows machine. Keep separate backups of any real
projects and pick a disposable SRT/project for mutation tests. Do not use a
personal production project as the only copy.

### Android (CPH2381 or other supported phone)

1. Run `flutter pub get`, then `flutter run -d <device-id>` (or use
   `tool/run_android_clean_debug.ps1` with the device ID). Cold launch.
2. Open an Android SAF SRT with empty subtitle cues and a non-UTF-8 encoding.
   Check line count and blank text before and after saving/reopening.
3. Create/edit checkpoints, name a branch and bookmark, detach HEAD, save
   `.msone`, close and re-import into a **new** session. Compare cue contents,
   edit state, history names, attachment state and selected checkpoint.
4. Open a SAF-picked video, play/pause, enter/leave Edit Line and Source View,
   visit MSone submission and return with system Back. Verify Editor and Home
   accept taps and video can resume without duplicate-player-key errors.
5. Background/foreground and reopen the same session; verify document grants
   and media access survive, with no loss of original subtitles.
6. Capture a cold-process log if any crash/freeze occurs, with steps, device,
   Android version and last visible UI state. Avoid posting private media
   paths or full personal subtitle text.

### Windows desktop

1. Run `flutter pub get`, then `flutter run -d windows` locally (no CI build).
2. Open/import a disposable legacy `.msone` and standalone SRT in UTF-8 BOM,
   UTF-16 BOM and Windows-1252; save/reopen and compare bytes/empty cues.
3. Exercise Save, Save As, import, overwrite and cancelled picker flows; confirm
   no false success or damaged original file.
4. Repeat the checkpoint branch/bookmark save/reopen test, video playback,
   Source View roundtrip and Edit Line unsaved-change dialog.

Linux/macOS/iOS runtime qualification is still platform-dependent; run their
native smoke gate on actual supported hosts/devices when available. A Linux
GitHub runner executing Flutter tests is **not** a substitute for those app
builds or media/file-picker workflows.

## Acceptance rule

CP93 shared core is **not yet declared native accepted**. Automated Flutter
analysis and the full suite must pass first. Subsequent native evidence must
be recorded separately with exact device/platform and test outcome, with any
P0/P1 defect resolved before production desktop integration is unblocked.

## Automated verification — October 23, 2026

- [Linux Flutter quality gate 39950148526](https://github.com/anzilr/SubtitleStudio/actions/runs/39950148526):
  **787 tests passed, zero analyzer issues**.
- Code/report commit: `e902a83bbf87a2813890cb3c19396bb8b4ac7bc6`.
- `git diff --check`: clean before publishing.
- No Android, iOS, macOS, Windows or Linux app builds in CI.
- Native Android/Windows smoke acceptance remains **pending**; the green
  Linux gate does not qualify media rendering, gesture recovery or SAF grant
  persistence on actual hardware.
