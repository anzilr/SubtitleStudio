# Checkpoint 82 — Audio track mapping and repeatable PTS verification

Date: 2026-10-14
Branch: refactor/riverpod-architecture
Prior verified checkpoint: 81 R2 (344 Flutter tests, zero analyzer issues).

## Source-grounded findings

- SubtitleStudio persists Media Kit AudioTrack.id (video_track_actions.dart).
  That ID is a player/backend track identifier; it must NOT be assumed
  to equal an FFmpeg stream ordinal without probing the actual media.
- audio_processor.dart duplicated desktop Process.start argument building
  and FFmpegKit command assembly. Both used the unverified legacy mapping
  of ID >= 1 to ID - 1 and inserted aresample=async=1:first_pts=0.
- Previously explicit invalid IDs failed instead of silently defaulting.
  This checkpoint makes that contract independently testable.
- Subtitle Composer and Subtitle Edit informed the audio-data separation
  and source/track selection research, without copied code.

## Implemented

1. New WaveformFfmpegPlan builds the same FFmpeg arguments for desktop
   Process.start and FFmpegKit. The plan includes:
   -nostdin, -hide_banner, -nostats, -loglevel error, -y;
   source input, optional -map 0:a:N, timestamp-gap-aware audio
   resampling, mono 44100-Hz little-endian PCM output.
2. audioOrdinal accepts explicit 0-based ffmpeg:a:N values for
   verified stream selection, or returns no map only for null/auto.
   Invalid, disabled, negative or malformed selections throw
   FormatException and do not fall back.
3. Historical numeric Media Kit track ID handling is preserved at
   the compatibility boundary until on-device tests establish the
   correct mapping. **It is NOT yet validated.** ID=0 maps to audio 0;
   ID=1 maps to audio 0; ID=2 maps to audio 1, and so on.
   The explicit ffmpeg:a:N prefix is for controlled testing and
   future resolvers, not currently a user-facing track-selection option.
4. FFmpegKit command paths are quoted as individual arguments and
   escaped rather than assembled through direct string interpolation.
5. Seven new tests validate identical argument order, presence of
   PTS correction, track selection semantics, strict invalid-ID
   rejection, native command path escaping and malformed input paths.
6. Windows PowerShell helper:
   scripts/waveform/checkpoint82_ffmpeg_probe.ps1
   creates a two-track MKV using 440-Hz and 880-Hz synthetic tones,
   offsets the second audio track by 1.25 s, records ffprobe stream
   metadata, extracts each track plus auto mode, and verifies a
   nonexistent 0:a:9 stream fails instead of selecting a substitute.
   It also reports PCM sample counts, a leading-silence indicator and
   hashes in waveform_probe.json. The helper is a manual script and
   has NOT been run on a user's PC in this checkpoint.

## Manual Windows qualification

From the repository root in PowerShell with ffmpeg/ffprobe on PATH:

    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/waveform/checkpoint82_ffmpeg_probe.ps1

Review build/waveform_checkpoint82/waveform_probe.json and stderr,
and open the generated multitrack_pts_gap.mkv in SubtitleStudio.
Compare player track selection versus waveform extraction with:

    flutter run -d windows --dart-define=MS_ONE_TILED_WAVEFORM=true --dart-define=MS_ONE_LAYERED_WAVEFORM=true

Record whether selected track 0 and track 1 display different audio
and whether a 1.25-s shifted PTS produces the expected leading gap.
Capture audio_processor logs and measurements, app crashes/errors,
playhead seeks, rapid video switching and overlay selection.

## Manual Android qualification

    flutter run -d <android-device-id> --dart-define=MS_ONE_TILED_WAVEFORM=true --dart-define=MS_ONE_LAYERED_WAVEFORM=true

Import the same generated MKV through Android file chooser, including
SAF content:// access where supported. Compare selected track labels
to audible player output and waveform. Test switching during extraction,
backgrounding, permissions, reopening, and cache invalidation.
Capture logcat with package PID, redacting private paths/user content.

## Caveats and remaining work

- There are NO physical-device results yet. The helper does not validate
  Media Kit ID mapping; it supplies a known two-stream test case so
  users can compare it with real Media Kit-selected IDs on devices.
- The FFmpeg PTS filter is asserted at argument level; real-world sync
  must be measured with offset screen recordings and on Android/Windows.
- Native FFmpegKit cancellation, FFmpeg process-tree termination, macOS
  availability, and peak-RSS/frame-time profiling remain unverified.
- Existing eager pipeline stays default. No Isar schema, desktop
  workspace, upstream/main/release tag changes or native five-platform
  CI builds.


## Verified quality gate: R2

- Verified code: https://github.com/anzilr/SubtitleStudio/commit/7ee451c2f2555aec1bf1dc39872b12c60e79508b
- Successful analyzer/test run: https://github.com/anzilr/SubtitleStudio/actions/runs/38622317190
- Flutter analyze: No issues found (zero errors, warnings or infos).
- Flutter test -j 1: 351 tests passed, 7 more than Checkpoint 81 R2 (344).
- Initial R1 failed analysis due a malformed generated plan file.
  R2 replaced that file cleanly, and the entire suite completed.
- No native-device audio tracks, FFmpegKit cancellation or Android SAF
  alignment were verified; these remain manual qualifications.
- Report/roadmap changes are documentation-only and do not trigger
  another GitHub Actions gate.
