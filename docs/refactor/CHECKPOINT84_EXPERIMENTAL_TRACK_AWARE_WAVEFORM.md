# Checkpoint 84 — Experimental editor waveform audio-track synchronization

Date: 2026-10-15
Branch: refactor/riverpod-architecture
Baseline: Checkpoint 83 (360 tests passed, 0 analyzer issues).
Mode: MS_ONE_WAVEFORM_TRACK_SYNC=true; default off.

## Implemented

- VideoPlayerWidget now exposes onAudioTrackChanged and reports real
  Media Kit/libmpv audio track IDs from the existing track subscription.
  Callback forwarding is connected to all editor video compositions,
  including the responsive mobile and desktop variants.
- The selected track is resolved through Checkpoint 83's
  VideoPlayerWidgetState.resolveWaveformSelectedAudioStream, obtaining
  ffmpeg:stream:N via libmpv track-list/N/ff-index rather than treating
  the mpv ID as an FFmpeg audio ordinal.
- WaveformTrackReloadCoordinator invalidates the existing waveform
  immediately, before awaiting stream metadata. Overlapping player
  selections supersede the previous request. Old failures do not
  publish stale errors; a hidden editor or replaced media stops
  publishing. Dispose also invalidates pending requests.
- When a selected stream cannot be resolved, the controller clears
  obsolete decoding and shows WaveformTrackSelectionFailed, avoiding
  presentation of the previous track's waveform as if it were current.
- Null/auto player track resolution is passed to LoadAudioFile as an
  EXPLICIT 'auto' value to prevent the controller loading an older
  stored preference for the now-automatic player track.
- Effective audioTrackId is recorded on WaveformReady and preserved in
  copyWith for future track-sensitive cache/readiness checks.
- Opening the waveform, regenerating it, hiding it, replacing its
  media source, and unloading video all use the guarded flow when
  the experimental compile-time switch is enabled. The previous
  load/restore behavior is preserved for normal builds.

## Regression tests

- Immediate invalidation before resolving slow player metadata.
- Two rapid track changes: only newest selection loads.
- Explicit auto mode bypasses saved ID fallback.
- Missing/failed mpv ff-index creates failure instead of old waveform.
- Outdated metadata failures cannot replace a newer load.
- Hidden source, stale source, and disposal ignore late results.
- WaveformReady selected stream remains across time/zoom state copies.

CI on each meaningful checkpoint only: flutter analyze plus flutter
test -j 1, no native five-platform compilation. The 360 previous
tests remain as regression coverage.

## Device verification (still required)

Native Media Kit and FFmpegKit integration have NOT been tested on
physical Android/Windows targets for this checkpoint. Compile with:

    flutter run -d windows --dart-define=MS_ONE_TILED_WAVEFORM=true --dart-define=MS_ONE_LAYERED_WAVEFORM=true --dart-define=MS_ONE_WAVEFORM_TRACK_SYNC=true

To compare baseline behavior, omit all three flags.

Use the Checkpoint 82 synthetic two-track MKV, select a different
language/audio track and observe the waveform swap, spinner or
visible error. Rapidly switch tracks while extraction is running.
Confirm the output matches audible audio and record debug lines:
    Waveform selected track: mpv=... ffmpeg=ffmpeg:stream:N

Android:
    flutter run -d <device> --dart-define=MS_ONE_TILED_WAVEFORM=true --dart-define=MS_ONE_WAVEFORM_TRACK_SYNC=true

Verify SAF content URI access, multitrack selection, pause/resume,
native FFmpegKit cancellation and memory/frame-time traces.
Do not assume mpv ff-index is meaningful for non-libavformat
demuxers. These physical-device qualifications remain unverified.

## Boundaries and next improvements

No changes to the default eager renderer, normal editor track
selection, database schema, upstream/main/release branches, nor
deferred desktop workspace. The experimental flow may report a
visible error where the player has no verified stream metadata.
Track-change signal and async controller race unit tests do not prove
a native plugin delivers ff-index on every target.

Checkpoint 85 candidate: run Android/Windows fixtures, correct MPV
property availability across platforms, resolve failed/stale source
selection lifecycle from logs, and benchmark tile/layer frame times.


## Verified CI result (R1)

- Verified code: https://github.com/anzilr/SubtitleStudio/commit/135caea87db1b64eebdca1bb798461701b0f265b
- Successful CI: https://github.com/anzilr/SubtitleStudio/actions/runs/38760499546
- flutter analyze: No issues found, including informational notices.
- flutter test -j 1: **369 passing tests**, nine more than
  Checkpoint 83 (360 tests). No failing or skipped regressions claimed.
- New coordinator tests cover stale resolutions/failures, rapid
  switches, explicit Auto, hiding, disposal, and source identity;
  a ready-state regression covers preservation of track IDs.
- The CI gate uses a Linux runner; it is not evidence that libmpv
  ff-index, FFmpegKit, Windows or Android SAF work in all configurations.
- The subsequent roadmap/report commit is documentation-only and does
  not request additional GitHub Actions runs.
