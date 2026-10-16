# SubtitleStudio — Waveform R7 Riverpod build-phase lifecycle

**Date:** 2026-10-16  
**Branch:** `refactor/riverpod-architecture`  
**CI-verified code:** `b10b06f29676ba975bcaf1ba5e84c0c4059413a4`  
**GitHub Actions:** [run 38921649751](https://github.com/anzilr/SubtitleStudio/actions/runs/38921649751), **452 tests passed and zero analyzer issues**.  
**Native Android:** acceptance pending, no physical device verification in CI.

## New evidence

The OnePlus CPH2381 Android 14 user debug run on the original large-media project successfully reached the **compact peak/metadata** waveform path. The log reports 20,637,381 display samples, 25 *metadata-only* zoom descriptors, 0 materialized zoom pixels and a completed waveform buffer. This is evidence that the R6 processing-path change was exercised, not evidence of an unrelated FFmpeg/native crash.

The user encountered a FlutterError at `WaveformController._setState(): state = nextState`: **Tried to modify a provider while the widget tree was building.** The attached truncated/console log does not include a full Riverpod stack, so the precise original call path cannot be proven from that file alone. Source review found two definitely illegal lifecycle call sites in `WaveformWidget.didUpdateWidget`: immediate `UpdatePlaybackPosition` dispatch and `_updateSubtitlesInternal` which invoked `setState` and dispatched `ForceRepaint`. Parent video callbacks during a rebuild can exercise both.

## Fix

1. Playback property changes are scheduled via a **single coalesced post-frame callback** that reads the latest `widget.playbackPosition`, checks `mounted` and then dispatches. No Riverpod mutation during `didUpdateWidget`.
2. Subtitle changes in `didUpdateWidget` refresh the widget's cached list without redundant `setState` or `ForceRepaint` dispatch. Explicit external subtitle updates still request a local repaint.
3. `WaveformController._setState` additionally protects against unexpected audio callback emissions during `SchedulerPhase.persistentCallbacks`, deferring those writes until after the frame. Later updates and disposal invalidate queued emissions. Pure `ProviderContainer` uses with **no SchedulerBinding initialized** continue to work synchronously.
4. The playback playhead and auto-scroll position are now computed as **one atomic `WaveformReady` transition**. Previously, two state writes could race when the first was deferred and the second was calculated from stale state.
5. A one-zoom-level waveform no longer divides by zero when rendering the Zoom (%) badge.

## Regression

`test/waveform_provider_build_phase_test.dart` verifies: (a) an intentionally requested provider update while a widget builds does not produce Riverpod's lifecycle error and retains the new playback time; (b) parent updates changing both subtitle content and playhead in the same rebuild do not throw or overwrite the new playhead. Original `waveform_load_epoch_test.dart` also remains green, ensuring old/cleared loads cannot resurrect data or rely on a widget binding.

- First run [38920947727](https://github.com/anzilr/SubtitleStudio/actions/runs/38920947727): analyzer clean, 448 tests passed, 4 test failures. Found additional issues: missing scheduler binding in pure provider tests, deferred playback overwritten by a stale scroll update, and divide-by-zero in single-zoom view.
- Final run [38921649751](https://github.com/anzilr/SubtitleStudio/actions/runs/38921649751): **452 tests passed, zero analyzer issues**.

## On-device acceptance

1. Back up the important subtitle project and run the latest `refactor/riverpod-architecture` branch with `flutter run --debug -d CPH2381`.
2. Open the original large-video session; enable waveform. Confirm the video remains visible, waveform processing completes and the UI becomes interactive.
3. While waveform is visible, play/pause and seek repeatedly, jump among subtitle cues, edit/mark a subtitle line and return to Editor. The waveform should synchronize playback without Riverpod lifecycle errors.
4. Hide/show waveform, drag the video/waveform splitter, switch Carbon Zero Light/Dark/Classic and rotate the device.
5. If any exception remains, capture the full **debugger stack trace** (not just the line `state = nextState`), plus Flutter console and `adb logcat -b crash -d -v time`. Distinguish framework exceptions from native process deaths.
6. Confirm editing data and historical checkpoints after closing/reopening the project.

**This is Flutter CI verification only, not Android native sign-off.** No changes to the Isar database schema, subtitle parsing, media decoder or upstream release branch.
