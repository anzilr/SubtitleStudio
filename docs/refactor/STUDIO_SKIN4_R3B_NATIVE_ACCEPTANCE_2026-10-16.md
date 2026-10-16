# SubtitleStudio — SKIN-4 R3-B Android & Windows appearance acceptance

**Date:** 2026-10-16  
**Branch:** `refactor/riverpod-architecture`  
**Scope:** user-operated native acceptance after the final Flutter analyze/test CI run succeeds. This is not a substitute for automated tests.

## Build and environment

- Backup the project data and sample subtitle source file before testing.
- Fetch `origin/refactor/riverpod-architecture` and confirm the working tree is clean. Use **the refactor branch**, not development/default or a release tag.
- Flutter **3.47.5** is pinned by GitHub CI. Run `flutter doctor -v`, `flutter pub get` and `flutter devices`.
- **Android:** use `flutter run --profile -d <device-id>` for realistic editing and playback. Use a debug run when detailed widget/framework diagnostics or logs are necessary.
- **Windows:** use `flutter run -d windows --profile` when Windows desktop support/toolchain is installed. Record target OS, device model and display scaling.
- Physical acceptance must be recorded as **manual**; GitHub CI does not perform Android/Windows tests.

## Twelve combinations

Exercise the four built-in skins in every mode. **Carbon Zero** is the new
grayscale-only default for unset selections; explicitly saved skins are not
replaced. Check both pure-white Light and pure-black Classic endpoints.

| Skin | Light | Dark | Classic |
| --- | --- | --- | --- |
| Carbon Zero | [ ] | [ ] | [ ] |
| Carbon & Jade | [ ] | [ ] | [ ] |
| Copper Cinema | [ ] | [ ] | [ ] |
| Aster Violet | [ ] | [ ] | [ ] |

Check distinctly readable surface, input/caret/selection/label, app bar, buttons, popup/context menu, dropdown, slider, modal sheet, dialog, disabled and destructive states. Classic must stay visibly distinct from Dark. Switching only a skin must retain the current mode; switching only a mode must retain the skin. Close/relaunch app and confirm persistence. Missing community ID must show fallback rather than crash and must preserve the stored ID.

## Editing and navigation preservation

1. Open a sample SRT with English, Malayalam, Arabic/RTL, long/multiline text and subtitle markup. In the main Editor, create an unsaved edit; open Appearance Settings, switch skin and mode, then verify the subtitle, selection and undo/redo state were not reset. Repeat in Edit Line with keyboard open, focused cue field, cursor selection, time edit and custom font.
2. Test **embedded Source View** and **standalone Source View** as **a single raw multiline SRT document**, not a per-cue GUI. Edit timestamps and Malayalam/Arabic subtitle lines as literal SRT; verify blank lines, Save/Save As, invalid incomplete-cue save rejection, discard, and appearance changes without losing cursor/text or scroll. Use a disposable test file.
3. In **MSone Submission**, inspect Translator Info, Movie Info and File Selection screens across all modes. Verify field focus/errors, required validators, Save for future toggle, Previous/Next buttons, file selection badges and submit disabled/progress contrast. **Do not submit an actual request** unless intentionally conducting an authorized end-to-end submission.
4. In **Screen Help**, test selected category chip contrast, search, reset, category and nested section expansion, quick navigation and long text.
5. Test selected-subtitle batch-delete confirmations (cancel and test-data-only confirm), index range selection and shift timing validation. Test save/discard dialogs, dropdowns and overlay/toolbar icon visibility.
6. With sample video/audio loaded, verify seek/play/pause, waveform zoom/auto-scroll and video overlay controls do not reset after switching appearance. This does **not** close the separate CP86 native waveform qualification gate.

## Viewports and accessibility

- Android: narrow portrait, landscape, soft keyboard/insets, large text scale, dark system bars, RTL/Malayalam, long text, selection handles and back gesture.
- Windows: resized window, keyboard Tab/Enter/Escape, hover/context menu, high DPI, focus rings, scrolling with mouse/wheel, popup positioning and overflow.
- Upgrade: use an actual backup of an older on-disk Isar DB (not merely a freshly created record with legacy-shaped data), with a safe copy and rollback option.

## Report template

Capture: build commit SHA, target platform, device/OS, Flutter version, combination(s), pass/fail, exact reproduction steps, screenshot and diagnostic logs (sanitized), and whether text, cursor, undo, route, project database or media state changed. **Only mark SKIN-4/5/6 native acceptance complete when both supported device tests and the upgrade gate pass.**

## R4 addendum: fullscreen Settings and Android logs

- Open Settings from Home, Editor and Edit Line: it must fill the available screen, retain a close action and sticky version footer, and initially show **Appearance collapsed**. Expand once, change Carbon Zero modes, close and reopen; section should start collapsed again.
- At 360dp portrait width, show/hide the keyboard with the subtitle-positioning sheet open; ensure the full 3×3 positioning grid and Apply action remain reachable without vertical/horizontal overflows.
- The supplied Android log contains repeated `ListTile background color or ink splashes may be invisible` assertions. If they recur, provide the exact opened screen/interaction plus logs and screenshot for localization. Do not mark this warning resolved merely because CI passes.
