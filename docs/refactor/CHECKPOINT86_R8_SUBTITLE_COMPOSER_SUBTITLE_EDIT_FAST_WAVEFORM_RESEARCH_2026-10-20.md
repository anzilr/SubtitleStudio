# CP86 R8 — Why Subtitle Composer and Subtitle Edit waveforms feel fast

Date: 2026-10-20
Research basis: user-provided `subtitlecomposer(1).zip` (583 entries); Subtitle Edit upstream `SubtitleEdit/subtitleedit` main at commit `cccac3af3262e15255aa6df8d91e9317ee598cc4`; current SubtitleStudio `refactor/riverpod-architecture` after CP86 R7.

**Status:** source review and experimental design only. No extraction behavior was changed in this checkpoint. Native performance claims below refer only to CP86 R6's measured OnePlus CPH2381 log; no same-hardware benchmark of either reference app was performed.

## 1. Our measured bottleneck

`cp86_r6_waveform_perf.log` demonstrates first full waveform load **137,089 ms**:
- Native FFmpegKit extraction: **134,990 ms** (**98.47% of full load**)
- Dart peak conversion: **1,881 ms**
- Zoom metadata: **24 ms**
- Warm reopen total: **1,953 ms**, including **1,825 ms** validated cache reading; cache was approximately 41.27 MB

SubtitleStudio's `WaveformFfmpegPlan` already decodes to low-rate **2,756 Hz mono s16le** (and uses `aresample=async=1:first_pts=0`). `AudioProcessor` waits for full `FFmpegKit.executeAsync` completion before `WaveformPeakCache.build` reduces a temporary file and publishes `WaveformReady`. Thus the user sees nothing useful until the *entire selected track* has been decoded. `WaveformTileSource` already provides visible-region rendering, but not partial source availability during extraction.

The R6 allocation optimization affects ~1.9 s peak processing, not ~135 s FFmpeg execution. Further Dart micro-optimization cannot materially solve time-to-first-waveform.

## 2. KDE Subtitle Composer source — progressive pipeline

Archive files inspected:
- `src/streamprocessor/streamprocessor.cpp` lines 356–365, 367–489: native worker `QThread::start(LowPriority)`; `av_read_frame`, `avcodec_send_packet`, `avcodec_receive_frame`, `swr_convert_frame`; each decoded frame immediately emits `audioDataAvailable(..., timeFrameStart, timeFrameDuration)` and `streamProgress(...)`.
- `src/gui/waveform/wavebuffer.cpp` lines 60–65, 74–86, 116–125, 146–238: direct signal connection receives decoded PCM in worker thread, reduces source sample rate by powers of two to **<= 3,000 samples/s**, accumulates per-channel samples and handles PTS holes/overlaps.
- `src/gui/waveform/zoombuffer.cpp` lines 75–153, 157–239: own thread reacts as `samplesAvailable()` advances; prioritizes requested visible range and sends `zoomedBufferReady` before the complete source exists.
- `src/gui/waveform/waveformwidget.cpp`: separate widget controls, zoom, selection and renderer.

**What makes it responsive:** the viewport can use *already decoded* frames while the remainder is still being processed; it does not wait for whole-movie extraction. **What it does not prove:** faster native full-duration decode on equivalent CPU/device/media. It still decodes the selected audio stream.

Caveat: this source eagerly allocates channel buffers based on its estimated duration plus 60 seconds and has Qt-specific thread/lifetime assumptions. Do not copy that allocation or synchronization scheme into Flutter.

## 3. Subtitle Edit upstream — compact peaks, cache, optimized renderer

