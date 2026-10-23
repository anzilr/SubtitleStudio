# SubtitleStudio — CP93 R4: Paused waveform scrub stabilization

Date: October 23, 2026  
Branch: `refactor/riverpod-architecture`  
Android profile acceptance: pending physical gesture verification

## User-reported defect and profile evidence

On OnePlus CPH2381 the video was **paused** while the user dragged the
waveform. Scrolling felt slow, and the resulting time was inaccurate. The
profile log contained many `AudioTrack.flush()` calls in `STATE_FLUSHED`
and subtitle highlight changes oscillating between adjacent cues; no Dart
crash, native fatal signal or ANR was detected in the captured output.

Code review confirmed three interacting causes:

1. Every waveform drag/wheel update directly called the video player's
   native `seekTo`, producing an unbounded seek stream during fast gestures.
2. Native playback-position notifications could auto-scroll back over a
   newly painted manual scroll before an asynchronous seek completed.
3. The calculated target used the *requested* scroll position even where
   the waveform provider clamped its *displayed* scroll to valid bounds.

## Focused correction

- The waveform continues to paint every drag update. **Paused media** now
  receives a single exact native seek on gesture release; while **playing**,
  preview seeks are limited to one per 180 ms, followed by the final seek.
- Mouse-wheel bursts have an idle final seek after 220 ms. Pending timers
  are canceled when the widget is disposed or a gesture is canceled.
- Explicit manual-scrub ownership suppresses stale playback auto-scroll.
  After release, it waits briefly for a native position acknowledgement
  (within 250 ms), with a two-second stale-report timeout; any abandoned
  gesture also has an inactivity recovery path.
- Scroll is clamped *before* computing the seek time, including for clips
  whose entire waveform fits inside the visible viewport.
- Profile-mode logs emit only `Waveform scrub: updates=… previewSeeks=…
  finalSeekMs=…`; no file paths, subtitle text, SAF URI or native commands.
- Tests cover paused and playing drag modes, throttling, wheel settling,
  viewport boundaries, and stale playback-position suppression.

This is a user-requested **manual seeking defect fix** on the stable
waveform path. It does not merge or restart the frozen CP86 progressive
audio-decode experiment; waveform generation, audio cache formats, project
files and playback engine are unchanged.

## Verification and physical acceptance

- Local whitespace diff check: clean.
- [Linux Flutter CI 39968610443](https://github.com/anzilr/SubtitleStudio/actions/runs/39968610443):
  **796 tests passed; zero analyzer issues**. Dependency resolution,
  analysis and tests only; **no platform builds in CI**.
- Verified code checkpoint: `b15da6c7b85c2addb74244f452befc0d46a3f30f`.
- Native OnePlus profile retest: pending. With video paused, drag across
  dozens of waveform updates and confirm `previewSeeks=0`, one final seek,
  accurate stationary playhead and minimal additional `STATE_FLUSHED` logs.
  Repeat while playing and with mouse wheel; verify one final target per
  gesture/burst, no snap-back and intact playback state.

Native performance and accuracy acceptance cannot be inferred from Linux
unit tests. Do not treat this checkpoint as closing the remaining CP93
Android/Windows file and media smoke-test gates.
