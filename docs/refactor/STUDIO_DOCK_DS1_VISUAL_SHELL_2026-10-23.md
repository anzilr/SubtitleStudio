# SubtitleStudio — DS1 Studio Dock Visual Shell

Date: October 23, 2026  
Branch: `feature/desktop-workspace-preview`  
Baseline: [Studio Dock v1](STUDIO_DOCK_V1_IMPLEMENTATION_DESIGN_2026-10-23.md)

## Delivered
- Constraint-aware **43% video / 13% waveform / 44% grid** center dock with draggable horizontal separators and default-ratio reset.
- Desktop style File/Edit/Subtitle/Timing/Tools/View/Help menu-label row. The menu labels are visual placeholders in DS1; command wiring is a DS2 task.
- Inspector tab layout **Text / Timing / Style / Notes**, preserving current demo edited text while switching tabs.
- Subtitle table showing **Original and Edited side by side** plus start/end, duration, cue number, and review status; horizontally scrollable when the workspace is narrow.
- At ≥1600 logical pixels: Explorer and Inspector are normally visible; at 1250–1599, Explorer is collapsed and Inspector remains; below 1250 both can be opened on demand as overlays.
- Existing sample cues, existing demo keyboard navigation and selection, and explicit no-persistence warning remain.
- Added unit/widget regressions covering geometry, short windows, columns, inspector tab switching, draft retention and narrow overlay visibility.

## Non-goals and acceptance
No production project/video/waveform connection, no new persistence format or mobile UI changes. This is **DS1 prototype only**.
CI: `flutter pub get`, `flutter analyze`, `flutter test` only. Never run platform builds on GitHub Actions.
Windows preview run remains `flutter run -d windows -t lib/main_desktop_preview.dart` on a local machine. Approve visual layout at 1366×768 and 1920×1080 before integrating the live editor.

Next: DS2 focus, multi-selection, context menu, key commands, command palette and workspace preference persistence, maintaining this isolated preview architecture.

## Verified Flutter-only gate

- First full gate [#40011822272](https://github.com/anzilr/SubtitleStudio/actions/runs/40011822272): analyzer passed and 577 tests passed; one geometry test exposed inverted `double.clamp` bounds from floating-point rounding in a very short window.
- Correction `eddd8b31`: clamp upper bounds are normalized against their minima before applying desired video/waveform proportions.
- Final gate [#40012374030](https://github.com/anzilr/SubtitleStudio/actions/runs/40012374030): **578 tests passed, Flutter analysis zero issues**. No platform builds ran in CI.
- Local Windows native preview still needs visual acceptance. The preview remains demo-only with no Isar/media persistence.
