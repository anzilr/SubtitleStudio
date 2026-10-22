# SubtitleStudio — CP90 R13: Direct controller Save and navigation consistency

Date: October 22, 2026  
Branch: `refactor/riverpod-architecture`

## Issue

`EditLineController.saveSubtitle()` retained a legacy independent,
boolean-only Isar update path even after CP90 R7/R8/R12 introduced
transactional draft saving with committed cue/index/order results. That
legacy method could leave Riverpod on a stale selection when timing edits
moved a cue, could commit without the edited-null/empty and original
metadata policies of the shared path, and used a null assertion when
there was no pre-existing cue in new-subtitle mode.

The controller's independent `navigateToLine()` also fetched one row
instead of the full committed collection, discarded unsaved drafts, and
accepted late asynchronous results from older navigation operations.

## Implementation

- Route `saveSubtitle()` through `saveDraftLine()` and its established
  Isar/checkpoint transaction result. Preserve detached cue copies and
  original vs edited semantics; project the real post-sort selection.
- Validate the current start/end time formats and ordering synchronously
  before a direct Save; reject invalid edits without changing the database.
- Support a new unsaved cue by creating an in-memory draft and inserting it
  exactly once on the first successful Save. The persisted selected state
  no longer remains flagged as an unsaved new subtitle.
- Return success without writing an empty checkpoint when a previously
  saved cue has not changed.
- Replace row-only controller navigation with a fresh collection reload.
  Block navigation while the controller owns unsaved text/timing changes,
  leaving the draft available for explicit Save/Discard decisions.
- Use a route-independent request epoch for controller-only navigation:
  late previous loads cannot replace a more recently accepted cue or
  an externally synchronized Edit Line widget selection.
- Continue preserving project file path, source URI, encoding and macOS
  bookmarks, cue comments/marks/resolved status, edited null-vs-empty
  values, and V2 history. No `.msone` or Isar schema changes.

## Regression coverage

Six Isar-backed Riverpod controller integration tests in
`test/edit_line_controller_persistence_test.dart` cover:
- Blank edited cue and timing sort with detached before-state.
- Invalid timestamp rejection with no database changes.
- Dirty draft safety, navigation, Next/Previous boundaries.
- Refresh from external committed reorder.
- Stale async fetch superseded by newer route selection.
- First-time new-cue insert without repeating that insertion.

## Verification

Initial [Flutter CI run #39820593566](https://github.com/anzilr/SubtitleStudio/actions/runs/39820593566)
passed all **713 Flutter tests** but reported one unused-import warning in
the new controller integration test. This follow-up removes that warning and
uses a final Flutter-only gate to close the checkpoint with a clean analyzer.
Only `flutter pub get`, `flutter analyze`, and `flutter test` are
permitted in GitHub Actions; no native platform builds or cross-platform
matrix are requested. The final [Linux Flutter-only CI run #39821316874](https://github.com/anzilr/SubtitleStudio/actions/runs/39821316874)
completed successfully with **713 Flutter tests passed** and `flutter analyze`
reporting **No issues found**. Its source is commit
[`6b36836`](https://github.com/anzilr/SubtitleStudio/commit/6b368362c4594fbfa1e5187cb4cdd86458b80f4f).
This includes six new Isar/Riverpod integration tests. No native builds
or Windows/macOS host matrix were run.

## Remaining

CP90 remaining controller/UI responsibility and lifecycle audit, then CP91
Git-style visual checkpoint history and compact Edit Line UX; CP92 cleanup
and profiling; CP93 native device/project compatibility acceptance. The
previous hot-restart `media_kit` crash is no longer an active blocker,
according to user testing.
