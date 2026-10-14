# Checkpoint 78 — Eager-versus-tiled waveform parity

Date: 2026-10-14
Branch: `refactor/riverpod-architecture`
Baseline: Checkpoint 77 R1 — 319 passing tests; Flutter analyzer 0.

## What changed

- Integrated the W2 `WaveformTileSource` through an optional
  `WaveformPainter.tileSource` input. Existing waveform, playback and
  subtitle overlay drawing use the *same painter and coordinates*.
  The painter fetches only visible tile buckets, shared for each channel,
  and preserves the existing eager-level fallback.
- `WaveformWidget` maintains a tile source scoped to the current
  `WaveformBuffer`. A different audio buffer replaces the previous
  tile service, so cached tiles cannot cross sessions or tracks.
- For safe experimentation, the default remains eager painting;
  opt in with `--dart-define=MS_ONE_TILED_WAVEFORM=true`.
  This works through the existing caller widgets, without changing the
  mobile layout or adding a desktop workspace.
- Added a byte-accurate renderer-parity test comparing the rasterized
  eager/tiled painter for multiple zoom levels and fractional horizontal
  scroll offsets. Also compare per-channel signed min/max at multiple
  viewport positions and resolutions against the actual
  `ZoomBufferGenerator.applyScaling` output.
- Added a deterministic synthetic media diagnostic printing eager
  generation time/total bucket count and the viewport tile time/count.
  Timing comparisons have **no speed threshold**; GitHub CI is not a
  realistic Android or Windows rendering benchmark.
- A larger synthetic track test checks LRU capacity remains bounded.
  No changes were made to V2 timing persistence or subtitle gesture
  callbacks.

## Known limits / next steps

1. **Memory savings are not yet realized end-to-end:** the current
   `AudioProcessor` still decodes the full PCM and eagerly computes all
   zoom levels before rendering. Opt-in tile painting can evaluate
   pixel parity and scrolling but does not remove these allocations.
2. Pixel-perfect parity tests use deterministic synthetic PCM. Native
   video/audio codecs, real subtitle overlays, high-DPI rendering and
   platform media toolchains are not exercised by Linux Flutter test.
3. There is no user-facing toggle. Select eager/tiled by build flag;
   do not silently flip production users to tiles yet.
4. Next: separate lightweight zoom **metadata** from eager pixel buffers,
   and integrate viewport tiles into data loading so only visible buckets
   are generated in tiled mode. Then benchmark memory, FFmpeg extraction
   time, first-visible-frame latency, zoom/scroll jank on Android/Windows.
5. Native FFmpeg cancellation and in-place SAF URI file-version tracking
   remain outstanding from Checkpoint 77.

## Reproduction after building

Android:
`flutter run -d <device-id> --dart-define=MS_ONE_TILED_WAVEFORM=true`

Windows:
`flutter run -d windows --dart-define=MS_ONE_TILED_WAVEFORM=true`

Omit the flag for the unchanged eager-rendering baseline. Collect
`AudioProcessor.lastProcessingMetrics` and frame/memory profiler
measurements for identical audio source and zoom positions. This document
does not claim that physical-device profiling has already occurred.

## Verified R3 CI outcome

- [Code commit `2b16918`](https://github.com/anzilr/SubtitleStudio/commit/2b1691891fefb781fb0d08fecc3a44ec05d57a66)
- [Successful Actions run 38601795799](https://github.com/anzilr/SubtitleStudio/actions/runs/38601795799)
- `flutter analyze`: **No issues found**, including informational notices.
- `flutter test -j 1`: **323 passed**, four more than Checkpoint 77.
- Deterministic Linux runner diagnostic: **13,714 eager full-track buckets
  in 28 ms versus 716 visible buckets in 12 ms**. No performance thresholds
  were asserted; this is not an isolated, statistically meaningful device
  benchmark or a process RSS measurement.
- Initial R1 gate caught a missing direct import for `WaveformBuffer`.
  The next run stalled during engine-backed image readback inside fake-async
  widget testing and was superseded. R3 uses `tester.runAsync` for
  image readback and passes the entire suite. This does not modify
  production render behavior.
- Documentation-only changes after the green gate do not consume another
  GitHub Actions run; no native five-platform builds or upstream changes.
