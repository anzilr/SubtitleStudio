# CP86 R10 — Early window preview during full extraction (2026-10-20)

**Branch:** `experiment/cp86-r9-windowed-waveform-preview`; experimental feature ONLY, disabled in normal launches.

## R9 physical log finding

`cp86_r9_window_1800_fast.log` from Android CPH2381 confirms three 30-second fast-seek FFmpeg extractions at absolute 1800 seconds: **931ms, 586ms, 714ms**. Each contained **82,680 samples / 165,360 PCM bytes**. Every sampled comparison to the full-track V2 cache reported `samples=256 lagSamples=0 relativeError=0.0000 inconclusiveSilence=false` (256 sampled points, not entire-waveform certification).

The same run extracted the full movie from uncached PCM: **135,947 ms native FFmpeg**, **3,905 ms peak building**, **140,592 ms total source processing**. Cold decoding remains expensive; a seeked short window is demonstrably cheap on this specific MKV with automatic track selection and Android DocumentsProvider.

## R10 implementation

After R9's successful temporary seek extraction, only when both `MS_ONE_CP86_R9_WINDOW_PROBE=true` and `MS_ONE_CP86_R10_SHOW_WINDOW_PREVIEW=true` are defined in a **debug** build:

- Convert bounded window samples to **256 min/max signed display buckets**, with absolute `start`/`end` timestamps.
- Notify the current Riverpod controller during the otherwise blocking full extraction. Loading-state updates preserve this preview and stale completion/cancellation callbacks cannot resurrect it for another media source.
- Display a small non-interactive preview strip labeled with its **absolute time interval**. Explicitly label other timeline ranges unknown, rather than drawing silence. No subtitle editing, seeking, scrolling or cached partial-tile publication is enabled until alignment tests are broader.
- Existing `WaveformReady` and normal full PCM/peak cache remain unaffected. Disabling either flag reverts to the previous behavior. All experimental PCM output is still temporary.

## Device acceptance

```powershell
git fetch origin
git switch experiment/cp86-r9-windowed-waveform-preview
git pull --ff-only
.\tool\run_android_clean_debug.ps1 -Device d6e22c3f -DartDefines @(
  'MS_ONE_CP86_R9_WINDOW_PROBE=true',
  'MS_ONE_CP86_R9_START_SECONDS=1800',
  'MS_ONE_CP86_R9_DURATION_SECONDS=30',
  'MS_ONE_CP86_R10_SHOW_WINDOW_PREVIEW=true'
)
```

Open the same long MKV using the same audio track. On a cold full waveform load, confirm a labelled 30:00–30:30 waveform **appears before** the entire 135-second native extraction finishes, remains displayed while progress callbacks arrive, and disappears as the validated full waveform becomes ready. Warm cache loads may replace the preview too quickly to observe.

Test rapidly navigating away or switching the audio track while the full decode runs; the preview must not appear on another session. Confirm R13 Android Back navigation still works. Retain `cp86_r10_window_preview.log` to record timing. Android native acceptance is outstanding until device tested. Do not use Flutter hot restart.

**Next R11 requirement:** independent timestamp-gap/codec/explicit-audio-track fixtures and real absolute-window tile mapping before allowing preview interactions or enabling it by default.

## R10 device capture: preview extraction verified, UI paint not yet observable

The uploaded `cp86_r10_window_preview.log` (20:51–20:54 October 20, CPH2381 Android 14, experimental branch) shows:

| Stage | Device log | Result |
|---|---|---|
| Source processing started | 20:52:00.009 | 30-minute window probe begins before normal full extraction |
| Window probe complete | 20:52:01.437 | **1,204 ms**, 82,680 signed PCM samples, 165,360 bytes, 30 seconds at 2,756 Hz, `stream=auto` |
| Full extraction starts | 20:52:01.502 | Normal FFmpegKit `aresample=async=1:first_pts=0` flow |
| Full extraction ends | 20:54:20.105 | Native FFmpeg **138,602 ms**, peak reduction **1,794 ms**, full source acquisition 141,920 ms, total processing **141,957 ms** |
| Preview vs whole-track cache | 20:54:21.930 | `samples=256 lagSamples=0 relativeError=0.0000 inconclusiveSilence=false` |

