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

## Verified Flutter-only quality gate

[GitHub Actions 39474158230](https://github.com/anzilr/SubtitleStudio/actions/runs/39474158230) — **SUCCESS** on 2026-10-20 at head `3791896`. `flutter analyze`: **No issues found**; **565 Flutter tests passed**. This includes source/track identity, owner-token isolation, at-most-eight concurrently claimed windows across repeated calls, cancellation, absolute interval clipping and known/unknown coverage regressions. No platform builds were performed.

The first R11 quality run [39473912088](https://github.com/anzilr/SubtitleStudio/actions/runs/39473912088) was superseded and canceled after the bounded-concurrency/owner-token fixes; it is not the acceptance gate. Native progressive UI interaction and Windows/Android PTS-gap/explicit-track qualification remain unverified.

## CP86 R11 P2 — Absolute-time sparse viewport demonstration

The R11 P1 scheduler was hardened before rendering: pending requests are now stored by **token identity**, not only a shared window index. A canceled request that finishes after a replacement request cannot promote stale data or cancel the replacement. Viewports spanning more than 1,024 windows and subsecond scheduling windows fail closed to prevent excessive list allocation.

Added `waveform_progressive_viewport.dart` and `waveform_sparse_viewport_painter.dart`:
- Absolute media timestamps map into viewport pixel coordinates, including nonzero 30:00 offsets and clipped known spans.
- Pure projection exposes a min/max pair only where a validated window exists; gaps render as explicitly **unknown** (hatched), not zero-volume audio.
- Validates bounded width, increasing non-overlapping extents and known interval containment before painting.
- Reuses theme colors; does not add tap, scroll, seek, subtitle edit or cache methods.
- Adds pure geometry and widget paint regression tests, including clipped-window sample offsets and zero-sized canvas behavior.

### Debug-only local Android experiment

Keep the R10 flags and add the new flag; the R11 UI shows a **90-second demonstration viewport** with 30-second unknown context on either side of the known window at 30:00. This is a local viewport, **not an assertion of total media duration**; no media duration is fabricated. The scheduler remains a separate pure service while we qualify real video duration and timestamp semantics.

```powershell
git fetch origin
git switch experiment/cp86-r9-windowed-waveform-preview
git pull --ff-only origin experiment/cp86-r9-windowed-waveform-preview
.\tool\run_android_clean_debug.ps1 -Device d6e22c3f -DartDefines @(
  'MS_ONE_CP86_R9_WINDOW_PROBE=true',
  'MS_ONE_CP86_R9_START_SECONDS=1800',
  'MS_ONE_CP86_R9_DURATION_SECONDS=30',
  'MS_ONE_CP86_R10_SHOW_WINDOW_PREVIEW=true',
  'MS_ONE_CP86_R11_SPARSE_VIEWPORT_PREVIEW=true'
)
```

Expected: a read-only viewport labeled 00:29:30–00:31:00, the 00:30:00–00:30:30 waveform in the center third, hatching on either side, and `CP86 R11 SPARSE_VIEWPORT_PAINTED knownStartMs=1800000 knownEndMs=1830000 unknownNeighbors=true`. Once the full decode finishes, the normal interactive waveform should replace this proof-of-concept unchanged.

**Not yet implemented:** driving multiple native FFmpeg window extractions from the scheduler, absolute time-to-subtitle gesture integration, native AV PTS gap verification, definitive media duration from video, cache promotion, or enablement outside debug/explicit opt-in. These remain gating work.
