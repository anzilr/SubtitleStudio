# SubtitleStudio — Waveform R6 Android crash containment

**Date:** 2026-10-16  
**Branch:** `refactor/riverpod-architecture`  
**CI-verified code commit:** `722615631760d726299053fc57b747f7fae9f311`  
**CI result:** [Run 38918789679](https://github.com/anzilr/SubtitleStudio/actions/runs/38918789679), **450 Flutter tests passed, 0 analyzer issues**.  
**Native Android acceptance:** PENDING; no phone build or reproduction test executed in CI.

## Observed symptoms and certainty

The user-supplied Android 14 log from OnePlus CPH2381 (360dp width) records
two `FlutterError.onError` events: `A RenderFlex overflowed by 3.8 pixels on the bottom` at
`lib/screens/edit/parts/edit_responsive_layout.dart:363`. The split pane offered
177.2dp; the waveform child always demanded 180dp plus a one-pixel divider.
The top video/player area was consequently constrained to 0dp.

The same log records eager reading of 330,198,104 44.1-kHz mono PCM samples
from a legacy cache, ~660.4 MB in raw PCM before the downsampled arrays and
25 eager full-track zoom levels were generated. Processing reported success,
then later the debug tool printed `Lost connection to device` and exited.
The log does **not** show a conclusive AndroidRuntime exception, SIGSEGV
or Java/Dart out-of-memory trace. Resource pressure is a plausible second
failure mode but **not an established root cause** of the disconnect.

## Changes

- `ResizableSplitView` now accepts `minFirstPaneExtent` for live height
  constraints, applied both in layout and gesture drags. The stored splitter
  preference is preserved when simply revealing the waveform.
- `AdaptiveWaveformPane` gives video a minimum 120dp and the waveform up
  to 180dp (1dp divider). It does not build the waveform into a viewport
  too short to safely show it; the video remains visible instead.
- The Editor's mobile video/waveform region uses this pane and asks for a
  minimum 301dp leading split while the waveform is visible.
- Android `AudioProcessor` defaults to the existing bounded compact-peak/tiled
  renderer. Windows/Linux/macOS retain eager mode unless explicitly enabled.
  The constructor still accepts `useTiledZoom` to select either path.
- For existing legacy PCM caches matching the current subtitle/media/audio
  track metadata, the compact pipeline streams the PCM through
  `WaveformPeakCache.build`, rather than allocating the entire legacy
  recording with `readAsBytes()` or decoding the movie a second time.
  Content-URI derived peak-cache files are still removed according to the
  previous nonpersistent SAF policy. On failure/cancellation, the peak builder
  does not promote an incomplete cache.

## Automated tests

`test/mobile_waveform_pane_constraints_test.dart` reproduces the exact saved
mobile video ratio 0.25486577181208037 on a 360dp-wide viewport, checks
minimum playable video and bounded waveform, and checks that a 177.2dp pane
does not overflow or create a zero-height player.

All existing waveform parity, metadata, cache and lifecycle tests remain in
the 450-test green Flutter CI gate. The Android compact path and FFmpeg SAF
integration still require on-device qualification.

## Manual Android acceptance

1. Back up valuable subtitle projects. On the OnePlus CPH2381, pull
   `refactor/riverpod-architecture`; use a debug build initially.
2. Open the existing session with the Ballerina MKV and its historic large
   PCM cache. Toggle waveform ON and watch the video still display. An
   increase in top split ratio is expected if the persisted split was tiny.
3. Confirm the waveform loads and remains scrollable/zoomable and the subtitle
   list remains usable. In the debugger logs, check for `Generating zoom
   metadata` rather than 25 eager full-track buffers and confirm **no**
   `Loaded 330198104 samples from cache` message.
4. Drag the mobile video split down toward minimum, rotate device, show/hide
   video, and toggle waveform repeatedly. Check for zero-height video,
   RenderFlex overflow, unexpected player recreation and subtitle sync errors.
5. Exit and reopen the same project; check existing edited subtitle data and
   history, waveform zoom, playback and cursor state.
6. If the app still disconnects, capture crash and ANR-specific diagnostics
   immediately, before opening the app again:
   `adb logcat -b crash -d -v time > android_crash.txt` and
   `adb logcat -b main -b system -d -v time > android_system.txt`.
   Keep the Flutter debug console too. A log with a native kill/ANR/OOM
   reason is required before attributing device connection loss.

## Not changed

No Isar schema migration, subtitle text parser/compilation, video decoder,
native platform dependency, upstream or release-branch changes.

**Release status: not approved** until Android native waveform stability is
verified on a device with the historic large PCM cache.
