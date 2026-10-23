# SubtitleStudio — CP92 R4: FFmpeg/FFprobe helper diagnostic privacy

Date: October 23, 2026  
Branch: `refactor/riverpod-architecture`

## Scope

Audit `lib/utils/ffmpeg_helper.dart`, which selects FFmpegKit on Android,
iOS and macOS and system FFmpeg/FFprobe on Windows and Linux. The helper
previously printed private input/output paths and SAF parameters, entire
commands, FFmpegKit logs, system process stdout/stderr, track metadata,
directory contents and raw exceptions. Some of that text was also included
in thrown exceptions or application logging.

## Changes

- Replace sensitive prints and application logs with phase/status diagnostics.
  Preserve useful OS, stream index, track count, byte count, frame rate and
  numeric return/exit code information.
- Do not collect FFmpegKit/FFprobeKit native session messages for Dart-level
  logging or error text. Do not print system FFmpeg stdout/stderr. System
  FFprobe JSON stdout is still parsed for stream metadata but not logged.
- Normalize unexpected helper exceptions to path-free, actionable failure
  messages so filesystem and FFmpegKit errors cannot leak their original
  locators through callers. Preserve the existing explicit desktop FFmpeg
  installation guidance by performing tool availability checks outside
  extraction/track-analysis catch blocks.
- Keep command arguments, SAF read conversion, output naming and return
  paths, subtitle bytes, output verification and framerate logic unchanged.
- Add `test/ffmpeg_diagnostic_privacy_test.dart`: verify that filename
  derivation does not print identifiers, missing desktop media returns an
  error without its private path, and old command/process/path trace
  signatures cannot reappear unnoticed in the helper.

## Verification

- `git diff --check`: clean locally.
- Flutter SDK was unavailable in the session workspace. The GitHub Linux
  [Flutter quality gate (run 39941700751)](https://github.com/anzilr/SubtitleStudio/actions/runs/39941700751)
  **passed: 779 tests and zero analyzer issues**, including all three new
  `ffmpeg_diagnostic_privacy_test.dart` regressions.
- Verified implementation commit:
  `0f91fcb3a5bdf4a3b6b43ab5bd11336659445689`.
- No Android/Windows/macOS/iOS application builds in GitHub Actions.

## Limitations and follow-ups

This is the **Dart FFmpeg helper boundary**. It does not suppress logging
performed internally by native FFmpegKit, and it does not claim that the
separate waveform audio processor or other external process callers have
completed their privacy audit. These remain targeted follow-ups. Real SAF
file-provider, extraction, and system-tool error acceptance is still needed
on user devices.

Next CP92 work: audit the waveform/native FFmpeg processing diagnostic
boundary, measure import/open/save/restore baselines, then remove verified
unused compatibility shims before the CP93 shared-core acceptance gate.
