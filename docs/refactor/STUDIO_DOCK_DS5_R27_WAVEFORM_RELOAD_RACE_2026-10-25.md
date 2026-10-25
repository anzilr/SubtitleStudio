# SubtitleStudio — DS5 R27 waveform reload race guard

Date: 2026-10-25
Branch: `feature/studio-dock-integration`

## Issue

Studio Dock's Regenerate Waveform action correctly checked the selected mpv
audio track after deleting the existing cache, but did not recheck it after
the asynchronous `ClearWaveform` dispatch. A user changing the audio track,
replacing the video or switching sessions in that interval could start an
obsolete FFmpeg waveform load. A reused session with identical track labels
also needed the widget's audio-change revision checked, not just a track name.

## Change

- Capture the playback link, project, video path, mpv track and resolved FFmpeg
  selector at regeneration start.
- Recheck the exact capture and change revision **before cache removal, after
  cache removal and after waveform clear**, immediately before dispatching a
  new `LoadAudioFile`.
- Keep existing sequential cache removal / `ClearWaveform` / `LoadAudioFile`
  and preserve the selected audio stream, single media player, visibility and
  busy/error UI. No new native decoder or persistent state is introduced.
- Continue allowing the newer automatic selection listener to load the new
  audio track; stale regeneration does not overwrite it.

## Regression gates

- Exact session/project/video/track/stream-selection match checks.
- Full successful reload order and already-invalid request no-op.
- Deterministic asynchronous track switches while cache removal and waveform
  clear are pending: obsolete load must not start.
- Flutter analyzer, Studio Dock focused tests, then full Flutter suite. GitHub
  Actions must not build Android, Windows, macOS, iOS or Linux binaries.

## Still pending

Physical Windows acceptance for rapid track switching, video replacement,
waveform seek/drag/snapping, audio-to-video synchronization, real cache
invalidation, and large-media responsiveness. This code-level race fix does
not certify native decoding performance or visual landing accuracy.
