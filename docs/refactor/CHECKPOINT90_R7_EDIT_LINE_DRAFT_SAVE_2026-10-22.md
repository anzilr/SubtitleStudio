# SubtitleStudio — CP90 R7: Shared Edit Line Draft Save

Date: October 22, 2026  
Branch: `refactor/riverpod-architecture`  
Code commit: [`46f9550`](https://github.com/anzilr/SubtitleStudio/commit/46f9550d612a2d6d1575592717ad9ea282df5177)

## Problem

Edit Line's manual Save and navigation autosave duplicated database-write
logic, previously ignored false repository results in places, and could
mutate the active subtitle prior to an acknowledged persistence commit.
This risked incorrectly reporting success or presenting unsaved content
as committed.

## Implementation

- New `EditLineDraftSaveService` shared by manual Save and navigation autosave.
- Prepare detached `SubtitleLine` copies for checkpoint before/after state.
  Preserve null-vs-empty edited text, marks, comments, resolved status,
  original-text mode and timing, and the existing newline-to-`<br>` policy.
- Delegate existing edits and new-line insertions to the established
  transactional EditLine repository. Report `saved=false` for rejected writes.
- Only after a successful transaction update the widget's active cue,
  associated in-memory collection and video subtitle projection.
- Last-edited index persistence is noncritical bookkeeping; a failure there
  is logged without changing a successful line-commit result.
- No Isar schema, `.msone` format, media engine, original file access, UI
  design, or desktop preview changes.

## Regression coverage

- Five pure service tests: manual/autosave equivalence, deliberate blank cues,
  original-source preservation, rejected edits/new cue inserts, metadata
  retention and noncritical session-index failure.
- One Isar integration test: an empty edited cue is persisted with the original
  before-state in a V2 checkpoint delta, with the caller's line kept detached.
- Existing import/export, history, and widget tests still run.

## Verification

[GitHub Actions run 39807708108](https://github.com/anzilr/SubtitleStudio/actions/runs/39807708108)
completed successfully on Ubuntu: **678 Flutter tests passed**, `flutter analyze`
reported **No issues found**. Only `flutter pub get`, `flutter analyze`,
and `flutter test` ran. No native builds or unnecessary Windows/macOS matrix.

## Remaining

- Continue CP90 with remaining Editor/Edit Line ownership boundaries,
  including controller state rehydration after timing-based cue reordering,
  media state handoff, and duplicated UI-side lifecycle handling.
- CP91 visual Git-style checkpoint history and compact Edit Line UX.
- CP92 tested cleanup and performance/logging work; CP93 native/platform
  acceptance, including real SAF/document-provider testing and the separate
  `media_kit` hot-restart stability issue.
- Keep the desktop preview and waveform experiment on their isolated branches.
