# DS7 R17 — SRT Batch 3, effect restore/filter, desktop cursor

Date: 2026-10-27. Branch: `feature/studio-dock-integration`.

## Implemented in this checkpoint

- Three additional **SRT-only** timed-frame effects: Spotlight Karaoke,
  Typewriter with Cursor, and Center-Out Reveal. One shared generator supplies
  the effects-sheet preview, export, and Studio Dock recognizer; the generator
  reveals or highlights only complete Unicode grapheme clusters.
- Added an `Effects` choice beside All/Marked/Unresolved/Resolved. It displays
  only recognized effect frames, keeping their bundles collapsed where the
  collapse preference is on. Search reveals matching individual frames.
- Collapsed bundle context menu adds `Remove effect · restore line`. It asks
  for confirmation, then commits a **single guarded history transaction**
  replacing the detected frames with one plain-text cue covering the same
  interval. Mark state, comments and resolution are projected to that cue.
  History undo recovers the exact original sequence; stale external edits
  abort the operation. Non-animation source formatting cannot be recovered
  losslessly from a pre-existing imported SRT bundle; the confirmation warns
  that text is restored without animation formatting.
- Studio Dock reads the Session `lastEditedIndex` through the shared loader,
  passes it into the workspace, and scrolls that selected cue into view when
  the project loads. Selection and successful text/timing edits update the
  existing session index via serialized writes, with no separate desktop DB.

## Acceptance / CI

- New tests: all Batch 3 SRT frames and auto-fold recognition, grapheme
  integrity, effect restoration projection, real-Isar checkpoint/Undo and
  concurrent-stale rejection, effect filter/context-menu flow, restoration of
  last-edited line on session load and long-grid initial scrolling.
- Run focused Studio Dock tests and full Flutter analysis/tests on GitHub
  Actions; never platform builds in Actions.
- **Verified source commit `5be845da873c83b3fdcb9f046d207bd4088b0ab5`:**
  Studio Dock Flutter quality [run 40405488846](https://github.com/anzilr/SubtitleStudio/actions/runs/40405488846):
  **380 passed**, analyzer clean. Migration quality
  [run 40405488690](https://github.com/anzilr/SubtitleStudio/actions/runs/40405488690):
  **1,229 passed**, analyzer clean.
- Pending physical Windows + Android visual acceptance (colors, cursor
  timing, effect folding, right-click behavior and restore).

## Explicit future commitments

ASS/SSA and WebVTT **editing**, plus Subtitle Edit feature parity, are tracked
in `SUBTITLE_FORMAT_EXPANSION_AND_SUBTITLE_EDIT_PARITY_BACKLOG_2026-10-27.md`.
This checkpoint deliberately does not claim those formats are editable yet.
