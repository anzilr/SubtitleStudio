# Subtitle Composer source audit — encoding and waveform

Date: 2026-10-13
Source: user-provided archive `subtitlecomposer(1).zip`
Archive root: `subtitlecomposer/` (583 ZIP entries, includes a `.git` directory).
Status: **source study / roadmap input only**. No copied KDE C++ or new Flutter waveform feature in this checkpoint.

## 1. Encoding implementation (verified in attached source)

### Source files
- `src/formats/formatmanager.cpp` (encoding detection, text read, text write)
- `src/dialogs/encodingdetectdialog.cpp` (ranked detection/preview)
- `src/actions/kcodecactionext.cpp` (open vs save codec selection)

**Detection:** the manager runs ICU `ucsdet_detectAll()` and its confidence when ICU is available, otherwise KDE's `KEncodingProber`. Ranked alternatives are shown in an interactive dialog. The dialog previews the *original raw bytes* decoded with whichever codec the user selects. Its available encodings are grouped by writing system/language via `KCharsets::charsets()->encodingsByScript()`.

**Reading:** it detects/converts raw text into Unicode **before** asking the subtitle format parsers to parse it; it normalizes CRLF/CR to LF. The reviewed version reads only the first 1 MiB with `file.read(1024 * 1024)`; this is a limitation, **do not adopt that truncation** in SubtitleStudio.

**Writing:** codec conversion happens after format compilation, newline policy is selectable, and the file is written with `QSaveFile`/commit. However, the inspected implementation prepends a BOM to every codec whose name begins with `UTF-` or includes `UCS-`; this is not acceptable for SubtitleStudio's planned exact UTF-8 BOM/no-BOM preservation. It does not demonstrate symmetric strict error handling for every legacy codec.

**Adopt for Flutter:** candidate ranking + byte-based text preview + script-grouped manual override; strict codec support checks, BOM precedence, explicit save-encoding/BOM choices, no automatic incorrect UTF-8 fallback, full-file parsing, and atomic file writing where the target filesystem API permits.

## 2. Waveform design in attached source

| Source file | Actual responsibility | Idea for SubtitleStudio |
| --- | --- | --- |
| `src/gui/waveform/wavebuffer.cpp/.h` | Receives streamed PCM audio callbacks, builds bounded decimated per-channel waveform; handles timestamp gaps/overlaps | Move toward incremental PCM/chunk indexing and bounded cache; verify gap/overlap handling and stop/cancel |
| `src/gui/waveform/zoombuffer.cpp/.h` | Worker thread materializes zoomed pixel statistics; when possible prioritizes the requested visible range and reports partial availability | On-demand/lazy visible-range zoom tiles instead of eagerly generating every zoom level for long media |
| `src/gui/waveform/waverenderer.cpp/.h` | Paints waveform channels, selection, subtitles, playhead and pointer; colors configurable | Keep renderer separate from decoding and input handling; bound repaint scope |
| `src/gui/waveform/waveformwidget.cpp/.h` | Coordinates zoom, time window, auto-scroll, seeks, mouse events, subtitle selection and audio track | Make timeline viewport state a reusable explicit controller; preserve playhead position when zoom changes |
| `src/gui/waveform/wavesubtitle.cpp/.h` | Distinct drag modes: subtitle left edge (show), whole cue, right edge (hide); anchor-aware prohibitions | Reuse explicit drag-intent model with snapping/tolerance; atomic timecode writes only on accepted drag |
| `src/videoplayer/waveformat.h` | Validates sample rate, channel count and PCM sample format | Validate actual PCM and channel metadata at processor boundary |

### Specific algorithms/behavior worth testing

- The incoming audio stream is decimated to a bounded number of samples/second in `WaveBuffer::onStreamData()`, retaining channel separation.
- `ZoomBuffer::updateZoomRange()` aggregates **mean absolute amplitude and maximum absolute amplitude** into a display bucket (`min` is named misleadingly). SubtitleStudio already uses **signed min/max** for its zoom samples, so *do not substitute one without assessing the visual result*. Compare implementations by waveform visibility and transient preservation.
- `ZoomBuffer::zoomedBuffer()` requests only the time-window interval; the worker can prioritize it. The design has interruption/restart paths and partial buffer availability.
- Zoom calculations use samples-per-pixel and sample rate to map time to buffer indices; changes of zoom adjust the time window around the existing center.
- Drag hit tolerance scales with samples-per-pixel and sample rate, and start/whole/end drag modes are distinct. The model includes an anchor-based forbidden mode.
- The C++ implementation owns Qt threads and pointers; do not copy its synchronization or allocations into Dart. Prefer isolates, cancellation tokens and bounded memory according to Flutter platform support.

