# SubtitleStudio — DS5 R11 selected subtitle operations

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Intent

Close the selected-subtitle operation gap without introducing a second editor,
changing mobile interaction, or bypassing shared undo/redo history. The native
Studio Dock remains an alternate UI to the existing Flutter editor engine.

## Implementation

- The desktop Edit menu and Tools panel expose **Select by index** (inclusive
  1-based bounds) and **Range selection** (two subtitle-row pointers).
  Existing Ctrl/Cmd and Shift multi-selection remain intact. Index-based
  selection addresses underlying cues, not filtered search results; selecting
  a range clears filters and text search to make the selection visible.
- The Timing menu and Tools panel expose **Shift selected**. The planner
  follows mobile `SubtitleSyncOperations.shiftSelectedTimecodes`: anchor the
  first cue start and last cue end, scale intermediate *start offsets*, and
  preserve each selected cue's individual duration. Invalid inputs and
  out-of-day timestamps fail before entering a history transaction.
- The Subtitle menu and Tools panel expose **Delete selected** with explicit
  confirmation. The repository uses a full-persisted-snapshot comparison
  inside one history transaction, removes positions from the end toward the
  beginning, sorts/reindexes surviving cues and stores one undoable checkpoint.
  This is distinct from the preexisting mobile multi-delete path so existing
  mobile behavior is unchanged.
- Both actions wait for the shared unsaved-draft gate. Successful actions
  refresh the full loaded cue list and selection, rather than leaving stale
  rows after a reindex. Failed/stale operations leave the project untouched.
- The **MSone submission** route and **Edit Mode** creation path remain on the
  same shared native session and are not modified by this checkpoint.

## Automated acceptance

- Pure service + Isar: selected anchor scaling, duration preservation,
  nullable translation/comments, one history checkpoint, stale/full-snapshot
  rejection, invalid SRT timestamp rejection and deletion reindexing.
- Desktop widget: index validation/inclusive bounds, two-pointer range,
  cancel/confirm deletion, callback cue IDs, selected shift anchors, rejected
  writes and unsaved text-draft cancellation.
- Run `.github/workflows` Flutter-only gates (dependency resolution,
  analysis and focused/full test suites); **no platform builds in CI**.

## Deferred native acceptance

Windows desktop manual testing remains pending because the development machine
is unavailable: inspect wide and narrow Dock layouts, real keyboard range
selection, multi-cue scrolling, Undo/Redo, import/export and MSone submission
UI (no actual submission to production).
