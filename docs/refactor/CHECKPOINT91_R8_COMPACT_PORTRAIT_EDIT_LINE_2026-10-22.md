# SubtitleStudio — CP91 R8: Compact portrait Edit Line pilot

Date: October 22, 2026  
Branch: `refactor/riverpod-architecture`

## Context

The user confirmed the CP91 R7 R2 **Branch from this point** repair works
on Android. CP91 R8 moves to the next roadmap item: better use of narrow
portrait space in Edit Line, without starting the future desktop workspace.

## Changes

1. `EditLinePortraitMetrics` centralizes display-only sizing for phones
   at most 430 logical pixels wide in portrait. The inline video becomes
   170–200 pixels tall rather than 240, content padding reduces from 16
   to 10, and gaps become 8 instead of 16.
2. The **Original** reference cue becomes 76 pixels tall while the **Edited**
   active cue gets 120 pixels. This prioritizes editing space without
   replacing `TextEditingController`, `UndoHistoryController`, `FocusNode`,
   Riverpod providers, keyboard selection or the underlying field widget.
3. At less than 380 pixels of actual time-section width, **Start Time** and
   **End Time** stack vertically to keep their full input widths available.
   The two-column arrangement is retained at wider widths.
4. The existing desktop/landscape/tablet base sizes, video split-pane
   preference, media lifecycle, skins, `.msone` persistence and all save
   operations are unchanged.

## Automated checks

- New `test/edit_line_portrait_layout_test.dart` covers sizing rules for
  narrow portrait, small-height portrait, tablet and landscape.
- Widget test checks 320-pixel stacked time inputs versus 430-pixel
  side-by-side inputs, verifies both widgets remain and confirms no layout
  exception.
- Code commit: `2973baac86dd38819347f09a91ca7eec83408743`.
- [Flutter CI run](https://github.com/anzilr/SubtitleStudio/actions/runs/39851877690):
  **success, zero analyzer issues and 764 Flutter tests passed**.
- GitHub Actions policy: `flutter pub get`, `flutter analyze` and full
  `flutter test` on Linux; **no platform builds**.

## Physical Android acceptance (pending)

1. Fetch `refactor/riverpod-architecture`, locally build debug, open a
   subtitle's **Edit Line** at normal portrait width and at a narrow display
   setting. Verify the Edited cue is taller than Original.
2. Test video loaded, video hidden, and **Edit Time** expanded. On narrow
   phones the full Start and End Time controls should appear one above the
   other without clipping.
3. Keep the keyboard open while editing multiline Malayalam/English text.
   Check text selection, undo, field scroll, Previous/Next and Save actions.
4. Switch Carbon Zero (Light/Dark/Classic) and the other shipped skins.
   Rotate to landscape: verify the existing layout remains comfortable.

## Next checkpoint

CP91 R9: refine compact edit controls only after the R8 phone acceptance,
then proceed to CP92 cleanup/performance and CP93 core architecture handoff.
