# SubtitleStudio — CP92 R5: Waveform FFmpeg diagnostic privacy

Date: October 23, 2026  
Branch: `refactor/riverpod-architecture`

## Scope and findings

`AudioProcessor` uses system FFmpeg on Windows/Linux and FFmpegKit on
Android/iOS/macOS. Although the shared FFmpeg helper was redacted in R4,
waveform processing separately printed private input/cache/output paths,
the complete native FFmpegKit command and raw exception text. System FFmpeg
stderr and FFmpegKit native logs were included verbatim in thrown errors.
The waveform controller and several UI error handlers also displayed raw
exceptions. A failed media grant or FFmpeg operation could therefore expose
file paths, content-document identifiers and media metadata in the UI/logs.

## Changes

- Keep the existing system FFmpeg and FFmpegKit arguments, SAF conversion,
  stream selection, PCM/peak cache generation, cleanup, progress reporting
  and epoch-scoped cancellation unchanged.
- Replace waveform phase logs containing source, cache or temp file paths
  with constant status messages; retain useful sample counts, progress,
  audio stream mapping, platform and measured processing timings.
- Drain desktop FFmpeg stdout **and** stderr concurrently without buffering
  raw stderr text into Dart. Include only numeric exit code and fixed
  recovery advice in failures. Do not retrieve native FFmpegKit session logs
  or print native commands; retain its numeric return code when available.
- Introduce `WaveformProcessingFailure` for deliberately path-free user
  messages. Mask unexpected plugin, cache, filesystem and decoding exceptions
  at the audio-processor boundary; retain the existing fixed SAF re-selection
  advice and system FFmpeg installation guidance.
- The Riverpod waveform controller displays only the typed, safe failure
  message, never `error.toString()` from arbitrary dependencies. Picker,
  subtitle-time update and zoom-preference failures also avoid raw errors.
- Add `test/waveform_audio_diagnostic_privacy_test.dart` for redaction of a
  deliberately sensitive filesystem exception, retention of safe FFmpeg
  recovery advice and source-level guards against command/native log leaks.

## Verification

- Local `git diff --check` clean.
- Flutter SDK is unavailable in this execution workspace. GitHub Linux
  [Flutter quality gate 39944813390](https://github.com/anzilr/SubtitleStudio/actions/runs/39944813390)
  **passed: 782 tests and zero analyzer issues**, including all three
  `waveform_audio_diagnostic_privacy_test.dart` regressions.
- Verified implementation commit:
  `27ef8b2b9eb89378b992f6c409edab5dcddeb238`.
- No native application builds in GitHub Actions. Android document grants,
  explicit/Auto track switching and Windows FFmpeg failures still need local
  device validation; these are not accepted by Flutter-only CI.

## Next checkpoints

CP92 R6: measure import/open/save/restore performance and capture comparable
non-sensitive baselines without restarting the deferred CP86 waveform
optimization experiment. CP92 R7: remove only usage-proven obsolete shims.
CP93: architecture compatibility, device smoke tests and core acceptance.
