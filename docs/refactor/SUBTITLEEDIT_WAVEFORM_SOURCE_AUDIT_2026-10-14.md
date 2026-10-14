# Subtitle Edit waveform and audio-visualizer source study

Date: 2026-10-14
Subtitle Edit source: https://github.com/SubtitleEdit/subtitleedit
Inspected Git revision: 30d8f08cd654440f62507dc04e44d88b5807aa1c (main at review time)
SubtitleStudio baseline: Checkpoint 78 R3, 323 passing tests, 0 analyzer issues.
Status: research and roadmap only; no source code was copied or integrated here.

This is a second reference alongside the KDE Subtitle Composer source audit
(SUBTITLECOMPOSER_WAVEFORM_AND_ENCODING_SOURCE_AUDIT.md). It describes
behavior verified from the pinned Subtitle Edit source and its public docs,
then separates suggested Flutter adaptation from existing implementation.

## 1. Inspected Subtitle Edit files and verified behavior

### Compact PCM peak extraction and durable cache

- src/ui/Logic/Media/WaveToVisualizer2.cs:
  WavePeakGenerator2.GeneratePeaks converts PCM in fixed chunks into
  reduced peak records, with a configured peaks-per-second output.
  The code includes a specialized 16-bit stereo peak reduction and
  WriteWaveformData for compact peak files. Peak writes go through
  WaveCacheFile.Write. WavePeakData2.FromDisk loads the stored peaks.
- tests/benchmarks/WaveformPeakSimdBenchmarks.cs:
  compares older intermediate-buffer peak generation with a fused
  single-pass stereo reduction; tests protect equivalence, including
  the signed 16-bit minimum boundary. No measured speedups are inferred
  here from simply reading the benchmark implementation.
- tests/UI/Logic/WaveformCacheCorruptionTests.cs:
  explicitly tests truncated and corrupted cache headers, read sizes
  bounded by actual file length, and commit-style cache writes rather
  than leaving half-written destination files after crashes.
- Implication for Flutter (proposal):
  create a compact, versioned, validated, track-scoped *peak cache*,
  rather than requiring persistent full-resolution raw PCM files.
  Write to a temporary file and atomically move into place where the
  filesystem allows it. Strictly cap lengths and allocation sizes.

### Audio extraction and synchronization

- src/ui/Logic/Media/WaveFileExtractor.cs:
  constructs FFmpeg extraction arguments for selected audio tracks.
  The documented filter aresample=async=1:first_pts=0 accounts for
  timestamp gaps, particularly screen recordings whose audio would
  otherwise appear progressively early. The source also contains an
  optional front-center speech channel selection case.
- docs/features/audio-visualizer.md:
  selecting another audio track updates the visualizer and chooses
  that track's cached/extracted peaks where available.
- Implication for Flutter (proposal):
  test extraction across timestamp gaps and ensure 0-based/1-based
  track mapping never silently falls back to the wrong audio track.
  Prefer precise audio presentation timestamps over assumptions that
  all decoded samples are contiguous.

### Separate interaction state from render work

- src/ui/Controls/AudioVisualizerControl/AudioVisualizer.cs:
  the primary interaction control manages selection, seeks,
  timeline input, and subtitle timing gestures.
- src/ui/Controls/AudioVisualizerControl/SkiaAudioVisualizer.cs:
  an experimental replacement renderer inherits those interactions
  while presenting display-state frames to a render-thread painter.
  It describes real per-device-pixel peak extrema when zoomed out,
  not sample interpolation, and a 256-device-pixel scroll-anchored
  scenery cache. Dynamic playhead and subtitle overlays draw above it.
- src/ui/Controls/AudioVisualizerControl/SkiaWaveformRenderer.cs:
  provides scenery caching modes None, Picture, and Image; reuses
  renderer-owned graphics objects, draws within device-pixel coordinates,
  and can render classic envelopes or more elaborate styles.