No app `SIGSEGV`, fatal signal, or ANR appeared in this capture. However, no `CP86 R10` label was emitted by the previously released code, so the log **does not confirm the preview ever reached the UI painter**. Do not mark native R10 preview display acceptance PASS based on this log alone.

### Follow-up observability patch

R10 now emits distinct, privacy-safe diagnostic markers:
- `CP86 R10 PREVIEW_CREATED startMs=1800000 endMs=1830000 buckets=256 callback=true`: bounded window PCM was reduced to UI data and handed to the controller; not evidence of drawing.
- `CP86 R10 PREVIEW_PAINTED startMs=1800000 endMs=1830000 buckets=256`: the waveform's CustomPainter completed drawing on a nonempty Canvas; logged only once per transient preview object.

The markers distinguish actual rendering from successful extraction. Added widget test for nonempty painting and a zero-size test to prevent falsely claiming a drawn waveform. Device acceptance still needs a fresh log with both markers and normal subsequent `AudioProcessor: Processing complete`; visual confirmation from the device remains recommended.


## Flutter-only R10 paint diagnostics quality gate

[GitHub Actions 39470973477](https://github.com/anzilr/SubtitleStudio/actions/runs/39470973477) completed successfully on 2026-10-20, with **558 Flutter tests passed and "No issues found!" from `flutter analyze`**. This includes the direct nonempty-canvas paint test and the zero-size rejection test. No Android, Windows, or other platform builds were run in CI.

The preceding gate (39470704464) initially failed analysis because the widget's newly typed `WaveformWindowPreview` reference lacked an import; fixed in commit `489d779`, and the succeeding gate verified the corrected source. Device-side `PREVIEW_PAINTED` and UI visible-frame acceptance remain to be captured.

## CP86 R10 native paint acceptance — PASS (2026-10-20)

**Evidence:** uploaded `cp86_r10_paint_verification.log` (UTF-16 LE; Flutter PID 28210, OnePlus CPH2381, Android 14). This newer capture supersedes the earlier R10 entry above that correctly reported UI paint as unverified.

| Wall clock (device local) | Event | Measurement |
|---|---|---|
| 21:12:58.299 | `AudioProcessor: Starting audio processing` | selected Android SAF MKV source |
| 21:12:59.459 | `CP86 R9 WINDOW` | **954ms** native FFmpeg for 30s at 1800s, **82,680 samples / 165,360 PCM bytes**, `stream=auto` |
| 21:12:59.465 | `CP86 R10 PREVIEW_CREATED` | absolute **1,800,000–1,830,000ms**, 256 buckets, controller callback attached |
| 21:12:59.497 | `CP86 R10 PREVIEW_PAINTED` | **32ms after creation**, painter drew a nonempty Flutter canvas |
| 21:12:59.521 | normal full FFmpeg extraction command | normal V2 full source path unchanged |
| 21:15:13.124 | full FFmpeg exit | success |
| 21:15:19.086 | `CP86 R9 ALIGNMENT` | **256 sampled points; 0 lag; 0.0000 relative error; nonsilent** |
| 21:15:19.125 | `AudioProcessor: Processing complete` | **140,822ms** total; **133,602ms native FFmpeg**, **5,904ms peak generation**, 20,635,510 samples |

**Result:** both preview handoff and the actual nonempty-canvas paint are now **device verified**, about **139.6s before full waveform completion**. No `SIGSEGV`, `Fatal signal`, `FATAL EXCEPTION`, app ANR, or Flutter framework exception was present in the capture. This log is evidence of painter execution, **not** a device screenshot or comprehensive human-perceptual display assertion.

**R10 acceptance:** PASS for *this selected Android SAF MKV, auto audio track, inputFast 30s window at 30:00*, plus clean [Flutter CI 39470973477](https://github.com/anzilr/SubtitleStudio/actions/runs/39470973477) (**558 tests, zero analyzer issues**). Do not extrapolate to all formats, PTS gaps, explicit stream selections, Windows, cancellation or interactive editing. The production `refactor/riverpod-architecture` branch remains unchanged.

**Next qualification:** CP86 R11 interval mapping, sparse unknown/known viewport coverage, source/track isolation, validation of timestamp gaps and explicit multi-audio track fixtures before interactive seek/edit is allowed.

