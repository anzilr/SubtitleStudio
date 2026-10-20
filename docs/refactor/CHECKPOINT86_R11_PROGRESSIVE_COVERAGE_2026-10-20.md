# CP86 R11 P1 — Sparse progressive viewport coverage foundation

Date: 2026-10-20
Branch: `experiment/cp86-r9-windowed-waveform-preview`
Status: Dart-only architecture/test checkpoint; **not wired to shipping or experimental UI yet**.

## Context

R10 native Logcat `cp86_r10_paint_verification.log` verified **954ms** seek-window extraction at 30:00, **32ms** from PREVIEW_CREATED to PREVIEW_PAINTED, successful sampled zero-lag alignment (256 samples compared), and **140,822ms** full waveform processing. This means early rendering is physically possible, but it does not certify PTS discontinuities or multi-track correctness.

## New source-independent orchestration

`lib/features/waveform/services/waveform_progressive_coverage.dart` implements:
- Explicit absolute-time window requests (default 30 seconds; hard maximum 60 seconds) and a strictly bounded at-most-eight in-flight viewport claim.
- Nearest-playhead-first missing-window scheduling, with deterministic tie-breaking; does not duplicate work for pending/ready windows. A **global eight-pending-window cap** applies across repeated viewport requests.
- Immutable viewport spans where **unknown data is `preview == null`**, never represented by zero/silence.
- Strict source-revision and selected-audio-stream identity isolation; a new revision invalidates ready and pending results, and obsolete async callbacks cannot publish. Request tokens carry an **instance owner identity** to reject late results from an entirely different coverage object even when generation/index coincide.
- Runtime rejection of truncated, shifted or invalid PCM windows; final tail window is clamped to the actual media duration.
- No cached partial-file writes; no renderer/seek/subtitle editing behavior change; no source locator strings logged.

Unit tests cover request ordering, known/unknown windows, duplicate suppression, cross-instance token rejection, the eight-pending-work global cap, source/stream cancellation, tail clipping and invalid views.

## Before any interactive integration

1. **Native PTS acceptance:** generate fixture with nonzero start time, timestamp gaps, offset multi-track audio, codec priming and at least one provider with limited seek support. Compare segment PCM sample alignment and absolute video time at 0, 30 and 90 minutes. Document tolerances per format and selection.
2. **Track/source identity:** connect to `StudioFileIdentity` and source revision; SAF without reliable version metadata must be session-only. No assumption that two docs with the same display name are the same media.
3. **Correct viewport mapping:** integrate explicit time-to-pixel translation and segment samples into `WaveformTileSource` only after PTS passes; unknown ranges must remain visually blank/loading instead of being rendered as silence, with no seek/drag widgets over unavailable data.
4. **Concurrency:** own FFmpeg sessions per window or safely cancel+serialize them, avoid starving playback and reject late callbacks on audio track changes. Do not reuse the single-session `AudioProcessor._activeNativeSessionId` across simultaneous extractions.
5. **Performance:** measure time-to-first-visible waveform, memory/battery while playback runs, LRU limit, cancellation, rapid scrolling, SAF revocation, and resume-from-background on actual Android CPH2381 and Windows.
6. **After acceptance:** investigate making viewport-first progression the default while retaining existing full-cache compatibility/fast reopening.

**Never build platform artifacts in GitHub Actions.** Only Flutter dependency resolution, analysis and tests.
