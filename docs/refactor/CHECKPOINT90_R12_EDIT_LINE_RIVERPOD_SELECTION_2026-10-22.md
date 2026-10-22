# SubtitleStudio — CP90 R12: Edit Line and Riverpod selection synchronization

Date: October 22, 2026
Branch: `refactor/riverpod-architecture`

## Problem

The UI-owned subtitle selection and cached collection were updated after a
successful edit, while the screen-scoped Riverpod controller could keep its
pre-save `subtitleLine`, `subtitleCollection` and unsaved-change baseline.
Reordering cues by timestamps or inserting one could therefore leave later
controller actions operating on stale selection/order. Direct cue navigation
loaded a fresh UI row without publishing the same selection to Riverpod.

## Implementation

- New pure `EditLineSelectionProjection.apply` creates a **detached**
  subtitle collection and selected cue for the next immutable Riverpod state.
- The copied collection preserves Isar ID, filename, file path, original
  URI/document identity, encoding, macOS security-scoped bookmark, and all
  embedded cue metadata, including marks/comments/resolved flags and
  null-versus-empty edited text.
- A committed cue uses the exact post-sort row order returned from the
  checkpoint/Isar transaction. A freshly drafted new cue may be selected
  without being added to the persisted rows before saving.
- The Edit Line controller now publishes the successful `saveDraftLine`
  result and resets its initial text/time baseline only after a confirmed
  commit. Rejected writes leave prior selection and baseline unchanged.
- The legacy widget adopts that newly projected collection and cue after
  Save rather than mutating the old collection object held by the earlier
  Riverpod state snapshot.
- Navigation and new-cue load paths explicitly inform the controller of
  the selected cue and displayed edited text (which can differ from stored
  text when showing the original). The legacy mobile widget and its form
  controllers stay intact.
- Validation errors are cleared when switching to a newly accepted cue;
  unrelated preference/media and UI state remains preserved.

## Regression tests

`test/edit_line_selection_projection_test.dart` adds six tests covering
committed sorting versus cached collection, file identity and cue metadata,
deliberate blank edits, preserved multiline breaks, unsaved new-cue slots,
and clean selection state without resetting media/preferences.

## Compatibility and verification

No Isar schema or `.msone` file-format changes, no video player
implementation changes, and no desktop presentation changes. GitHub Actions
runs Flutter dependency resolution, analyzer, and full tests on Linux only.
The verified result will be appended once the CI job finishes.

## Remaining

Further CP90 Editor/controller state ownership audit and direct controller
navigation modernization, then CP91 checkpoint history and compact Edit
Line UX, CP92 cleanup and CP93 native acceptance. The previously reported
native `media_kit` hot-restart crash is no longer reproducible according
to user device testing and is not an open blocker.