- tests/UI/Controls/SkiaWaveformCacheTests.cs and
  tests/benchmarks/SkiaAudioVisualizerBenchmarks.cs:
  provide useful examples of validating cached/uncached drawing
  and measuring render throughput separately from extraction.
- Implication for Flutter (proposal):
  separate static scenery (waveform peaks, time ruler, grid) from
  frequently changing state (playhead, cue selection, drag handles).
  Add repaint boundaries and reuse paths/pictures when appropriate;
  preserve correct fractional scrolling and high-DPI peak coverage.
  Do not port SkiaSharp render-thread ownership to Flutter directly.

### Editor interaction and advanced optional modes

- tests/UI/Controls/AudioVisualizerShotChangeSnapTests.cs:
  validates shot-change snapping for both cue edges and whole-cue
  moves, with capture distance measured in screen pixels; the
  configured in/out cue gaps are maintained.
- docs/features/audio-visualizer.md and
  docs/features/settings.md:
  document horizontal and vertical wheel zoom, configurable actions,
  frame snapping, Shift override for shot-change snap, audio track
  selection, waveform and spectrogram display options.
- src/ui/Logic/Media/SpeechOnlyWaveform.cs and
  docs/features/audio-visualizer.md:
  describe a separate speech-only peak output and its cache identity.
  The feature requires additional audio processing.
- src/ui/Controls/AudioVisualizerControl/TimelineThumbnailCache.cs:
  prioritizes current thumbnail requests and throttles extraction
  while playback is active to avoid stealing resources from media.
- Implication for Flutter (proposal):
  use explicit drag intent and pixel-based snapping tolerances,
  and add optional shot-change/grid markers. Keep speech-only
  waveform and spectrogram as later, separable features (not
  prerequisites for an efficient normal waveform).

## 2. Subtitle Composer versus Subtitle Edit

| Design question | KDE Subtitle Composer (attached source) | Subtitle Edit (reviewed main revision) | Proposed SubtitleStudio approach |
| --- | --- | --- | --- |
| Raw audio | Incremental streamed audio buffer and bounded decimation | FFmpeg-extracted PCM reduced to compact peak records | Bounded streamed PCM-to-peak extraction, no permanently retained full PCM requirement |
| Zoom | Worker prioritizes requested visible interval | Peaks sampled at actual device-pixel columns; static layer cached | Resolution-aware viewport tiles and cache; move expensive work off UI thread |
| Painting | Separate waveform renderer and interaction widget | Fast renderer inherits interaction model; static scenery separated from dynamic overlays | Flutter render layers with RepaintBoundary; retain existing interaction semantics |
| Cache | Bounded waveform/zoom data | Durable, validated on-disk peak cache; atomic write, corruption tests | Versioned, keyed peak cache with size limits, invalidation and atomic promotion |
| Seeking/timing | Drag start/end/body and center-anchored zoom | Shot/frame snapping, whole-cue moves, configurable pixel tolerance | Add geometry-independent drag policy and preserve V2 atomic timing writes |
| Extra views | Primary emphasis on time-domain waveform | Spectrogram, speech-only peaks, optional timeline filmstrip | Optional future features with isolated budgets and platform checks |

Important distinction: Subtitle Composer's inspected zoom aggregation
uses mean absolute and maximum absolute amplitudes. SubtitleStudio's
current renderer and tile tests preserve signed min/max values. Subtitle
Edit's per-pixel extrema are another useful point of comparison, but
neither reference is authority to change SubtitleStudio's amplitude
semantics without explicit visual and timing parity tests.

## 3. Current SubtitleStudio status (verified through Checkpoint 78)

Already in experimental branch:
- Audio load epoch guard prevents old jobs from overwriting newer state.
- Source/track/local-version PCM cache keys and basic PCM integrity checks.
- Signed extrema viewport tiles with a bounded LRU.
- Optional tiled WaveformPainter, default disabled; 323 tests and zero
  analyzer issues verified at Checkpoint 78 R3.
- Basic stage timing and allocated peak-count diagnostics.

