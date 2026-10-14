# Checkpoint 79 — Metadata-only zoom levels in experimental tiled mode

Date: 2026-10-14
Branch: refactor/riverpod-architecture
Previous verified gate: Checkpoint 78 R3, 323 passing Flutter tests and zero analyzer issues.

## Source references

KDE Subtitle Composer audit: SUBTITLECOMPOSER_WAVEFORM_AND_ENCODING_SOURCE_AUDIT.md
Subtitle Edit audit: SUBTITLEEDIT_WAVEFORM_SOURCE_AUDIT_2026-10-14.md

Both source studies indicate that viewport-oriented waveform rendering and compact
peak representations help avoid eagerly materializing full-track display pixels.
This checkpoint implements an independent Flutter adaptation, not copied code.

## Implemented

1. ZoomLevel.metadata stores samples-per-pixel, channel count and pixel count
   but does not allocate any per-pixel WaveformSample arrays. Eager ZoomLevel
   remains unchanged. Metadata-only getSample/getChannelData return null.
2. ZoomBufferGenerator.generateZoomMetadata uses the existing zoom ladder
   configuration to preserve zoom index, sample-per-pixel values and widths.
   prepareZoomLevels selects eager pixels + scaling or metadata only.
3. AudioProcessor uses the compile-time MS_ONE_TILED_WAVEFORM flag, default false.
   In enabled mode it skips eager pixel-array generation and square-root pass.
   Metrics zoomPixels records zero allocated full-track zoom buckets
   by summing the actual per-channel materialized array lengths,
   not metadata-only virtual timeline widths.
4. WaveformWidget automatically creates tiles for metadata-only levels even
   when a widget caller opted out of tiled paint explicitly. The painter
   asserts metadata levels are not painted without a tile source.
5. Playback, zoom/scroll timing mapping, subtitle overlays and V2 timing
   mutation API remain unchanged. Eager painting remains production default.

## Reproduction

Windows (default eager):
    flutter run -d windows

Windows (experimental metadata-only):
    flutter run -d windows --dart-define=MS_ONE_TILED_WAVEFORM=true

Android:
    flutter run -d <device-id> --dart-define=MS_ONE_TILED_WAVEFORM=true

## Tests

- Compare every zoom level's sample-per-pixel, pixel count and channel count
  to eager output for 0, 1, 17, 4096 and 40001 samples, mono and stereo.
- Assert no per-channel sample arrays in metadata-only zoom levels.
- Generate metadata for a declared 900-million-sample source without allocating
  the audio samples. This is a geometry/allocation test, not an actual codec test.
- Compare signed min/max pixel extrema to the existing scaled eager generator.
- Compare rasterized eager, tiled/eager and tiled/metadata painter variants
  at several zooms and fractional offsets using true async image readback.
- Retain existing cache, load epoch, UI and import/export regressions.

## Known limitations and next steps

- AudioProcessor STILL extracts and loads the complete 44.1-kHz PCM
  and downsamples it into memory. This checkpoint eliminates full-track
  zoom PIXEL allocations in the experimental mode only.
- Tile computation currently runs synchronously over downsampled PCM.
- Android/Windows real-device initial latency, peak RSS, scroll frame times
  and output visual parity have NOT yet been benchmarked.
- FFmpeg cancellation, temp file cleanup, SAF source version, timestamp gaps,
  selected-track selection failure and compact versioned peak cache are
  deferred to Checkpoint 80.
- Main/upstream/tags, Isar schema, desktop workspace and platform build
  settings remain unchanged.

## Verified R2 quality gate

- [Verified code commit `853f3ee`](https://github.com/anzilr/SubtitleStudio/commit/853f3ee3af1f492d381d9ac153b84eaa797584f9)
- [Successful GitHub Actions run 38611346020](https://github.com/anzilr/SubtitleStudio/actions/runs/38611346020)
- `flutter analyze`: **No issues found**, including informational notices.
- `flutter test -j 1`: **327 passed**, four new tests relative to
  Checkpoint 78 R3's 323 passing tests.
- Original R1 was also green, but an inspection noticed the existing
  zoomPixels metric counted metadata-only virtual widths as allocated
  memory. R2 introduced ZoomLevel.materializedPixels, made the
  diagnostic sum actual resident sample buckets, and added assertions
  before running the entire gate again.
- No schema generator changes, upstream/main/tag changes, native
  five-platform builds or desktop-workspace UI changes. Documentation
  updates following the green gate do not trigger the workflow.
