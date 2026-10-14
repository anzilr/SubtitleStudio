# Checkpoint 77 — Waveform processing safety and tile foundation

Date: 2026-10-14
Branch: `refactor/riverpod-architecture`
Baseline: Checkpoint 76 R2 — 310 tests passed, analyzer zero issues.

## Evidence and original research

Based on `SUBTITLECOMPOSER_WAVEFORM_AND_ENCODING_SOURCE_AUDIT.md`,
written from the supplied KDE Subtitle Composer archive. That review
described streamed PCM decimation, bounded amplitude buffers, requested
visible-range zoom buffers, and explicit renderer/view state.
**This checkpoint does not copy KDE source code.** The current Flutter
processor eagerly reads PCM and materializes every full-track zoom level.
The comparison is architectural, not a measured speedup.

## Production changes

- **Request epoch / navigation safety:** Riverpod waveform controller
  invalidates the prior load when another source starts, when ClearWaveform
  is dispatched, or when the provider is disposed. Late progress, ready
  results, errors, and saved zoom preferences cannot overwrite newer state.
  This prevents cross-file waveform mixups but does not yet cancel CPU or
  FFmpeg work already in progress.
- **PCM cache identity:** cached PCM output is now keyed by collection,
  source path, selected audio track, and local media size+modified time.
  For SAF content URIs, URI and track are known but a source-version stat
  is unavailable; external content changing in place is still a limitation.
  Old collection-only caches are invalidated and regenerated automatically.
- **PCM integrity:** check expected cache path, 44.1-kHz mono format,
  nonzero total samples, and exact PCM length before reuse. Decoding handles
  explicitly little-endian FFmpeg PCM even on a non-little-endian host and
  rejects odd or empty byte streams.
- **Bounded tile foundation:** added `WaveformTileSource` serving only
  requested pixel intervals, at selected samples-per-pixel resolution.
  Its fixed-size LRU tile cache has bounded resident entries, per-channel
  signed min/max preserving transients, optional source invalidation, and
  square-root amplitude scaling to match the current rendering semantics.
  Large/malformed viewport requests are bounded/rejected.
  **Existing mobile waveform rendering and the eager zoom implementation
  remain unchanged** pending visual and performance parity validation.
- **Performance instrumentation:** `AudioProcessor.lastProcessingMetrics`
  records source acquisition, downsample, zoom generation and total time,
  along with decoded/retained sample counts and generated zoom pixel count.
  Debug logging prints these indicators for manual device profiling. They
  are not peak RSS measurements.

## Coverage

- Pure Dart tests validate stable file/track cache identity, file-version
  invalidation, PCM metadata and truncated-cache rejection.
- Tile tests cover channel separation, signed transients, visible-range
  clipping, LRU eviction, zoom resolution changes and invalidation.
- Riverpod controller tests simulate late competing audio loads, progress
  and clearing history, without launching FFmpeg.

## Important boundaries and Checkpoint 78 direction

- W1 baseline **instrumentation** is ready, but real Android/Windows
  decode latency, first paint latency, actual peak memory and tile
  performance are **not yet measured**.
- W2 tiles are an isolated, reusable foundation for future desktop use.
  They are **not yet wired to the visible waveform renderer**; do not
  claim UI speed or memory reductions from this step.
- W3 epoch rejects stale *state updates*, not native FFmpeg cancellation.
  Content-URI file-version metadata, same-source concurrent extraction,
  temporary raw-file cleanup and native cancellation need follow-up.
- Next: compare new tile source against eager generator with a deterministic
  PCM fixture, then progressively integrate viewport tiles behind a
  compatibility mode. Preserve subtitle overlay editing transactions and
  existing zoom/scroll semantics.
- No Isar schema changes, desktop workspace UI, upstream/main branch
  edits, PR merges, release tags or native five-platform build actions.

## Verified quality gate

- Verified code gate: [`7ff10e1`](https://github.com/anzilr/SubtitleStudio/commit/7ff10e13b03aaf219118fb4ff0dcca9c4a60d76e).
- [GitHub Actions run 38596363070 — success](https://github.com/anzilr/SubtitleStudio/actions/runs/38596363070).
- `flutter analyze`: **No issues found**, including warnings and infos.
- `flutter test -j 1`: **319 tests passed**, nine new tests
  compared to Checkpoint 76 (310 passed).
- No Isar generator work, cross-platform native build jobs, or UI redesign
  were performed.

## Real-device qualification checklist for Checkpoint 78

On **Android** and **Windows**, use a short voice clip plus a long media
clip with multiple audio tracks. Open, zoom, seek, change audio track,
reopen, edit subtitle timing, and exit during loading. Capture:

1. AudioProcessor debug metrics: source acquisition, downsampling,
   zoom generation, total, decoded samples, display samples and zoom pixels.
2. Time to first visible waveform, zoom-to-zoom latency, UI scroll/jank,
   peak application RSS using device tooling, and temporary PCM file growth.
3. Stale waveform check when switching sources before extraction finishes.
4. Cache invalidation after changing the local media file or selecting
   another audio track; verify SAF replacement-in-place separately.
5. Waveform screenshot/visual parity at multiple zooms before changing
   the renderer; signed peaks must remain visible and subtitle overlays
   must continue to use the existing V2 timing mutation service.

These are manual qualification steps, **not** tests claimed to have been run.
