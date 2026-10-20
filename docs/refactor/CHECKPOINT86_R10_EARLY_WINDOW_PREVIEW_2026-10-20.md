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