## 3. Comparison with current Flutter SubtitleStudio

Inspected current files on `refactor/riverpod-architecture`:
- `lib/features/waveform/services/audio_processor.dart`: extracts FFmpeg PCM, caches by subtitle collection, reads cached PCM, downsamples and produces zoom levels.
- `lib/features/waveform/services/zoom_buffer_generator.dart`: **eagerly generates multiple full-track zoom levels** using per-pixel signed min/max.
- `lib/features/waveform/providers/waveform_controller.dart`: Riverpod owner but still includes compatibility-style `dispatch(WaveformEvent)` and event handlers.
- `lib/features/waveform/widgets/waveform_painter.dart`: custom painter currently mixes many overlays and feature display options.
- `lib/features/waveform/repositories/waveform_subtitle_repository.dart`: uses session-scoped V2 timing writes for active edits.

**Inference, not a proven benchmark:** long media may have high initial latency or peak memory from decoding/caching PCM and generating every full-track zoom level. Run memory/latency profiling on representative media before changing the architecture. Subtitle Composer's visible-range zoom work suggests a promising alternative but is not automatically faster on Flutter/Android.

## 4. Proposed waveform milestones

**W1 — Measure before changing:** baseline decode latency, first visible waveform latency, peak memory and zoom latency on short/long mono/stereo clips; high-DPI repaint cost; cancellation during file/screen change. Compare Android and Windows on user-testable systems.

**W2 — Decouple processing from viewport:** propose a `WaveformTileSource` or `WaveformAmplitudeCache` that serves time-window buckets at requested resolution; retain/compare existing precomputed zoom levels as a fallback. Design bounded LRU cache and deterministic invalidation by audio track/file identity.

**W3 — Cancellation/concurrency safety:** ensure late isolate/FFmpeg results cannot overwrite a newly opened session; avoid unbounded PCM allocations, redundant zoom recomputation or cached stale track metadata. Unit-test tile requests and cancellation; native device verification later.

**W4 — Interaction and renderer:** support independent start/end/whole-cue drag modes, zoom anchored on playhead or pointer, auto-scroll pause/resume, selection sync, waveform and subtitle overlays. Keep persistence via V2 timing mutation API with optimistic snapshots.

**W5 — Platform parity:** same core behavior on Windows/Linux/macOS/Android/iOS using existing media abstraction; no new platform-bound Qt code. Do not start desktop workspace merely to implement waveform improvements.

## 5. Research priorities and caveats

The attached project is C++/Qt/KDE, not a drop-in Dart implementation. KDE code has its own licensing obligations; **design inspiration only**, no copying routines or assets into SubtitleStudio without explicit compatibility/legal review.

Do not conflate waveform peak/bucket statistics with audio transcription, silence classification or FFT spectrogram functionality. The inspected `zoombuffer.cpp` is a time-domain waveform aggregation, not an FFT analysis pipeline.

This research is separate from Checkpoint 67's Git-history reference migration code and requires no Flutter/native CI by itself.


## Complementary source: Subtitle Edit (reviewed 2026-10-14)

The KDE source study remains valid for streamed audio, viewport-oriented
zoom work and interaction ownership. A separate audit of Subtitle Edit's
Avalonia/Skia implementation and source-level tests is recorded in
[Subtitle Edit waveform source study](SUBTITLEEDIT_WAVEFORM_SOURCE_AUDIT_2026-10-14.md).
Subtitle Edit adds useful details on peak caches with corruption/atomic
write tests, audio timestamp-gap preservation, static scenery layer
caching, per-device-pixel peak extrema, and whole-cue shot-change
snapping. These are references for future Flutter work, not copied
implementations or claims that the current app already has them.
