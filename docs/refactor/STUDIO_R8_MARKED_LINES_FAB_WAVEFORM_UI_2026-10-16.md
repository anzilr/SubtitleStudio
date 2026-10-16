# SubtitleStudio R8 — Marked Lines filter, Editor transport skin and Android waveform toolbar

**Date:** 2026-10-16  
**Branch:** `refactor/riverpod-architecture`  
**Baseline:** [R7 452-test gate](https://github.com/anzilr/SubtitleStudio/actions/runs/38921649751), user confirms prior Riverpod waveform lifecycle error is resolved on Android.

## Android findings

The OnePlus CPH2381 Android 14 debug log at ~18:19 records successful compact peak/metadata waveform processing and subsequent subtitle navigation and video playback. It records one Flutter UI error: a horizontal `RenderFlex` overflow of **23px** at `lib/features/waveform/widgets/waveform_rendering.dart:189`. The control Row was constrained to about **304 logical pixels** while its controls were wider. No native crash is indicated by this supplied log, which does not by itself prove all waveform workflows are stable.

## Fixed in R8

1. Marked Lines now uses a single pure `MarkedLinesFilter.apply` for the displayed list and its counts. **Unchecked:** only genuinely marked rows (`marked == true`), including marked rows without comments. **Checked:** those rows plus unmarked entries whose comments contain non-whitespace characters. The merge is deduplicated by cue number, sorted, and prefers the live marked record to a stale comment query copy. This also protects callers if they inadvertently supply comment-only rows in the marked list.
2. The saved 'show all comments' setting loads asynchronously on opening the sheet, but cannot override a subsequent user checkbox tap. The setting is still persisted.
3. The extra 'Show:' label and its filter-list icon have been removed. The All / Resolved / Unresolved chips remain directly accessible.
4. Editor's optional floating video play/pause is now `EditorFloatingPlayPauseButton`, reusing the prior video callback and actual playing stream while obtaining background/foreground from the live `ColorScheme.primary/onPrimary` for all four skins and Light/Dark/Classic.
5. Waveform toolbar's constrained action group now scrolls horizontally without RenderFlex overflow at 360dp. Its active/inactive track, magnet, overlap, Add Line, accept/cancel and auto-scroll icons use theme roles rather than fixed orange/blue/red/teal.
6. New tests: `marked_lines_filter_test.dart`, `marked_lines_sheet_checkbox_test.dart`, `editor_floating_play_pause_theme_test.dart`, and `waveform_toolbar_narrow_screen_test.dart`.

## Automated verification

- First gate: [CI 38925010484](https://github.com/anzilr/SubtitleStudio/actions/runs/38925010484) — **468 tests passed, 0 analyzer issues**.
- Final gate with real Marked Lines checkbox widget test and 360dp overflow protections: [CI 38926044286](https://github.com/anzilr/SubtitleStudio/actions/runs/38926044286) — **469 Flutter tests passed, 0 analyzer issues** at code commit `b25faf4a7742cd1dcd842dd3814e6915495ff110`.

## Native/manual acceptance checklist

- On the original Android 14 phone, open Marked Lines from both Editor and fullscreen Project Settings. Verify checkbox off shows **only bookmarked/marked cues**, on additionally shows unmarked commented cues, and off hides those extras again; after reopening, the saved setting persists. All/Resolved/Unresolved filters must compose correctly with the checkbox. Check a marked cue with no comment and a commented but unmarked cue. Check create/edit/delete comment and unmark.
- Confirm the Show text/filter icon are absent and filter chips are usable at 360dp and enlarged accessibility text.
- Toggle Editor floating playback in Carbon Zero Light/Dark/Classic and at least one colorful skin; icon and background must remain legible when playing/paused, with unchanged video controls.
- While waveform is ready, verify toolbar no longer overflows in 360dp portrait, and horizontal scrolling exposes all controls. Test zoom, snap, overlap, add line and settings. Continue monitoring R7 playback state and R6 compact cache on the original large-media file.
- Native Windows testing, historical Isar upgrade, and full accessibility checks remain open.

## Remaining roadmap and recommended order

**Immediate:** finish R8 Android manual regression and waveform CP86 qualification (audio-stream selection, SAF, cancel/reload, seek/playhead and cache/long-media profiling); then Windows native check and historical Isar migration acceptance.

**Appearance DESIGN-2/SKIN-5:** complete screen-by-screen migration of remaining custom controls to shared themes (Home, Editor, Edit Line, History, project settings, Source View, import/export, waveform/settings/menus), ensuring contrast and consistent component geometry across twelve built-in combinations. DESIGN-3/SKIN-6 is accessibility/goldens/large-text/RTL and Android/Windows stabilization.

**History UX-2 and UX-3:** user-friendly labels (Current version, editing path, pin version), then true version timeline and branch-lane graph backed by the existing checkpoint graph (not a fake mockup).

**Mobile UX-4:** compact keyboard-aware Edit Line editor with safe original/translation/timing/media and Next/Save navigation. Follow with UX-5 app-wide UI migration and UX-6 clean-up.

**Open-source skins:** SKIN-EXT-2 user-import/export and validation; SKIN-EXT-3 client-side Skin Creator webpage. Core data-only factory and skin schema are done, website/import UI is not.

**Technical refactor:** complete injectable storage and typed project/file access migration, split broad Editor/ProjectManager/Checkpoint UI orchestrations, remove static globals and obsolete compatibility shims, measure performance and logging, and isolate platform toolchain modernization. Some dated v4 lower sections are historical plans rather than up-to-date milestones.

**Desktop:** specialized workspace layout is deferred until Editor reuse/interfaces and design system stabilize. Upstream five-platform integration gate remains a separate final stage.

No Isar schema or subtitle parsing modifications were made in this R8 patch.

## Test-discovered usability repair

The initial end-to-end checkbox gate [38925474773](https://github.com/anzilr/SubtitleStudio/actions/runs/38925474773) caught two independent overflow assertions at Android 360dp: the header's resolved/total summary overflowed 57 logical pixels and the one-line start→end timestamp chip overflowed 111 pixels. The header now uses flexible wrapping; each cue card stacks full start and end times inside a bounded row. This was fixed in code, not silenced in tests. [Final gate 38926044286](https://github.com/anzilr/SubtitleStudio/actions/runs/38926044286) passed all 469 tests.

R7 Riverpod provider-during-build exception was reported **resolved by the user** after Android testing. This does not imply comprehensive CP86 native waveform or platform acceptance.