Pinned source links:
- [WaveFileExtractor.cs](https://github.com/SubtitleEdit/subtitleedit/blob/cccac3af3262e15255aa6df8d91e9317ee598cc4/src/ui/Logic/Media/WaveFileExtractor.cs): spawns FFmpeg extracting **24,000 Hz, stereo WAV** with `-vn`, per-stream `-map` and `aresample=async=1:first_pts=0` to preserve timestamp gaps. An optional speech/front-center filter is available. Full extraction still takes time.
- [WaveToVisualizer2.cs](https://github.com/SubtitleEdit/subtitleedit/blob/cccac3af3262e15255aa6df8d91e9317ee598cc4/src/ui/Logic/Media/WaveToVisualizer2.cs) lines 682–931: `WavePeakGenerator2` streams WAV via 64 KiB `FileStream` and `FileOptions.SequentialScan`, reduces PCM to configurable min/max peaks (default **126 peaks/s** per [SeWaveform.cs](https://github.com/SubtitleEdit/subtitleedit/blob/cccac3af3262e15255aa6df8d91e9317ee598cc4/src/ui/Logic/Config/SeWaveform.cs)), and saves reduced peaks by atomic temporary-file promotion. A specialized 16-bit stereo SIMD path avoids intermediate float sample buffers.
- [SkiaWaveformRenderer.cs](https://github.com/SubtitleEdit/subtitleedit/blob/cccac3af3262e15255aa6df8d91e9317ee598cc4/src/ui/Controls/AudioVisualizerControl/SkiaWaveformRenderer.cs): one min/max representative per screen pixel and 256-device-pixel scroll-anchored static scenery cache; dynamic playhead/text overlays avoid rebuilding waveform scenery.
- [WaveformExtractionEstimate.cs](https://github.com/SubtitleEdit/subtitleedit/blob/cccac3af3262e15255aa6df8d91e9317ee598cc4/src/ui/Logic/Media/WaveformExtractionEstimate.cs): coarse, explicitly approximate codec-specific estimates; acknowledges heavy codecs such as TrueHD/MLP can decode far more slowly than AC3/AAC/MP3.
- [Audio visualizer docs](https://github.com/SubtitleEdit/subtitleedit/blob/cccac3af3262e15255aa6df8d91e9317ee598cc4/docs/features/audio-visualizer.md): cache/track behavior.

**What is faster:** reduction and rendering *after PCM is available*, plus rapid cached reopens. A 24-kHz stereo WAV is actually much larger than SubtitleStudio's 2,756-Hz mono temporary PCM: this does **not** evidence a superior first-run decoder on identical mobile hardware.

**Licensing:** attached Subtitle Composer headers are GPL-2.0-or-later. Subtitle Edit upstream license is MIT at the reviewed revision. Use independently designed algorithms and respect upstream license notices if copying any code; we are copying none in this review.

## 4. Comparison for SubtitleStudio

| Dimension | Current SubtitleStudio | Subtitle Composer | Subtitle Edit |
|---|---|---|---|
| Decode | FFmpegKit to full 2,756 Hz mono temp PCM, then await completion | Native libavcodec/libswresample, frame callbacks during decoding | FFmpeg process to full 24-kHz stereo WAV |
| UI first data | After **full** extraction + peak build | As new frames arrive | Generally after extracted waveform cache is generated or already cached |
| Peak data | 2,756 Hz V2 mono cache (~41.27 MB in measured long movie) | WaveBuffer reduces <= 3 kHz; separate on-demand zoom | Configurable compact signed min/max peaks; default 126/s |
| Rendering | Existing tile source after ready | Visible range zoom worker runs while source builds | SIMD peak reduction and scroll-anchored static scenery cache |
| Source/track freshness | Track/source-revision keys; SAF without reliable metadata does not persist | Stream ordinal and per-media decoding lifecycle | Media/track-specific peak cache |
| PTS | `aresample=async=1:first_pts=0` during full decode | Frame time offsets with hole/overlap logic | Same FFmpeg gap-aware aresample filter |

**Key finding:** observed first-use latency is determined by the amount of audio we insist on decoding *before* the waveform is usable. No source-code evidence establishes that one full-decode binary alone would remove the 135-s bottleneck.

## 5. Recommended CP86 R8/R9 experimental approach — fast viewport first

**Do not replace our shipping FFmpegKit pipeline yet.** First trial a seekable *partial preview* extractor behind a disabled-by-default flag on a dedicated experimental branch:

1. In the Editor, determine the current viewport's **absolute timeline range** and resolved audio stream. Start with **30–60 seconds** of audio around the playhead (not the entire video). Prefer the current segment over the beginning of a long movie.
2. Use the existing `WaveformFfmpegPlan` contract, but add a separately testable **windowed** FFmpeg plan with bounded duration, explicit audio mapping, `-vn`/no subtitle/data processing, and output PCM size limits. Investigate accurate `-ss` before/after `-i` performance and absolute PTS alignment. No silent wrong-track fallback.
3. Generate actual signed min/max or compatible amplitude buckets from just that window and publish **partial availability**, showing not-yet-decoded ranges as *unknown/loading*, never as silence.
4. Preserve absolute seek/edit mapping by anchoring every segment to the source-time origin and keeping its first sample's timestamp/codec priming. Retain gap padding within the segment, discontinuity handling and overlap avoidance. **Do not assume `aresample=async=1:first_pts=0` can simply be reused unchanged after a nonzero `-ss` without confirming the PTS offset.**
5. Cancel obsolete window decodes by source/track/generation. Cache per-window peaks in separate temporary track+source-revision+range keys; promote only complete validated segments. For unversioned Android SAF, never reuse after closing the request.
6. Continue background windows at low priority and/or allow a later full-duration stable peak cache, while editing the first viewport remains usable. Suppress heavy FFmpeg work during active playback if it causes dropped frames.
7. For next-stage streaming, investigate FFmpegKit native pipe support/FFmpeg callback availability; do not assume the current Flutter binding exposes decoded PCM frames. A native FFI/plugin layer would require its own memory, lifetime, thread and platform qualification.

This is a **time-to-first-usable-waveform** optimization, not a claim that a two-hour track can be fully decoded without work. Native full-file indexing can continue and have its own measured completion time.

### R8 acceptance experiment

Use the same long MKV as CP86 R6 and a controlled multi-track PTS-gap fixture, measure each on Android SAF and a seekable local file (then Windows):
- Time to first waveform at playback **0:00**, **30:00** and **90:00** vs baseline **137.1 s** whole-movie load.
- FFmpeg duration, source seek/startup overhead, memory and bytes written per preview window.
- Waveform/audio alignment after seeking and around timestamp gaps; compare with the full-cache reference.
- Auto and explicit audio tracks (including heavy codecs), cancellation/rapid selection, no stale callback, no partial file promotion, cache revision replacement.
- Behavior on nonseekable/slow DocumentsProvider: explicit safe fallback, never falsely report a segment as available.
- Reopened-editor responsiveness and preservation of CP87 R13 Back/touch handling.
- Flutter test/analyze-only CI; Android and Windows native builds/tests run locally.

**Decision gate:** If seekable partial extraction gives a substantial measured reduction in first-visible latency without offset/track errors, promote the optional mode to a broader progressive tile prototype. If not, benchmark a native streaming PCM-frame reduction layer as the alternative, not speculative resampler or Dart micro-optimizations.

## 6. Approaches NOT established by the reference code

- Changing `-ar 2756` to `126` alone does not avoid decoding compressed audio; it reduces downstream PCM bytes, potentially harming fine waveform detail.
- Adding `-vn` to raw audio-only output is sensible explicitness, but the selected s16le muxer already emits audio; it cannot account for 135 s by itself.
- Using GPU/HW video decoding does not automatically accelerate audio decoding.
- Changing to Media Kit/mpv or native libavcodec may improve architecture for PCM callbacks, but needs comparative same-device benchmarks; no guaranteed decode speedup.
- Retaining the entire movie in RAM to make progressive rendering easy would undo the bounded-memory work.

Result: **first usable viewport (short seeked extraction)** is the recommended low-risk first experiment; **native streaming frame callbacks** are a second phase if the first experiment fails or SAF seeking is unreliable.
