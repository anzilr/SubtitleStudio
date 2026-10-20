# CP86 R9 — Seeked waveform-window extraction benchmark (experiment)

**Date:** 2026-10-20
**Branch:** `experiment/cp86-r9-windowed-waveform-preview` (separate from `refactor/riverpod-architecture`)
**Status:** working debug-only seek-window **probe**, *not yet progressive waveform UI*. Physical Android/Windows measurements and PTS-gap fixtures required before adopting any extraction behavior.

## Objective

CP86 R6 device log on CPH2381 showed 137,089 ms cold waveform, including 134,990 ms FFmpeg, 1,881 ms peak-cache construction. Our current Android path blocks `WaveformReady` until every second of the media stream is decoded.

KDE Subtitle Composer's progressive WaveBuffer/ZoomBuffer design allows rendering already decoded samples; Subtitle Edit stores compact validated peaks. Our R9 first stage isolates one question: **how long does FFmpegKit require to seek and decode only 30 seconds from a multi-hour media file on this Android device, and do those samples align with the existing full-waveform cache?**

## Implemented

- Independent `WaveformWindowFfmpegPlan` holds start, duration (max 60 s), seek mode, existing selected stream ID, 2,756-Hz mono signed PCM output.
- Seek mode `inputFast`: `-ss` *before* `-i`, FFmpeg accurate seek is left enabled. `outputAccurate`: `-ss` *after* `-i`, which may require decoding the lead-in. Both include `-t`, `-vn`, `-sn`, `-dn`, and unchanged `aresample=async=1:first_pts=0`. **That filter alone does not establish absolute alignment after `-ss`; verify the output against the full extraction.**
- Debug-only `AudioProcessor` probe gated by `MS_ONE_CP86_R9_WINDOW_PROBE=true`. Runs before the normal cached/full operation, reads only the bounded temporary PCM, measures native FFmpeg milliseconds, deletes the file, then proceeds through the original unchanged waveform pipeline. **The probe adds temporary extraction work; do not judge the total UI open time with this flag enabled.**
- Uses exactly the shipping source-path normalization, Android SAF read parameter, selected FFmpeg track map, `cancelActive` epoch guard, process-specific termination, and temporary-file cleanup. No new on-disk cache identity/version, data schema or application navigation changes.
- Reports `CP86 R9 WINDOW seekMode=... startSeconds=... durationSeconds=... ffmpegMs=... pcmBytes=... samples=... stream=...`. Does not print source URLs/paths in this new message (other older debug logs may still contain paths).
- After the normal full waveform is available, reports `CP86 R9 ALIGNMENT samples=... lagSamples=... relativeError=... inconclusiveSilence=...`. The relative error comes from a bounded signed PCM comparison near the seek position and allows a ±100-ms lag scan. **This is a correlation diagnostic, not PTS correctness certification**, particularly near discontinuities or silence.
- Pure Dart regression tests for seek argument placement, limiting duration, preserved audio stream choice/SAF-compatible escaping, invalid user track and path rejection, no output beyond bounded raw PCM, subsecond seeking and alignment behavior.
- `run_android_clean_debug.ps1` now optionally accepts named Dart defines; old usage remains compatible. Flutter CI triggers are limited to analyzer and tests on this experiment branch.

## Flutter-only CI acceptance

[GitHub Actions run 39461127483](https://github.com/anzilr/SubtitleStudio/actions/runs/39461127483) — **successful**, 2026-10-20. **552 Flutter tests passed**; analyzer had **zero errors**, with one pre-existing informational unused-import lint in `lib/screens/msone_input_diagnostics.dart`. Tested bounded seek-window construction and quote behavior, track selection, time arguments, invalid input rejection, comparison diagnostics, and all existing application regressions. **No Android/Windows or other platform builds ran in Actions.**

**Still pending:** same-media native fast-vs-accurate seek profiling at start offsets 0/1800/5400 seconds, nonzero PTS stream handling, Android SAF seeking, and preview alignment / cancellation on device. Full progressive rendering is not yet implemented.

## Run on local Android OnePlus CPH2381

Save any local edits before switching branches. An existing `flutter run` terminal should exit with lowercase **q**; do not Flutter hot restart with uppercase R.

```powershell
git fetch origin
git switch --track origin/experiment/cp86-r9-windowed-waveform-preview
```

If a local experimental branch already exists, `git switch experiment/cp86-r9-windowed-waveform-preview` then `git pull --ff-only`.

In another PowerShell window, capture Logcat (clears *log buffers only*):

```powershell
.\tool\capture_android_back_log.ps1 -Device CPH2381 -Fresh -Output cp86_r9_window_1800_fast.log
```

Run clean-debug with one seek offset (the first startup is **30:00**):

```powershell
.\tool\run_android_clean_debug.ps1 -Device CPH2381 -DartDefines @(
  'MS_ONE_CP86_R9_WINDOW_PROBE=true',
  'MS_ONE_CP86_R9_START_SECONDS=1800',
  'MS_ONE_CP86_R9_DURATION_SECONDS=30'
)
```

Open waveform with the same long MKV and the same audio track as R6. Await the usual full waveform, because its data is needed for comparison. New experiment logs:

```
CP86 R9 WINDOW seekMode=inputFast startSeconds=1800 durationSeconds=30 ffmpegMs=... pcmBytes=... samples=... stream=...
CP86 R9 ALIGNMENT samples=... lagSamples=... relativeError=... inconclusiveSilence=...
```

Repeat separately at 0 and 5,400 seconds, and compare accurate output seek by adding `'MS_ONE_CP86_R9_ACCURATE_SEEK=true'` to `-DartDefines` (and using a distinct log name). The full-cache hit remains valid: R9 probes every load in debug mode when the flag is on, even when the full waveform is cached.

Confirm audio-track switching, Android SAF source, aborting during native FFmpeg, Editor Back and Home taps, no unremoved `cp86_r9_window_*.raw` temporary files. Do not uninstall, clear Isar database or delete the user's regular cache.

## Decision criteria and next phase

- **Good result:** seeked 30s window decodes substantially faster than R6 134,990ms, `samples` roughly 82,680, peak alignment reproducible against known clean test clips on 0/30/90-minute positions, cancellation and SAF stable. Keep this separate until tests include timestamp gaps and non-zero stream start time.
- **Bad result:** input SAF cannot seek efficiently, or absolute sample alignment has systematic drift across tracks. Do not declare the preview ready; test outputAccurate mode or native libavcodec/stream callback alternative.
- **Phase 2, not implemented in R9:** render only the validated window as a *partial* waveform, mark unknown ranges as loading rather than silence; track absolute start time in tiles, viewport priority and cache/source-revision identity. No release-mode visual change in R9.

**Important:** no APK/platform compilation is performed in Actions. Flutter device/debug builds are local to user PC.
