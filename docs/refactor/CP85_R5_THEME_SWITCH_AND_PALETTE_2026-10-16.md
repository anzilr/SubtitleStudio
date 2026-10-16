# SubtitleStudio CP85 R5 — Android theme-switch crash investigation and UI palette stabilization

Date: 2026-10-16
Branch: `refactor/riverpod-architecture`
Baseline: Android debug build `3.0.0+30`, OnePlus CPH2381, Android 14, user-provided PowerShell/Flutter console log, 2026-10-16 about 09:03–09:07 Asia/Riyadh.

## Observed device regressions

1. Home theme switching succeeds.
2. Editor theme switching replaces the edit screen with an app bar `Loading...` and a spinner.
3. Edit Line theme switching crashes the route.
4. Light theme background looks grey.
5. Project Settings uses unrelated colors for ordinary headings, file cards, stats and action links.

## Log-grounded failure diagnosis

- At 09:04:53 and nearby, changing the theme caused repeated `EditController: Initialized` and `EditScreen lifecycle: disposing` events. `EditScreenHost` and `EditSubtitleScreenHost` had constructed a **new Riverpod configuration override** every time their widget built.
- At 09:06:22, Flutter reported `Bad state: Using "ref" when a widget is about to or has been unmounted is unsafe`. Stack: `screen_edit.dart:103` -> `_selectedVideoPath` -> `edit_subtitle_actions.dart:252`. `MaterialPageRoute.builder` was reading parent state that became invalid after theme-driven reconstruction.
- At 09:06:35, another async navigation continuation accessed `subtitleLines` through `ref` after deactivation (`edit_subtitle_actions.dart:283`).
- Before changes, `AppThemes.lightTheme` used `colorScheme.surface = #CED4DA` and different primary/secondary/text colors in all theme modes.

## Implementation

- Both Editor and Edit Line route hosts are Stateful wrappers retaining **stable ProviderScope override instances** across rebuilds, recreating configuration only when actual editor route inputs change.
- `EditScreenState._navigateToEditSubtitleScreen` and the initial-line route capture video path, loaded state, secondary subtitle list, and IDs **before** handing a builder to Navigator, and use `mounted` guards after async returns. No deferred builder reads Riverpod via the old parent screen.
- Scope-local test-only controller factories permit direct widget tests that observe provider recreation without opening Isar, video decoding or project UI.
- Light theme uses a pure-white scaffold and surface, subtle neutral variants and indigo-brand primary; dark/Classic share the same palette vocabulary. Legacy white-on-AppBar controls are protected by a dark navy AppBar background.
- `ProjectSettings` section headers, file icons, stat cards and actions use one primary semantic accent and restrained neutrals. The Clear action uses the error semantic role rather than arbitrary red styling.
- Dedicated widget tests switch themes three times and assert no extra `EditController` or `EditLineController` builds, plus light surface and cross-theme accent invariants.

## Verification

- [Successful GitHub Actions run 38861456875](https://github.com/anzilr/SubtitleStudio/actions/runs/38861456875)
- Code gate commit `05ca628daa2396ae72162b4bcc4e5adb03718261`.
- Flutter analyzer: **No issues found**.
- Full suite: **386 passing tests**.
- Previous CI attempts detected and prompted correction of unsupported Override typing, a test-only provider-scope mistake, and `pumpAndSettle` on intentional perpetual progress indicators. Latest gate is green.
- This CI result is **not** physical-device validation of theme transitions, video-controller retention, IME state, or file access.

## Required Android checks before closing

1. Open project in Edit Screen; cycle light → dark → Classic → light. No `Loading...` reset, return-to-Home, dropped video, line reinitialization or lost scroll.
2. Open Edit Line, type unsaved Malayalam/text, cycle themes; no route crash, navigation or text/cursor loss.
3. While Edit Line is open and after switching themes, use Previous/Next, Save, Back and full-screen video comment, verifying existing unsaved-edits dialogs and controllers.
4. Open Project Settings under light/dark/Classic and check path/action text contrast, encoding selection, status labels and buttons.
5. Confirm white light canvas and one clear brand accent; send screenshots of remaining rainbow-colored components for later migration.

## Follow-up visual-system work

UX-1 now has an application-wide baseline and Project Settings pilot, but other sheets still contain hard-coded decoration colors. A UI-color audit and incremental migration by feature is needed. Keep semantic distinctions for warnings/errors/success, selected subtitles/markers, waveform channels, and branch lanes—do **not** replace every meaningful signal with a single color. Prioritize Editor/Edit Line toolbars, common bottom sheets, Home cards and modal action components. Avoid modifying native media behavior or Isar schema in visual-style commits.
