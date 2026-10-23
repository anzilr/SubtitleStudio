# SubtitleStudio — CP92 R2: Extraction diagnostic privacy

Date: October 23, 2026  
Branch: `refactor/riverpod-architecture`

## Scope

Review the subtitle extraction file service, the extraction options sheet,
and the shared URI/path normalization diagnostics these two callers use.
The debug trace previously included personal video paths, proposed subtitle
filenames, temporary output paths, destination paths, Android SAF URIs and
original exceptions that may themselves contain file paths. The extraction
sheet also copied certain raw exception messages into error snackbars and
structured application logs.

## Changes

1. Replace path, filename, SAF locator and exception interpolation in
   extraction diagnostics with neutral phase/status messages. Retain useful
   numeric facts such as subtitle track index, output size, retry count,
   existence status and enabled processing options.
2. Use path-free user-facing error messages for extraction/processing failure
   while keeping actionable instructions to retry or choose another track.
3. Do not alter the actual file locators, Android SAF/iOS save picker flow,
   desktop copy destination, output verification, saved subtitle content,
   imported session, temporary-file cleanup, or `.msone` format.
4. Remove raw path/SAF parameter interpolation from the mobile and desktop
   `FFmpegHelper` path-conversion diagnostics without changing normalization.
5. Add `subtitle_extraction_privacy_test.dart` with a real temporary SRT
   copy/verify/read roundtrip, missing-temp-file error check, debug print
   capture and a screen-trace source regression guard.

Only the two audited extraction components and shared path conversion are
covered by this pass. FFmpeg execution helpers still have separate raw
command/process-log traces and require a later dedicated audit; therefore
this is **not** a claim that all media diagnostics are private. AppLogger's
existing separate redaction remains in place.

## Verification

- Main code commit: `5d992827dd1730291276406d3a7eb0066c166e22`.
- CI correction: `ad1e61f5ffd033f743e26b3ec7b832605e6eba3e`
  (literal `$` in two test strings required raw Dart strings).
- Follow-up helper commit: `3e41c5e207e64680f97feb0a36b98b278938424e`.
  The first executable privacy test identified path-bearing `FFmpegHelper`
  conversion logs; the follow-up removes those messages from the shared
  normalizer without affecting path values.
- [GitHub Actions — Linux analysis and full Flutter tests, run 39918055526](https://github.com/anzilr/SubtitleStudio/actions/runs/39918055526).
  **Passed: 772 tests, zero analyzer issues.** The earlier CI attempts were
  superseded after fixing the Dart test literal and path-converter trace.
- No native/platform builds in CI. Physical Android SAF, iOS picker and
  desktop overwrite smoke tests remain device/local acceptance work.

## Follow-up

Proceed with CP92 focused performance measurement for import/open/save/restore
and audit the remaining extraction helper/logging surfaces separately. Do not
reinterpret this checkpoint as a fix for the independent native hot-restart
`libmpv.so` lifecycle crash or as mobile Edit Line physical acceptance.
