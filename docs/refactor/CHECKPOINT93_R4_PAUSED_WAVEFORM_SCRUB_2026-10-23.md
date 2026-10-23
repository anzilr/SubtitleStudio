# SubtitleStudio — CP93 R4: Paused waveform scrub stabilization

Date: October 23, 2026  
Branch: `refactor/riverpod-architecture`  
Android profile counters: observed on CPH2381; user accepted paused seek accuracy/responsiveness

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
- Native OnePlus profile retest (Oct 23, log
  `8078e7e1-97bd-4740-a648-d131f48fb093`): **33 paused gestures** in the
  fresh app process (PID 27948) produced **1,793 visual update events and
  zero intermediate seek previews**. A single final seek was logged after
  each gesture. The corresponding `AudioTrack.flush()` records appear
  immediately after those completions, not on every scroll update.
- A separate earlier app process captured 63 gesture completions, 3,725
  visual updates and 2 intermediate previews, consistent with a playing
  period; the two process lifetimes are not combined to estimate latency.
- No Flutter fatal, SIGSEGV or ANR appeared. In the full capture, six
  `Skipped: true` frame reports counted 22 frames; the largest 191 ms
  report was near FFmpeg media handling/GC. The remaining `STATE_FLUSHED`
  events include genuine final seeks and track lifecycle operations and
  must not be reported as zero across the full session.
- On October 23, the user confirmed that paused waveform seeking was
  **responsive and accurate** on the phone. This closes the originally
  reported drag responsiveness and landing defect. Long-duration/wheel
  scenarios remain distinct native-acceptance checks.

Do not treat this acceptance as closing
the remaining CP93 Android/Windows file and media smoke-test gates.
