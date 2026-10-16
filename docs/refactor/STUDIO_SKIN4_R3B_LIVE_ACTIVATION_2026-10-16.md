# SubtitleStudio — SKIN-4 R3-B: live appearance activation + requested screen audit

**Date:** 2026-10-16  
**Branch:** `refactor/riverpod-architecture`  
**Status:** **R3-B code + Flutter quality gate COMPLETE. Native Android/Windows acceptance PENDING.**

## Verified CI

- **Final quality gate:** https://github.com/anzilr/SubtitleStudio/actions/runs/38903429526
- **Verified code and CI-triggering commit:** `ff2b2f1e5e31a99512188a8bf9fd10f550b25993`
- **Flutter analyze:** **No issues found** (19.1 s).
- **Flutter test:** **440 tests passed**.
- This is not a physical build or runtime acceptance result. Later report/roadmap documentation does not alter the CI-tested Dart implementation.
- Intermediate activation gate: https://github.com/anzilr/SubtitleStudio/actions/runs/38902744294 — 439 tests, analyzer clean.

## Implementation

1. **Live factory activation.** `lib/main.dart` now watches `liveStudioThemeProvider` rather than legacy `ThemeState.themeData`. This provider reads the separately persisted `skinId` and `StudioAppearance` and the injectable `studioSkinCatalogProvider`. `ThemeState.themeDataFor(catalog)` uses `StudioThemeFactory.fromDefinition` for all three bundled skins and future validated community skins. Custom font family is passed through. A missing community ID renders Carbon & Jade in the requested appearance **without overwriting the saved ID**; Appearance Settings supplies the fallback notice.
2. **Source View — both surfaces.** `lib/screens/edit/widgets/source_view_pane.dart` and `lib/screens/source_view/source_view_screen_host.dart` migrate index/timestamp/text, header, actions and warning foregrounds to semantic tokens. Crucially, the standalone `SourceViewScreenHost` now owns **stable Riverpod overrides** in a `StatefulWidget`, resetting only when its actual file/config changes. Previously rebuilding a ProviderScope during theme changes could reinitialize a controller and lose unsaved source state.
3. **MSone Submission.** `lib/screens/msone_submission_screen.dart` uses selected-skin accents for the three form sections and file choices, centralized button geometry, semantic selected/disabled/error/success states, theme-aware wizard navigation via OutlinedButton/ FilledButton, and the shared success action. Existing form validators, file selection and request logic are unchanged. Actual online submission was **not** exercised by CI; do not send a test submission to an external receiver without authorization.
4. **Screen Help.** `lib/screens/screen_help.dart` uses one skin-consistent selected category surface/foreground, neutral guide cards/section accents, standard radius and readable quick-navigation colors. Category and documentation data are unchanged.
5. **Edit Line warnings and waveform toolbar.** `edit_line_dialogs.dart` uses semantic caution/danger/action roles; `waveform_toolbar.dart` uses semantic surfaces, metadata and geometry. No waveform signal-processing, native decoding, video controller or playback behavior was modified.
6. **Appearance Settings.** Preview-only language removed; mode and skin choices now apply to the live MaterialApp. All saved legacy light/dark/classic values are preserved, Classic is not system-following, and mode/skin persistence remains independent.

## Regression coverage

- `test/studio_source_help_skin_test.dart`: nine-theme Help chip selected foreground and embedded Source View multilingual editing/contrast.
- `test/studio_live_skin_activation_test.dart`: nine theme resolutions, imported community-skin catalog injection and safe missing-ID fallback; focused editing text, controller, selection and UndoHistoryController identity through nine theme rebuilds.
- `test/source_view_theme_scope_lifecycle_test.dart`: nine skin changes do **not** recreate a route-scoped Source View controller.
- Previous R3-A and R3-B P1 widget tests cover popup commands, subtitle cards, confirmation/selection/time-shift sheets, input focus and nine color combinations.

## Native acceptance — next

Follow [SKIN-4 R3-B Android/Windows acceptance](STUDIO_SKIN4_R3B_NATIVE_ACCEPTANCE_2026-10-16.md) in profile build, record device/OS/commit and test all 3 skins × Light/Dark/Classic. Include an actual historical on-disk Isar DB upgrade, Source View unsaved edits, MSone wizard and Help, video/player focus and long Malayalam/Arabic/RTL lines. **Do not call the release native-verified until the user completes this step.**

## Remaining separate roadmap

- **SKIN-5 / DESIGN-2:** clean up remaining low-risk feature-local overrides, dialogs, buttons and desktop responsive layouts across screens not yet fully migrated.
- **SKIN-6 / DESIGN-3:** device visual accessibility, keyboard/focus, color contrast and migration acceptance.
- **SKIN-EXT-2/3:** community file installer/export and open-source skin-creator website (data-only v1 schema remains the contract).
- **Checkpoint 86:** native waveform qualification — remains independent.
- No default/upstream branch, release tags, native platform build, Isar generated schema or subtitle parsing code was modified.
