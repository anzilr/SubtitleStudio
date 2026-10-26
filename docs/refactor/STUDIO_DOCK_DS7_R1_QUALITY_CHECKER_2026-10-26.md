# SubtitleStudio — DS7 R1: read-only subtitle quality checker

Date: 2026-10-26
Branch: `feature/studio-dock-integration`

## Scope

Begin the quality/productivity phase using Subtitle Edit's List Errors and
Fix Common Errors workflow as references. This checkpoint implements a reusable
**read-only** Dart checker and a Studio Dock review dialog; no automatic fixing
or subtitle mutation is authorized by the checker.

## Shared checks

- Invalid or non-positive timing; chronological overlaps and short gaps.
- Minimum and maximum duration; characters per second (CPS).
- Excessive line length, more than two lines, and empty visible text.
- Basic SRT/ASS markup stripping for measurements only. SRT text, including
  intentionally blank lines, is left unchanged.
- Configurable immutable rules profile with conservative default limits.
- Stable report ordering in the original cue list, independent of timestamps.
- Independent report issues may refer to the same cue (counts are distinct).

## Studio Dock

- New Tools → Check subtitle quality… action.
- The dialog shows total issues and affected cues, filters by issue type, and
  navigates to the selected cue through the existing editor selection route.
- The Tools popup is dismissed before presenting the dialog, preserving the
  modal/shortcut behavior. Dirty drafts use existing Apply/Discard/Cancel.
- No additional top toolbar buttons; mobile UI stays unchanged. The validator
  itself is platform-agnostic and can be reused when mobile UI is planned.

## Limitations and next step

- Character counts use Unicode scalar values, not grapheme clusters or
  proportional subtitle pixel widths; this matters particularly for Malayalam.
- Does not yet detect spelling, language-specific punctuation, shot changes,
  or scene-specific reading-speed profiles.
- Next checkpoint: configurable presets, language-aware counting, a safe
  correction-plan preview, and checkpoint-backed explicit apply.

## Verification

- Unit coverage for thresholds, timing chronology, invalid timestamps,
  markup-only cues, profiles, and blank-line preservation.
- Widget coverage for Tools menu entry, read-only report, and navigation.
- Run Flutter analysis and focused/full tests in GitHub Actions. No platform
  builds. Native Windows UI acceptance remains deferred.