Still incomplete:
- AudioProcessor extracts *all* PCM and eagerly creates all zoom
  levels even with tiled painting enabled. The experimental mode does
  not yet provide proven end-to-end peak memory reduction.
- PCM downsampling is an arithmetic mean, which can discard
  opposite-signed transients; investigate streaming peak-preserving
  reduction before changing the visual representation.
- No robust cache-as-compressed-peaks format or atomic promotion yet.
- No actual native FFmpeg cancellation; late state updates are ignored,
  but obsolete extraction may still consume resources.
- Android SAF source timestamp/version changes are not fully tracked.
- Real Android/Windows end-to-end benchmarks have not been run.
- Audio timestamp gap handling and precise audio track selection
  need targeted tests and a platform-by-platform policy.
- Independent static/dynamic repaint layers, shot snapping, speech-only
  waveform, and spectrogram remain future work.

## 4. Revised next milestones and tests

**Checkpoint 79 / W2-W3: eliminate eager zoom buffers in experimental mode**
1. Preserve the current default eager pipeline; experimental tile mode
   should use zoom *metadata* without full-track arrays.
2. Preserve current time-to-pixel and zoom index semantics, seek,
   subtitles, and same-unit scrolling.
3. Prove that both the initial pipeline and renderer no longer
   allocate a full track's zoom pixels in tile mode.
4. Test zero-length audio, stereo, silence, high/low transients,
   edge windows, zoom changes, stale requests and long streams.

**Checkpoint 80 / W3: peak streaming, cache integrity, audio PTS**
1. Stream PCM from FFmpeg into bounded peak records; use a cache
   format with validated headers, version, source/audio-track identity,
   and complete-write promotion.
2. Validate FFmpeg timestamp gaps on screen recordings and
   make selected audio track failures visible rather than silently
   changing stream identity.
3. Add cancellation of obsolete extraction and safe temp cleanup.
4. Unit-test corrupt, truncated, oversized, mismatched and
   interrupted caches; include samples at -32768 and 32767.

**Checkpoint 81+ / W4: rendering and interaction**
1. Separate static/background waveform drawing from dynamic playhead,
   cue overlays and drag visuals; benchmark repaint churn.
2. Add frame/grid/shot-change snap policies with screen-pixel
   thresholds, explicit override and whole-cue duration preservation.
3. Regression-test touch gestures, mouse wheel modifiers, high-DPI,
   fractional scrolling, subtitle text overlays and transactional
   timing edits.
4. Research spectrogram and speech-only waveforms as optional
   separately bounded services after baseline stability is proven.

## 5. Research and licensing caveats

This review used Subtitle Edit's latest visible main source at the
stated SHA, not its older Windows-only SE4 architecture. The reviewed
implementation uses C#/Avalonia/SkiaSharp and is not drop-in Flutter
code. Subtitle Composer uses C++/Qt/KDE and its own threading model.
Any described Flutter item marked "proposal" is an architectural
recommendation, **not** a feature already shipped or tested.

Use independent Dart/Flutter designs and tests. Do not copy code or
bundled assets from either project without an explicit license review.
Do not conflate waveform reduction, speech separation, speech-to-text
transcription and FFT spectrogram generation.

Reference links:
- https://github.com/SubtitleEdit/subtitleedit/tree/30d8f08cd654440f62507dc04e44d88b5807aa1c/src/ui/Logic/Media
- https://github.com/SubtitleEdit/subtitleedit/tree/30d8f08cd654440f62507dc04e44d88b5807aa1c/src/ui/Controls/AudioVisualizerControl
- https://github.com/SubtitleEdit/subtitleedit/tree/30d8f08cd654440f62507dc04e44d88b5807aa1c/tests/UI/Logic
- https://github.com/SubtitleEdit/subtitleedit/tree/30d8f08cd654440f62507dc04e44d88b5807aa1c/tests/benchmarks
- https://github.com/SubtitleEdit/subtitleedit/blob/main/docs/features/audio-visualizer.md
- https://github.com/SubtitleEdit/subtitleedit/blob/main/docs/features/settings.md
