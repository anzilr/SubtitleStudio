# SubtitleStudio — DS5 R15 Subtitle Synchronization

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Desktop parity

The existing mobile `SubtitleSyncSheet` provides two paths:
1. Shift Timecodes: supply a new first start and last end; start positions scale
   proportionally relative to the original first start, **while durations stay
   unchanged**. The target final end acts as a scale anchor; it is not always
   the resulting final end when durations are kept constant.
2. Adjust Framerate: when a video is attached, enter source and target frames
   per second; scale *both* start and end by source/target.

DS5 R15 exposes these existing operations through the native Timing menu and
Tools panel. The old fixed positive/negative millisecond shift and selected
cue timing stretch stay intact. No classic desktop editor is introduced.

The desktop calculations match the two existing mobile planner formulas but
use canonical HH:mm:ss,SSS and SRT boundary validation, rejecting invalid
ranges and FPS values before entering the shared checkpoint writer.
`StudioDockBulkToolsService` uses the same
`SubtitleRepository.updateMultipleLinesWithHistory` optimistic transaction
as other Studio Dock batch tools, with one undoable Sync checkpoint.
Original/edited text, marks, comments and resolved metadata are preserved.
The active cue, list, playback overlay and history graph are refreshed.

The desktop framerate action is disabled without attached video, matching the
mobile video prerequisite. Where the current player reports an FPS, it becomes
the target default; otherwise 25.000 is used. Source defaults to 23.976.

Both dialogs validate input, provide Cancel, and use the established unsaved
inspector/Source View leave gate before the final confirmation. This checkpoint
does not change mobile UI or the existing MSone submission feature.

## Validation

- Pure plan tests: anchor ratios, duration preservation, FPS bounds, metadata
  retention, malformed inputs, and 24-hour SRT boundary protection.
- Widget tests: first/last validation, one confirmation/write, video
  prerequisite and detected FPS, draft cancellation, Timing-menu navigation.
- Flutter pub get, analyze, focused Studio Dock suite and complete Flutter
  tests in GitHub Actions. Absolutely no native builds.

## Native deferred

Windows acceptance: player FPS detection, actual video+subtitle drag/seek
accuracy after sync, live history Undo/Redo, long documents, file round trip,
desktop keyboard/focus, and video attachment removal. No test submission is
sent to the MSone production service.
