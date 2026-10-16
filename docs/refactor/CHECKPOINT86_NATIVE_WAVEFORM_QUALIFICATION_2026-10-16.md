# Checkpoint 86 — Native Waveform Qualification (R1)

**Date:** 2026-10-16  
**Repository:** `anzilr/SubtitleStudio`  
**Branch:** `refactor/riverpod-architecture`  
**Starting HEAD:** `c49cbe7`  
**CP86 R1 code:** [`18ea029`](https://github.com/anzilr/SubtitleStudio/commit/18ea02927ed792df3150e4415a8fc34cc64044e6)  
**Flutter CI:** [Run 38937320025](https://github.com/anzilr/SubtitleStudio/actions/runs/38937320025) (launched; check run for completion)  
**Last green baseline:** 470 tests, 0 analyzer issues, [38933989670](https://github.com/anzilr/SubtitleStudio/actions/runs/38933989670)  
**Native qualification:** NOT YET APPROVED. No physical Android or Windows tests were performed in CI.

## Scope and freeze

CP86 qualifies the existing compact/peak/tiled waveform implementation on
Android 14 (OnePlus CPH2381; approximately 360dp) and Windows. Preserve R6
bounded-memory mode, R7 provider build-phase/atomic playback protection, and
R8 narrow toolbar fixes. **Appearance, new skins, historical UI rework, the
desktop workspace, and unconnected feature work remain paused.** Do not merge
into the upstream or release branch based on a Flutter-only CI result.

## R1 code findings and corrections

1. The Windows/Linux FFmpeg path built a verified `-map 0:N` from
   `ffmpeg:stream:N`, but its debug log independently called the audio-only
   ordinal parser on that same ID, throwing `FormatException` before native
   extraction. Debug logging now uses the plan's selected stream map.
2. Android's `content://` waveform path did not persist the compact
   `.pk1` cache, but could still reduce an old persisted raw PCM file keyed
   by the unchanged URI; a document provider may change content without
   exposing an mtime/version. Legacy PCM reduction is now limited to
   stat-able path inputs.
3. A SAF failure/cancellation after compact build could leave `.pk1`
   behind, even though successful decodes deleted it. Transient SAF peak
   cleanup now runs in a `finally` block **inside the cache lock**; abandoned
   previous outputs are rejected before another decode. Old PCM files are
   not destructively deleted or migrated.
4. When Android cannot acquire an FFmpegKit SAF read handle, the code now
   reports a document-access error and asks for reselection instead of
   passing the unresolved `content://` URI to FFmpeg. Permission-provider
   internals and URI values are not inserted into the error string.
5. Tests exercise authorized/null/blank/revoked SAF mapping, cross-platform
   path bypass, the actual stream-map description and post-stream
   cancellation preserving an existing valid peak cache without partials.

These are targeted reliability corrections, not proof of a native fix on a
particular device. R6's original debug disconnect had no proven OOM trace.

## Physical-device acceptance matrix

| Area | Android 14 CPH2381 | Windows | Pass / failure evidence |
|---|---|---|---|
| Local path | Long MKV, reopen and zoom | Long MKV path and filename with spaces | Correct peak and stable playhead; no exceptions |
| SAF | Pick original MKV as `content://`; reopen/revoke access/replace same document | Not applicable | Grant works or fails visibly; no stale cached waveform |
| Old cache | Use the historical ~660 MB raw PCM and collection | Existing large raw PCM if available | Stream conversion, no huge `readAsBytes` allocation in tiled mode |
| Tracks | Auto, explicit #1/#2, rapid switch | Auto, explicit #1/#2, rapid switch | Correct libmpv `ff-index` mapping; no obsolete track waveform |
| Timing | Playback/seek/auto-scroll; delayed PTS track | Same using synthetic two-track MKV | Waveform follows chosen audible stream and PTS gap |
| Lifecycle | Close/reopen, hide, rotate, background, exit during decode | Close/reopen, replace media, dispose during decode | No late provider write, no partial promoted cache |
| Cache failures | Corrupt/truncate `.pk1` in a disposable test project | Same | Regenerate or useful error; no data loss |
| Performance | Debug then **profile** for memory/CPU/framerate | Tiled on/off and resource samples | No runaway memory, process death, repeated huge allocation or UI stalls |

Use a **disposable test session or backup** before manually corrupting a cache.
For SAF source replacement, test with a document provider that really
preserves the same URI; do not assume copying another file gives that identity.

### Controlled multi-track fixture (Windows PowerShell)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/waveform/checkpoint82_ffmpeg_probe.ps1
```

The fixture is `build/waveform_checkpoint82/multitrack_pts_gap.mkv`:
two distinguishable audio streams (440 Hz and 880 Hz), with the second
offset by 1.25 seconds. The script checks FFmpeg's mapping and outputs
`waveform_probe.json`. **It does not verify Flutter or native Media Kit.**

### Android: debug, profile, logs

```powershell
git fetch origin
git switch refactor/riverpod-architecture
git pull --ff-only origin refactor/riverpod-architecture
flutter pub get
flutter run --debug -d CPH2381 --dart-define=MS_ONE_WAVEFORM_TRACK_SYNC=true

# Run again in profile for useful memory/CPU behavior.
flutter run --profile -d CPH2381 --dart-define=MS_ONE_WAVEFORM_TRACK_SYNC=true

# Keep full flutter console/exception logs and capture native buffers:
adb -s CPH2381 logcat -b crash -d -v time > cp86_android_crash.txt
adb -s CPH2381 logcat -b main -b system -d -v time > cp86_android_system.txt
adb -s CPH2381 shell dumpsys meminfo org.malayalamsubtitles.studio > cp86_android_meminfo.txt
```

Android's compact/tiled processing is the default since R6. An explicit
`MS_ONE_TILED_WAVEFORM=true` remains usable but is not necessary for the
normal Android trial. Switch tracks with `MS_ONE_WAVEFORM_TRACK_SYNC=true`
to exercise the experimental mpv-to-FFmpeg mapping. Logcat files and debug
console may contain private media paths or metadata; redact before sharing.

### Windows: experimental mapping and memory comparison

```powershell
flutter run -d windows --dart-define=MS_ONE_TILED_WAVEFORM=true --dart-define=MS_ONE_LAYERED_WAVEFORM=true --dart-define=MS_ONE_WAVEFORM_TRACK_SYNC=true
```

Open the controlled MKV and a long real MKV. Alternate Auto/explicit streams,
rapidly replace media, interrupt extraction, re-open, seek, zoom and monitor
RAM/CPU using Task Manager or Process Explorer. Compare normal Windows
(default eager) with explicit tiled mode, but don't use a huge file for an
unbounded eager trial without monitoring. Confirm system `ffmpeg` and
`ffprobe` are installed and available on PATH. Record `-map`, native
stderr and selection IDs, especially for `ffmpeg:stream:N`.

## Automated versus native evidence

- Existing regression suites already cover versioned checksummed peak
  caches, cache locking/janitor, load epochs, lifecycle/provider frames,
  mpv stream resolution, track reload races, timeline parity, and compact
  waveform tiling.
- New R1 regression tests cover gaps above without changing visual surfaces.
- GitHub Actions Linux Flutter analysis/unit tests **do not** establish that
  native FFmpegKit has SAF access, that mpv emits `ff-index` on Android or
  Windows, or that native peak-RSS/frames remain within an acceptable bound.
- No historical Isar migration, parser/export encoding change, dependency
  upgrade, upstream merge or native release has been performed.

## Qualification decision / next work

**Status: IN PROGRESS.** R1 code is landed; native Android 14/CPH2381 and
Windows matrix and actual measurements are outstanding. A later CP86 report
must record device build mode, test media/stream IDs, source type, cache
size, decode duration, sample memory/CPU, exception logs, and per-row pass/fail.
Reproduce and fix any native discrepancies before marking CP86 accepted.
Following CP86, continue typed file/SAF identity, persistence ownership,
Editor-controller decomposition, encoding hardening and isolated toolchains.
