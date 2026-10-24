# SubtitleStudio — DS5 R5e: Resolve and reopen review marks

Date: 2026-10-24
Branch: `feature/studio-dock-integration`
Predecessor: `STUDIO_DOCK_DS5_R5D_COMBINED_INSPECTOR_REVIEW_2026-10-24.md`

## Review semantics

- **Mark** puts a subtitle in the review list without changing its note or
  existing resolution. A marked, unresolved subtitle still needs attention.
- **Resolve** completes the review but retains both its mark and note. When a
  previously unmarked subtitle is explicitly resolved, it is also marked; the
  UI warns before applying this side effect.
- **Reopen** makes a resolved subtitle unresolved again, preserving the mark,
  note, text and timing.
- **Unmark** explicitly removes the review mark, note and resolution, with a
  destructive-data confirmation. This is distinct from reopening.

## Implementation

- Added type-safe `StudioDockReviewAction` with mark/unmark/resolve/reopen.
  The existing `StudioDockBulkReviewService` applies each action to a selected
  group in a single guarded shared-history transaction. Even unchanged cues
  in the selected group are checked against the original snapshot, preventing
  concurrent annotations from being silently omitted from the guard.
- The grid's Review menu, right-click actions and command palette support all
  four actions. Notes retains its one-cue **Review resolved** switch.
- The grid distinguishes unresolved marks (bookmark) from resolved reviews
  (check-circle) and unmarked comment-only lines (comment icon), using theme
  colors. Filter options: **All lines**, **Marked**, **Unresolved** and
  **Resolved**. Filtering does not alter persisted selection/review data.
- Bulk actions retain multi-selection on refresh. No schema change, mobile
  screen change, separate review database, or native build.

## Regression coverage

- Isar: resolve and reopen retain notes/marks/text, single undoable checkpoint
  per action, no-op and mixed-selection stale conflict protection.
- Widget: selected-cue resolution and reopening, confirmation of automatic
  marking, differentiated status icons, unresolved filter after resolution.
- Existing Notes and desktop selection tests assert accurate review status.
- GitHub CI: `flutter pub get`, `flutter analyze`, focused Studio Dock tests,
  then all Flutter tests; no platform builds.

## Remaining

1. **DS5 R5f:** desktop Settings and existing hotkey configuration surface,
   context-menu refinements, accessibility and narrow-layout acceptance.
2. **DS6:** Windows native Studio Dock video/controller/waveform interactions,
   file paths/encodings, reopening and scaling — deferred until the user's
   Windows machine is available.

## CI

Pending focused and full Flutter validation.
