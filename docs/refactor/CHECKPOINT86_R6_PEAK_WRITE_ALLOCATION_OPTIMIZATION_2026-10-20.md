# CP86 R6 — Allocation-free compact peak record writer (2026-10-20)

**Branch:** `refactor/riverpod-architecture`. This checkpoint follows R5 native acquisition profiling. No file-format version change, no schema change, no user-facing design change.

## Why this matters
R4's physical Android test produced approximately 20 million reduced samples on a long MKV. The V2 peak writer allocated a `ByteData(2)`, derived a `Uint8List`, hashed each byte, and appended each small record to `BytesBuilder` for **every** sample. Such object churn is unnecessary even though the upstream FFmpeg output is already reduced to 2,756 Hz.

## Implementation
- Replace per-record allocations with one reused 24 KiB `Uint8List` and direct little-endian signed 16-bit writes.
- Hash the same two bytes in the same order using the existing FNV-1a checksum.
- V2 passes through the already reduced signed sample without recalculating min/max or averaging.
- V1 still emits the legacy average/min/max in the exact six-byte record order, using the same fixed batch.
- Preserve chunk-boundary handling, bounded reads, checks for canceled sessions, staged atomic writes, corrupted-header rejection, and cache version numbers.
- Add a 60,001-sample golden round trip asserting binary payload equality and independent checksum across several full 24 KiB buffer flushes.
- R5 stage instrumentation distinguishes FFmpeg native extraction time from this Dart reduction cost. Only an Android debug/profile run can measure real speedup; CI tests alone do not prove performance improvement.

## Remaining CP86 native qualification
Run on CPH2381 with a fresh source/track identity and compare `ffmpegMs`, `peakMs`, `cacheMs` from `AudioProcessor: Processing complete`; also reopen the same file twice and test cancellation, alternate audio streams, seeking, waveform gestures, and large-file memory. On Windows use `--dart-define=MS_ONE_TILED_WAVEFORM=true` when testing the compact writer rather than the default eager PCM pathway. Keep the verified CP87 R13 MSone Back recovery unchanged.

## Latest Flutter-only quality gate

[Run 39454515948](https://github.com/anzilr/SubtitleStudio/actions/runs/39454515948) succeeded on 2026-10-20 against `4ce284d`, with **543 tests passed and zero analyzer issues**. Includes both R5 stage profiling and the R6 allocation-free writer/golden round trip. No platform builds were run. Native performance impact and Android/Windows acceptance remain unverified.
