# SubtitleStudio — SKIN-4 R5 Android contrast and marked-lines acceptance

**Date:** 2026-10-16  
**Branch:** `refactor/riverpod-architecture`  
**Flutter gate: VERIFIED.** [Successful R5 run 38915923306](https://github.com/anzilr/SubtitleStudio/actions/runs/38915923306): **448 Flutter tests passed; 0 analyzer issues**, verified code checkpoint `5e0c15563dbd1c5442b15a7287648723486fe213`. Native Android/Windows manual acceptance is still pending; native device testing is not performed in GitHub Actions.

## Device findings and corrections

1. **Editor waveform icon:** The Editor app-bar waveform toggle used a fixed white icon, invisible against Carbon Zero Light. It now derives the foreground from the live app-bar theme; the inactive/hidden toggle remains distinguishable.
2. **Home expanded FAB:** The five actions had fixed white icon/label colors while Carbon Zero Dark/Classic primary buttons use light backgrounds. They now use the same `colorScheme.onPrimary` contrast role as the parent Menu FAB.
3. **Marked Lines theme:** Marked badges, selected/resolved/unresolved states, editable text, comment actions and copy states had hard-coded red, blue, green and grey values. These now use primary, on-surface-variant, outlines, field surfaces and semantic error only for actual deletion. Repeated widget-build debug prints have also been removed.
4. **Project Settings → Marked Lines:** The nested route was a 70% `DraggableScrollableSheet` with a 90% maximum. The replacement is a full-height, safe-area modal while retaining the existing marked-lines editing/callback logic and internal scrolling.
5. **Go To Line:** The custom slider's blue track, thumb and value indicator explicitly ignored the active skin. All now derive from `StudioDesignTokens`, including value text and field-surfaces.
6. **Danger and warning consistency:** The previous Home delete/clear dialogs used several shades of hard-coded red, while line/batch deletion, reset and app-data clearing used theme tokens. `StudioStatusColors` now supplies shared **destructive red** and **warning amber** for light/dark modes. Skin palettes, `ColorScheme.error/onError` and `StudioDesignTokens.dangerText/caution` resolve the same roles across all built-ins and future community-skin renderings. Carbon Zero's decorative palette remains grayscale; **red/amber are deliberate functional safety exceptions**. Cancel actions and mere marked/edited state must not use danger red.

## Android log review

The supplied 2026-10-16 debug log indicates successful startup and an 895-line session loaded on Android 14 (OnePlus CPH2381). It shows marked-line loading with seven records, followed by repetitive `_buildMarkedLinesList` debug diagnostics. The attached log alone does not prove or locate an icon contrast problem; the issues were observed visually on the device. No app crash was indicated by the supplied excerpt. Build-tool compatibility warnings were already present and are unrelated to these colors.

## Device verification

- Carbon Zero **Light**: Editor appbar waveform icon visible in its shown and hidden states; other buttons retain normal foreground.
- Carbon Zero **Dark and Classic**: all five expanded Home FAB icons and labels visible against their background. Open/Create/Extract/Import/View callbacks unchanged.
- From Editor and Project Settings: open Marked Lines, scroll, filter comments and resolved status, edit, copy and unmark; verify all status labels readable and only delete actions red. Project Settings version opens full screen and closing it reveals Project Settings, not the home screen.
- Go To Line in Light/Dark/Classic: slider track, thumb, indicator, value label, typing and jump behavior consistent. No blue override.
- Compare delete session, clear sessions, delete subtitle, batch delete, reset settings, clear app data, and delete comment. Confirm common red for destructive actions and amber for non-destructive warnings. **Use test content; do not execute destructive Clear All actions on real data.**
- Repeat basic Source View and Edit Line keyboard workflow. Check logs for build-time/runtime exceptions.

## Notes

- No database migration, parser changes, hotkey rewrites or upstream-branch modifications.
- Existing saved skin/mode settings and player/waveform logic remain unchanged.

## Verification history and device-width correction

- Initial R5 code at CI [38913706270](https://github.com/anzilr/SubtitleStudio/actions/runs/38913706270) passed 444 tests with zero analyzer issues.
- The new real-modal Go To Line slider regression exposed an asynchronous diagnostic logging call that delayed modal opening. Logging no longer blocks navigation.
- The 390dp test then exposed a 35px horizontal overflow, which was fixed with responsive card/header spacing. CI [38915501196](https://github.com/anzilr/SubtitleStudio/actions/runs/38915501196) passed 448 tests with zero analyzer issues.
- The supplied Android log reported a 360dp screen, so the regression was tightened to that actual viewport and action-row labels gained scale-down fitting. **Final CI [38915923306](https://github.com/anzilr/SubtitleStudio/actions/runs/38915923306) passed all 448 tests and analysis.**

**Acceptance gate remains:** verify the real Android screenshots and interactions before closing the physical-device checkpoint. Use debug for the initial visual pass, then profile for performance follow-up if needed.
