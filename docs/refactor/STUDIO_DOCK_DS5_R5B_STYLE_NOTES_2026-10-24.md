# SubtitleStudio — DS5 R5b: Production Style & Notes inspector

Date: 2026-10-24
Branch: `feature/studio-dock-integration`
Predecessor: `STUDIO_DOCK_DS5_R5A_SOURCE_VIEW_2026-10-24.md`

## Implementation

- **Style** now edits the selected subtitle's established SRT styling tags:
  bold, italic, underline, `<font color>` via the shared color-picker,
  and `\\an1`–`\\an9` positioning. It renders a live formatted preview and
  a selectable tagged-text representation. Style drafts are persisted only
  through the existing text-edit checkpoint transaction; no new style schema
  or separate desktop write path exists. Clear Tags removes supported tag
  forms while preserving ordinary subtitle content and other annotations.
- **Notes** now exposes mark-for-review, multiline comment and resolved state.
  The production host uses `StudioDockNotesService` to compare the complete
  persisted cue with its authoritative baseline, atomically update annotation
  metadata via the existing `updateMultipleLinesWithHistory` transaction and
  reload the authoritative snapshot. Comments imply a review mark. Explicit
  unmark clears the comment and resolution. Conflicting/stale writes fail
  without clobbering another editor; unchanged proposals still verify the
  current cue rather than accepting stale state.
- Style and Notes use the existing **Apply / Discard / Cancel** draft boundary
  on tab, cue, project, file and history navigation. Rejected Notes saves
  keep the draft and show a clear error. History describes a Notes operation
  as `Updated review notes on subtitle #` rather than a storage label.
- Touched inspector colors inherit the active theme's surfaces/text tokens;
  no Carbon Zero/Jade/Copper/Aster skin switch or mobile editor behavior was
  changed. In read-only sessions, Notes remain visible but cannot be edited.

## Regression acceptance

- `test/studio_dock_style_actions_test.dart`: nine-grid tag replacement,
  typography toggles, preservation of interior blank lines, supported-tag
  cleanup and invalid inputs.
- `test/studio_dock_notes_integration_test.dart`: one atomic checkpoint for
  review metadata, data preservation, unmark, blank-note normalization,
  no-op/no checkpoint, rejected stale content and stale no-op.
- `test/studio_dock_inspector_widget_test.dart`: Notes Apply, Cancel/Apply
  tab guard, stale-save draft retention, Style typography/position Apply,
  cancelable shared color picker without an immediate write.
- CI gates are **Flutter dependencies, analyzer and tests only**. No Android,
  desktop, iOS or other native application build in GitHub Actions.

## Remaining

1. **DS5 R5c:** production Search and Tools panel integrations and workflow
   polish (bulk actions and shortcuts), plus layout/skin widget regression.
2. **DS6:** user-machine Windows native playback, waveform scroll/seek/follow,
   controller visibility, theme contrast at 1366×768/1920×1080, save/import
   and encoding round-trips, `.msone` reopening/history; macOS/Linux targeted
   smoke checks when environments are available.

## CI

- [Focused Studio Dock #40075098433](https://github.com/anzilr/SubtitleStudio/actions/runs/40075098433): **PASS**, analyzer clean, **121 tests passed**. The first focused run #40074874524 passed analyzer and 118 tests but exposed three Notes widget failures: Flutter required a local Material ink surface around SwitchListTile. The two switches now have transparent Material ancestors and all focused tests pass.
- [Full Flutter repository #40075274018](https://github.com/anzilr/SubtitleStudio/actions/runs/40075274018): **PASS**, analyzer clean, **923 tests passed**.
- GitHub Actions ran `flutter pub get`, `flutter analyze` and Flutter tests only, with no native/platform application builds. Desktop native acceptance remains pending.
