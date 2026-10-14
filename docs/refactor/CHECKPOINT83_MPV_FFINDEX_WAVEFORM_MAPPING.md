# Checkpoint 83 — Verified MPV track index mapping foundation

Date: 2026-10-14
Branch: refactor/riverpod-architecture
Baseline: Checkpoint 82 R2, 351 Flutter tests and zero analyzer issues.

## Why the legacy heuristic is unsafe

SubtitleStudio saves the Media Kit AudioTrack.id in video preferences.
Media Kit uses libmpv's audio track ID. MPV's track-list/N/id is the ID
used by aid selection. It is not guaranteed to correspond to FFmpeg's
global stream index or zero-based audio-only ordinal. libmpv provides
track-list/N/ff-index for the stream index commonly used by FFmpeg.
Even ff-index has a documented caveat for non-libavformat demuxers.
Sources:
- https://mpv.io/manual/master/#property-list
- https://pub.dev/documentation/media_kit/latest/media_kit/NativePlayer-class.html
- https://github.com/media-kit/media-kit

## Implemented

1. Added WaveformMpvAudioStreamResolver with an injectable property
   reader (no libmpv dependency in its testable core). For a selected
   numeric mpv ID it reads track-list/count, scans only audio entries,
   matches exact mpv ID, and reads ff-index. It returns a new, explicit
   selector of the form ffmpeg:stream:N for the GLOBAL stream index.
   It rejects missing selected audio, duplicates, missing ff-index,
   malformed indexes, invalid track counts and property-reader errors
   rather than applying a guess.
2. Added WaveformFfmpegPlan.streamMap. It supports three distinct
   semantics:
   - ffmpeg:stream:N => -map 0:N (global FFmpeg stream);
   - ffmpeg:a:N => -map 0:a:N (zero-based audio ordinal);
   - historical numeric Media Kit ID => legacy heuristic as a
     compatibility boundary until full UI integration is qualified.
   The normal extraction plan passes the exact generated map argument
   to both desktop Process.start and FFmpegKit.
3. VideoPlayerWidgetState exposes resolveWaveformSelectedAudioStream(),
   which queries the active native Media Kit player's mpv properties.
   It returns null for automatic selection, fails for disabled audio,
   and raises errors if native track metadata is unavailable.
4. When a manually selected track is saved in a DEBUG build, the player
   logs its mpv ID alongside the resolved FFmpeg stream selector, or
   explains why resolution failed. No paths or media contents are
   included in the new mapping log.
5. Unit tests model interleaved video/audio/subtitles, non-consecutive
   mpv IDs, duplicate/missing matches, invalid global indexes, no
   ff-index availability, and exact FFmpeg plan output.
6. New optional FFmpeg integration test generates a temporary MKV with
   one video and two sine-tone audio streams, offsets the second audio
   by 750 ms, probes the three global stream indexes, extracts streams
   1 and 2 with the app's actual argument planner, checks initial
   silence/PCM lengths and confirms that stream 9 fails. It uses only
   generated media, not real user files. If FFmpeg isn't installed the
   fixture test exits while all pure Dart tests remain active.
7. Windows probe from Checkpoint 82 remains at:
   scripts/waveform/checkpoint82_ffmpeg_probe.ps1.

## Qualification and candid boundaries

- This is a REAL resolver exposed to the video player, but automatic
  editor waveform reload on audio track changes is NOT wired to it yet.
  Existing LoadAudioFile call sites continue accepting the legacy
  numeric audioTrackId unless a caller explicitly passes a resolved
  selector. We must not advertise that all production waveform loads
  are now mapped with mpv ff-index.
- mpv itself warns that ff-index can be inaccurate for non-libavformat
  demuxers. Confirm compatibility against the same source container
  with a native video/audio inspection when possible.
- FFmpeg integration tests exercise command-line FFmpeg on a test
  environment, not Android FFmpegKit, Android content URIs or Windows
  Media Kit playback. Physical-device ID and synchronization checks
  remain outstanding.
- The previously implemented cancellation guard and cache locks have
  not been recertified on native FFmpegKit/process trees. Avoid
  treating unit-test success as native cancellation proof.
- Existing default eager rendering, Isar schema, mobile UX, upstream
  main and release tags remain unchanged. The desktop workspace
  continues to be deferred.

## Recommended next checkpoint

Wire the verified selector into the actual editor waveform load and
track-change lifecycle behind a guarded experimental switch, including
testing source/track identity and preventing stale waveforms from
remaining visible when track resolution fails. Test Android/Windows
with the controlled MKV before enabling this mapping by default.

To inspect selected IDs on Windows, run a DEBUG build, open a
multitrack video and change the audio track; look for:
    Waveform selected track: mpv=... ffmpeg=ffmpeg:stream:N
If metadata is unavailable the log explicitly says so.
