# Checkpoint 81 — Concurrent peak-cache operations and layered painting

Date: 2026-10-14
Branch: refactor/riverpod-architecture
Baseline: Checkpoint 80 R2, 334 passing tests, zero analyzer issues.

## Architecture and source references

This step builds on our studies of KDE Subtitle Composer's separation
of waveform processing, visualizer widgets, and view state, and
Subtitle Edit's cache corruption, peak generation, and rendering tests.
It is independently authored Flutter/Dart code. No upstream files or
GPL sources have been copied.

## 1. Lock/queue individual peak-cache operations

New WaveformCacheCoordinator uses a per-file FIFO queue shared within
the Dart isolate. Different media/cache destinations can proceed
concurrently; operations targeting the same destination serialize
validation, deletion, rebuild, and promotion. This prevents two
AudioProcessor instances from racing to overwrite or invalidate the
same peak file in the ordinary single-isolate UI architecture.

Waiters check their request epoch before acquiring file ownership
and after each awaited operation, so a superseded load cannot publish
or replace stale data once it starts. The active extraction still uses
Checkpoint 80's session-scoped desktop/FFmpegKit cancellation.

Limit: coordination is within a Dart isolate, not a cross-process
advisory file lock. External processes/native isolates must not use
these cache paths concurrently without stronger locking.

## 2. Conservative cleanup of expired artifacts

New WaveformPeakCacheJanitor scans only files matching strict
SubtitleStudio-generated names. It considers complete peak caches
older than 30 days and interrupted partial writes older than 2 hours,
with a hard per-invocation scan limit of 4096 entries.

- It does not delete raw PCM, source videos, unrelated files or fresh
  peak caches.
- Callers protect their own cache destination from pruning.
- File disappearance, permission errors, and racy deletions are handled
  best-effort.
- This is a temporary-cache retention policy, not permanent backup.
- Staging files from active generation remain protected by age cutoff.
  Large/very slow generation exceeding the cutoff on another isolate
  remains a theoretical limitation to address via lock files/process
  coordination if needed.

Experimental audio processing invokes cleanup when entering the
cache-specific critical section and gives the current path explicit
protection. Temporary PCM filenames now include a monotonic identifier
to avoid two same-microsecond extractions choosing the same name.

## 3. Opt-in split waveform painter

WaveformPainter supports a WaveformPaintLayer value:
- combined (the existing unchanged/default paint order);
- scenery (background + waveform);
- overlays (subtitle/add line overlays, playback cursor, centerlines).

The widget can use MS_ONE_LAYERED_WAVEFORM=true to enable separate
CustomPaint passes and a RepaintBoundary around static scenery. The
already existing independent subtitle overlay painter remains intact.
No mobile interaction handling, gesture hit testing, or layout is
changed in the default build.

The scene reuses the same paint input parameters and has independent
shouldRepaint comparisons: cursor motion invalidates overlays but not
the scenery renderer. Scroll and zoom invalidate both layers.

Test output compares RGBA bytes of the combined painter and sequential
scenery/overlays passes with playhead at multiple positions. Actual
frame-rate or physical-device repaint profiling remains outstanding.

## Quality and regression coverage

- Multiple callers to the same key proceed sequentially; unrelated
  keys are not unnecessarily serialized.
- Failure releases a lock so subsequent operations can retry.
- Superseded waiters do not execute stale cache mutations.
- Expired partial/complete caches are selectively pruned, with current
  destination, raw PCM and unrelated files protected.
- Layered/combined raster output and shouldRepaint isolation.
- Prior 334+ tests continue covering imports, exports, backup,
  waveforms, Isar/checkpoints, subtitles and geometry.

## Follow-up qualifications

- Does NOT provide native Android/Windows UI profiling or certification
  of process-level File.rename replacement semantics.
- On-device FFmpeg cancellation, multi-track media ID indexing,
  timestamp gap alignment, and SAF source invalidation need real-media
  testing; CI uses analyzer and Flutter tests, no five-platform builds.
- Renderer split must remain experimental until profiles show reduced
  repaint work with no jank or visual regressions at high DPI.
- Concurrency is single-isolate only. Future work: process-safe lock
  strategy if running multiple waveform workers/processes on one store.
- Rendering peak extrema retained in compact caches without loading
  full peak arrays is still a future scalability improvement.
- Isar schema, main/upstream branches, release tags and desktop
  workspace are left untouched.

## Verified R2 gate and correction

- [Verified code commit `266f038`](https://github.com/anzilr/SubtitleStudio/commit/266f0382917d743bd41a325c63f6387bfde0d6d6).
- [Successful GitHub Actions run 38617605939](https://github.com/anzilr/SubtitleStudio/actions/runs/38617605939).
- `flutter analyze`: **No issues found**, including informational notices.
- `flutter test -j 1`: **344 tests passed**; 10 new tests relative
  to Checkpoint 80 R2 (334 passing).
- The R1 gate had one failing newly added repaint test, because the
  fixture created a different ZoomLevel instance in its second frame;
  the scene correctly repainted when zoom identity changed.
  R2 reused the same zoom object for a playback-only update. No
  production code changed between R1 and R2. The composed-image pixel
  parity test already passed in R1 and remains green in R2.
- Native device timing, actual peak RSS, FFmpeg cancellation on every
  target platform, and process-to-process file locking remain untested.
- Documentation-only commit does not trigger extra CI usage.
