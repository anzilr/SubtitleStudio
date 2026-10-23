# SubtitleStudio — CP93 R5: Waveform edges, playhead time and loader

Date: October 23, 2026  
Branch: `refactor/riverpod-architecture`  
Prerequisite: CP93 R4 paused seeking confirmed responsive and accurate by user

## Reproduction and source-level explanation

At 0:00 the true red cursor starts at the left and travels to the midpoint
before following auto-scroll. The clock incorrectly displayed the *viewport
midpoint* even though the cursor was still at the left, causing an observed
`00:00:11,473` readout to freeze until actual playback caught up. At either
end, zero-padding scroll bounds prevented the midpoint selection from reaching
the very first/last samples, so add-line and copy were inaccurate or blocked.

## Changes

1. Clock, clipboard and new-subtitle default time now use the actual playhead
   position. Painter and pointer hit testing use the same time-to-pixel
   projection. The normal left-to-center-to-right playback movement remains;
   the timer updates from the beginning without waiting for the cursor to be
   centered.
2. Manual scrolling may reveal half a viewport of **visual-only blank space**
   before the start and after the end. This lets the center position reach
   precisely `0` and the final sample, including for short clips. The waveform
   PCM, media position and valid cue times are unchanged. Wheel/drag seeking
   retains R4's throttled previews and final exact native seek.
3. A compact waveform-shaped loading indicator replaces the bouncing dots.
   During native extraction, its fill tracks **accepted FFmpeg decoded-media
   timestamps relative to the player's known source duration**. An unknown
   duration animates an indeterminate sweep; it never claims a percentage.
   After PCM acquisition, the last segment fills using the existing zoom
   processing-stage callbacks. Stage weights are presentation-only, not a
   benchmark of wall time or decoded bytes.
4. Native FFmpegKit decode-time callbacks now reach the default eager-PCM
   pipeline, not just the optional tiled peak pipeline. The editor passes its
   player-known duration during initial waveform load, regeneration and
   audio-track reload. Standalone loading works without total-duration data.

## Regression scope

- Playhead starts, middle, end, exact manual scroll boundaries and short audio.
- Clock follows actual playback before the first center crossing and near end.
- Measured/unknown-duration loader cases, 100% extraction clamp, zoom stage.
- No new native seeks are introduced by loading or by painting the cursor.

## Validation

- Source patch prepared and reviewed in an isolated worktree. The full
  [GitHub Flutter gate 39976867177](https://github.com/anzilr/SubtitleStudio/actions/runs/39976867177)
  **passed: 801 tests, zero analyzer issues**. Flutter SDK is unavailable in
  the isolated Linux scratch environment; CI ran dependency resolution,
  analysis and Flutter tests only. **No platform builds in Actions.**
- Physical OnePlus playback, paused endpoint scrubbing, copying and loader
  visual progress require user validation after successful CI.

## Continuity

This is CP93 R5 on the *stable* waveform path. Do not merge CP86's deferred
experimental progressive window decoder. The separately accepted R4 native
seek optimization remains in place. Continue CP93 shared-core native acceptance
and desktop integration work after this focused regression gate.
