# CP86 R5 — Decode versus peak-cache profiling (October 20, 2026)

**Branch:** `refactor/riverpod-architecture`
**Scope:** Dart-only instrumentation and regressions; no decoder/cache-format behavior change, no Android/Windows platform build in CI.

## Why

CP86 R4 physical-device capture found long-MKV cold waveform creation at 145,942 ms but warm loads at 1,879 / 1,865 / 1,845 ms. Existing `sourceAcquisition` combined native FFmpeg extraction, source-grant resolution, and peak conversion. Without stage attribution it is not safe to claim which component should be optimized.

## Implementation

- Add optional immutable `WaveformAcquisitionTimings`, with no source URI, original media filename, or sensitive SAF locator.
- Add independent timings in `AudioProcessor` for successful FFmpeg extraction and streamed peak-cache creation. For existing compact cache hits, time validated cache reads; for legacy PCM conversions, measure stream reduction separately. The Windows/Linux and Android/Apple FFmpeg entry points share the same stage semantics.
- Include the breakdown in `WaveformProcessingMetrics.toString()` without removing the existing `source= / downsample= / zoom= / total=` measurements.
- Reset metrics at the start of each request. Only record stage metrics for a still-current epoch, so late canceled requests do not overwrite a new load's result.
- Unit coverage checks cold FFmpeg/peak separation, cache-only logs, and backward-compatible summary formatting.

## Physical CP86 R5 acceptance: Android + Windows

Use a long video test file already available on the device and without deleting user projects. On OnePlus CPH2381:

```powershell
git fetch origin
git switch refactor/riverpod-architecture
git pull --ff-only origin refactor/riverpod-architecture
.\tool\capture_android_back_log.ps1 -Device CPH2381 -Fresh -Output cp86_r5_waveform.log
```

Run clean debug as usual, load waveform for a first-time media/track identity and reopen twice with the same source. For a *new* cold identity (not already cached), use a disposable test video or distinct valid audio track; do not clear Isar or forcibly delete cache files. Find the line `AudioProcessor: Processing complete:` and compare `source=`, `acquisition=`, `ffmpegMs=`, `peakMs=`, `cacheMs=`. Test Auto and explicit track, resume Editor, cancel/load another session during decode, and verify no canceled result replaces the next session's data.

On Windows repeat with the same MKV and a valid FFmpeg install. Compare cold and cached timings and inspect the selected `-map` source track. No Android/Windows success or speedup is claimed from unit CI; operator logs must confirm the native behavior.

**Expected output examples (not benchmarks):**
- Cold: `acquisition=ffmpegCompactBuild ffmpegMs=... peakMs=... acquisitionBytes=...`.
- Warm: `acquisition=compactPeakCache cacheMs=... acquisitionBytes=...`.

**Retained blocker:** the `media_kit` hot-restart SIGSEGV remains separately unverified; ordinary CP87 R13 Back/tap behavior has passed physical-device QA.

## Latest Flutter-only quality gate

[Run 39454515948](https://github.com/anzilr/SubtitleStudio/actions/runs/39454515948) succeeded on 2026-10-20 against `4ce284d`, with **543 tests passed and zero analyzer issues**. Includes both R5 stage profiling and the R6 allocation-free writer/golden round trip. No platform builds were run. Native performance impact and Android/Windows acceptance remain unverified.
