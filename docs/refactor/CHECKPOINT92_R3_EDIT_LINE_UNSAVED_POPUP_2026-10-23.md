# SubtitleStudio — CP92 R3: Edit Line unsaved-change popup

Date: October 23, 2026  
Branch: `refactor/riverpod-architecture`

## User feedback and root cause

Exiting Edit Line with unsaved edits presented a confirmation as a bottom
sheet. The old function constructed an `AlertDialog` *inside*
`showModalBottomSheet`, so the dialog's visual hierarchy and positioning
were wrong despite the `AlertDialog` widget being present.

## Changes

- Present the unsaved-change confirmation using `showDialog` with an
  `AlertDialog`, consistent with the requested popup behavior.
- Expose explicit **Cancel**, **Leave Without Saving**, and **Save & Leave**
  choices. Cancel keeps editing; Leave discards and exits; Save runs the
  existing `_updateSubtitle` callback, then exits only if saving succeeds.
- Block repeated saves, conflicting actions, and system Back dismissal while
  a save is in progress; show **Saving...** during that operation.
- Keep original Edit Line edit-button and Start/End Time arrangements;
  no changes to cue data, editing behavior, video ownership, or screen layout.
- Retain the distinct *Original Line* warning sheet, which is outside this
  request.

## Regression checks

`test/edit_line_unsaved_changes_dialog_test.dart` covers:

1. Dialog is an `AlertDialog` rather than a `BottomSheet`; Cancel preserves
   the editing route and invokes neither save nor discard.
2. Leave Without Saving invokes discard once, without saving.
3. Failed save leaves the popup open; retry succeeds and exits once.
4. Pending save disables competing actions and repeated submissions until
   completion.

## Verification and limits

Code commit: `7812d9a353acbd02af846be9f6a6f811ae4d40ac`.

Flutter Linux quality gate:
[run 39919836452](https://github.com/anzilr/SubtitleStudio/actions/runs/39919836452)
**PASS — 776 Flutter tests, zero analyzer issues.**
Only Flutter dependency resolution, analysis and tests ran. No native
platform builds were run in CI.

Native acceptance still needed on Android: edit a cue, press Back, test
Cancel, Discard, Save, invalid save, and rotate/change appearance during the
confirmation. Confirm no duplicate route pop or video widget error. This
checkpoint does not claim the historical media_kit native fault is resolved.

## Remaining CP92 / CP93 work

- CP92: sanitize raw FFmpeg and FFprobe command/process output, personal
  media paths, SAF locators and exception text in logging; retain safe,
  useful diagnostics without exposing the input or output path.
- CP92: complete measured import/open/save/restore performance baselines,
  compatible shim audits, and safe cleanup with focused regressions.
- CP93: final shared-core compatibility gate and local Android/desktop
  device verification, followed by production desktop-workspace integration.
