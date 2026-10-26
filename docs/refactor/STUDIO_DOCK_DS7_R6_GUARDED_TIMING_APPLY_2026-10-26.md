# SubtitleStudio — DS7 R6: checkpoint-guarded timing corrections

Date: 2026-10-26
Branch: `feature/studio-dock-integration`

## What changed

- The quality dialog's **Timing ideas** tab now supports explicit selection
  and **Apply timing changes** in editable live sessions. Every suggestion is
  unchecked by default, with a separate inspect button for manual review.
- Preview-only sessions retain the previous non-mutating navigation behavior.
- Suggestions shorten the preceding cue's END timestamp only for an existing
  positive insufficient gap. The planner continues to reject overlaps,
  invalid/noncanonical timecodes, values beyond the SRT 24-hour boundary,
  unsafe minimum durations, and excessive CPS.
- Each suggestion retains its validated quality profile; the writer
  regenerates the expected proposal from the authoritative session snapshot.
  Unknown/duplicate cue numbers, changed source ENDs, forged suggested ENDs,
  or invalid profile limits are rejected before any persistence call.
- **Optimistic neighbor guard:** each following cue is included unchanged
  alongside edited cues in the same `updateMultipleLinesWithHistory` batch.
  The repository checks every submitted line against the current Isar state
  inside the history transaction. An unchanged guard produces no history
  delta; a changed following cue aborts the entire batch.
- Multiple approved suggestions are combined into one undoable checkpoint.
  A following cue may itself be a selected preceding cue for the next gap;
  the planner merges those updates while retaining the original expected
  snapshot for each.

## Verification

- Integration tests: two adjacent timing suggestions committed atomically,
  original text/marks/comments preserved, stale proposal rejection, forged
  timing output rejection, and concurrent follower edit rejection.
- Widget tests: Apply disabled until a timing idea is checked, selected
  proposals passed to the live guarded callback, preview-only mode unchanged.
- Regression CI: Flutter dependency resolution, analyzer and tests only.
  No Android, Windows, macOS, Linux or iOS platform builds in Actions.

## Limits and next steps

- Trimming a cue's END can be helpful, but is not a universal fix for
  overlaps or short durations. Those cases remain diagnostic and require
  manual edit. No automatic seek, speech recognition, or waveform changes.
- Native Windows visual acceptance remains pending the user's laptop.
