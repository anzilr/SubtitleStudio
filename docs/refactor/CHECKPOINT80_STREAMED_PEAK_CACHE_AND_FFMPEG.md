# Checkpoint 80 — Streamed peak cache and FFmpeg extraction safety

Date: 2026-10-14
Branch: refactor/riverpod-architecture
Verified code: 3631738304e6d4e61869cd1b0f892da41be7066f
Successful CI: https://github.com/anzilr/SubtitleStudio/actions/runs/38614517634
Quality: 334 passing Flutter tests, zero analyzer issues.
Baseline: Checkpoint 79 R2, 327 tests.

## Source research and scope

This checkpoint is an independent Flutter implementation informed by:
- KDE Subtitle Composer's streamed audio/zoom architecture:
  SUBTITLECOMPOSER_WAVEFORM_AND_ENCODING_SOURCE_AUDIT.md
- Subtitle Edit's compact peak files, corruption tests, timestamp-gap
  extraction and independent render-cache approach:
  SUBTITLEEDIT_WAVEFORM_SOURCE_AUDIT_2026-10-14.md

No code or bundled assets from either project were copied.

## 1. Streamed PCM-to-peak reduction (experimental only)

New lib/features/waveform/services/waveform_peak_cache.dart processes
FFmpeg's s16le, 44,100 Hz mono PCM from a file stream in bounded chunks.
It never calls readAsBytes() on the full-resolution PCM in this path.

One output frame summarizes 16 source samples:
- signed mean: retained in WaveformData for legacy rendering parity;
- signed minimum and maximum: stored in the peak cache for later
  peak-preserving rendering and silence/transient visual modes.

The resulting display sample rate follows the prior downsampler's
44100 >> 4 = 2756 Hz convention, with any incomplete trailing group
omitted to preserve existing geometry. This mode bypasses the old
full-PCM downsampling pass; ZoomLevel metadata remains lazy from
Checkpoint 79 and viewport tiles remain bounded from Checkpoint 77.

At this reduction granularity, the on-disk record is six bytes per
16-input-sample frame, compared with 32 bytes of original 16-bit PCM.
This is a structural size reduction, NOT a measured peak-RSS saving.

## 2. Cache validation and safe promotion

- SWPK version-1 header records input/output rates, frame size,
  frame count, record width and FNV-1a checksum of the peak payload.
- The reader validates the header, file size, frame-count bounds,
  checksum and min <= mean <= max before allowing reuse.
- New caches are written to a uniquely named partial file, flushed
  and renamed into place only after complete generation.
- Cancellation or failure removes the partial file and keeps a
  previously complete target untouched. Platform-specific rename
  behavior (especially replacement on Windows) still needs native
  verification.
- The cache path is source/selected-track/local-file-version scoped,
  based on Checkpoint 77 identity policy.
- Android content URI sources are regenerated, not blindly reused,
  because a stable URI alone cannot certify source freshness.
- Legacy Isar PCM cache fields are untouched. This is an independent
  compact cache used only in the experimental tiled pipeline.

## 3. FFmpeg extraction and request safety

- The desktop path now uses Process.start() rather than Process.run(),
  allowing cancellation of the active FFmpeg process.
- FFmpegKit uses asynchronous sessions with cancellation scoped to
  that session ID; unrelated FFmpegKit sessions are not cancelled.
- WaveformController cancels obsolete native decoding when a new load
  starts, on ClearWaveform, and on disposal. Late results are also
  rejected by the earlier load-epoch guard.
- The raw extraction temp file is removed after streamed reduction,
  and when an interrupted/failed temporary extraction is detected.
- PCM reduction itself accepts an epoch-based cancellation callback.
- The extraction filter includes aresample=async=1:first_pts=0 to
  preserve presentation-timestamp gaps such as those found in some
  screen-recording audio. This needs real-media alignment testing.
- If a requested audio stream is invalid or FFmpeg cannot select it,
  extraction fails visibly rather than silently switching to the
  default stream. Numeric media-kit ID interpretation remains a
  legacy 1-based/0-based heuristic and requires device qualification.

## 4. Tests and CI

New deterministic tests cover:
- exact mean parity with legacy decimation across chunk boundaries
  and for incomplete trailing frames;
- both signed 16-bit extrema (-32768, +32767);
- valid compact cache reload;
- corrupt/forged headers, checksum mismatch, truncation, bounded
  allocations and invalid PCM length;
- failed generation does not replace a complete cache.

The existing Riverpod race tests caught an R1 disposal problem:
ref.read() is forbidden inside onDispose lifecycle callbacks.
R2 resolves the processor dependency in build() and captures it
before registering the disposal callback.

GitHub Actions R2:
- flutter analyze: No issues found;
- flutter test -j 1: 334 tests passed;
- test run: https://github.com/anzilr/SubtitleStudio/actions/runs/38614517634

No native five-platform builds, Isar schema migrations or
desktop-workspace UI changes were performed.

## 5. Known limitations / next checkpoint

1. FFmpeg still extracts a full PCM file to temporary DISK before it
   is streamed into compact peaks; native FFmpeg stdout/pipe streaming
   has not been integrated. The full PCM bytes are no longer loaded
   into Dart heap in experimental tiled mode.
2. The WaveformData mean array remains in memory for the current
   WaveformTileSource; extrema are stored on disk but not yet used
   by the painter. Visual parity is preserved at the cost of not
   displaying every transient. Streaming min/max pyramids and
   disk-backed window queries are a future opportunity.
3. There is no measured peak RSS or frame-time result from real
   Android, Windows or Linux devices. The standard eager pipeline
   remains the default unless MS_ONE_TILED_WAVEFORM=true is set.
4. Native FFmpegKit cancellation, PID cleanup, PTS gap handling and
   track-index mapping need realistic media/device integration tests.
5. Temporary peak cache eviction/orphan cleanup, concurrent same-source
   generation locks, in-place SAF source-version tracking and atomic
   replacement portability remain hardening items.
6. Peak caches in temporary storage may be purged by the operating
   system; regeneration is expected, never treated as permanent data.

Checkpoint 81 direction: device-oriented performance and waveform
interaction parity; evaluate foreground/background layer separation,
frame/shot snapping, full-source concurrency and native cancellation
tests, while avoiding a premature default-mode switch.
