# SubtitleStudio — DS5 R24 Cue Context Menu Parity

Date: 2026-10-25
Branch: `feature/studio-dock-integration`

## Parity audit

The mobile timeline's `showEditSelectionMenu` provides Copy Selected, Shift
Times, Delete Selected, Select by Index and Select by Range. The desktop
right-click menu previously offered only Select, review marking/resolution,
copy subtitle text and copy timecodes. These mobile batch operations already
existed elsewhere in Studio Dock, but were absent from the right-click route.

DS5 R24 adds the five mobile selection commands to desktop right-click,
reusing the exact shared handlers that the Edit/Subtitle/Timing menus call:

| Mobile selection action | Desktop context action | Shared route |
| --- | --- | --- |
| Copy Selected | Copy subtitle/selected subtitles | `_copySelectedSubtitleText` |
| Shift Times | Shift selected times | `_shiftSelectedSafely` |
| Delete Selected | Delete selected subtitles | `_deleteSelectedSafely` |
| Select by Index | Select subtitles by index | `_selectByIndexSafely` |
| Select by Range | Select subtitle range | `_toggleRangeSelectionMode` |

The desktop row context also exposes Edit subtitle, Review notes, Insert
after, Split, Combine, and Delete cue when corresponding live host callbacks
exist. These are *additional entry points* into existing transactions, not
new editor or persistence logic. The old review and copy-timecode actions
remain accessible. Edit Mode and Translation Mode use the same existing
services; no mobile UI is changed.

## Selection and safety contract

- Right-click on a **selected** row preserves all selected rows for batch
  operations, including non-contiguous selections.
- Right-click on a **non-selected** row does not immediately throw away the
  existing selection. If the user chooses an actionable batch/structural
  operation, that row becomes the sole target only after the unsaved-draft
  confirmation succeeds. Cancel never redirects a delete/shift to the
  previously selected row.
- Per-cue actions target the clicked row after the same draft confirmation;
  the shared handler then performs its normal confirmation and history write.
- Popup exit completion is awaited before another dialog opens, avoiding
  hit interception by the disappearing context-menu barrier.
- Copying a non-selected row copies only that row and does not change the
  active selection. Read-only hosts do not expose structural edits.

## Verification

- Widget tests: selected batch visibility, disabled/available host actions,
  group delete cancellation, nonselected one-row targeting, Cancel with
  unsaved text, and copy without mutating selection.
- Flutter-only CI: pub get, analyze, focused Studio Dock suite and full tests;
  no platform application builds.
- Pending native acceptance: pointer/menu hover and scroll behavior with
  1000+ cues, right-click inside a wide/narrow Dock, two-step range pointer
  mode, modal-focus transitions, true Windows/macOS/Linux mouse input and
  persistence/Undo/Redo with real `.msone` projects.

R24 is Flutter source-level context-menu parity, not native OS certification.
