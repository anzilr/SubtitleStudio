# SubtitleStudio — CP91 R9 R3: Restore Edit Line controls

Date: October 23, 2026  
Branch: `refactor/riverpod-architecture`

## User feedback

After reviewing the CP91 R8/R9 compact portrait Edit Line screen on Android,
the user preferred the original editing buttons and Edit Time arrangement.
This is a focused presentation rollback rather than a general rollback of
the successful Riverpod, video, or checkpoint work.

## Changes

1. Restore the original single-row editing button order on narrow and wide
   screens: Previous, Dictionary, Formatting, optional Subtitle Actions,
   Save, optional Play/Pause, Next. Remove the expandable Tools control.
2. Restore the original 24–36px icon-button width constraints instead of
   making each common action at least 48px wide on compact phones.
3. Restore Start Time and End Time fields side by side at all supported
   widths, rather than stacking them below 380px.
4. Restore the original 16px vertical padding around Edit Time and 16px
   space after its section.
5. Update widget regressions to assert all actions remain immediately
   visible at 320px, preserve action order, retain no-video behavior and
   keep both time fields aligned at 320px and 430px.

## Deliberately unchanged

- CP91 R8 compact Original/Edited cue area dimensions and inline-video
  height, including the explicit video-slot identification introduced in
  CP91 R9 R2 to fix the duplicate `VideoPlayerWidget` GlobalKey.
- Editing controllers, text content, time parsing and validation, callbacks,
  keyboard behavior, subtitles, persistence, Isar and `.msone` format.
- Riverpod state, skins, media-player initialization and disposal.

## Verification

- Code commit: `4219be02b6d056ab85217104e57e6e8205a7b7bb`.
- [GitHub Actions 39913695448](https://github.com/anzilr/SubtitleStudio/actions/runs/39913695448):
  768 Flutter tests passed and zero analyzer issues.
- No Android/iOS/macOS/Windows/Linux app build in Actions.

## Android acceptance

Fetch and locally rebuild the latest `refactor/riverpod-architecture`.
Open Edit Line at phone width with and without video. Confirm that all
editing buttons appear in one row with no expandable Tools control;
Dictionary, Formatting and Subtitle Actions work; and both time fields
appear alongside each other when Edit Time is opened. Test editing and
saving a subtitle, playing/seeking a video, and toggling Resize Player on
Keyboard without a duplicate video GlobalKey error. Native `libmpv.so`
hot-restart lifecycle acceptance remains separate.
