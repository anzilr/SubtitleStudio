# SubtitleStudio — SKIN-4 R2: Edit Line cue/time readability pilot

Date: 2026-10-16
Branch: `refactor/riverpod-architecture`
Status: **R2 code committed; full verification in progress**
R1 run (failed solely on two new timing-of-theme-animation widget test assertions): https://github.com/anzilr/SubtitleStudio/actions/runs/38889022163 (420 tests passed, 2 failed)
R2 quality gate: https://github.com/anzilr/SubtitleStudio/actions/runs/38889494374 (pending)
Previous complete: [SKIN-3 appearance UI](STUDIO_SKIN3_APPEARANCE_SETTINGS_2026-10-16.md)

## Implemented — production Edit Line pilot

- `lib/themes/studio_cue_field.dart`: reusable `StudioCueFieldSurface` with neutral semantic `fieldSurface`, on-focus `focusBorder`, unfocused `fieldBorder`; `StudioCueFieldStyle` supplies transparent inner TextField decoration and `onSurface` foreground. Labels/index metadata use `mutedText`. Typography inherits `ThemeData.textTheme` so installed custom app fonts are respected. No controller or UndoHistoryController is recreated by the surface.
- `lib/screens/edit_line/parts/edit_line_original_section.dart`: original field, HTML rendering default, text caret style, Original/index labels, copy/edit icon tints changed from saturated primary, forced white, faded white and independent orange/teal to semantic colors. Unicode formatter, readonly edit toggle, clipboard actions, input flags and undo remain.
- `lib/screens/edit_line/parts/edit_line_edited_text_section.dart`: same shared cue surface, correct edited field foreground/labels, preserved FocusNode, controller, undo, formatting, paste Original and copy actions.
- `lib/screens/edit_line/widgets/edit_text_field.dart`: older reusable `OptimizedTextField` uses the same surface and style, `CharacterCountWidget` now uses muted metadata or semantic danger, not white 50% alpha/red.
- `lib/themes/studio_time_field.dart`: reusable `StudioTimeField` with neutral field fill, semantic text, focused outline and danger role. Keeps supplied TextEditingController, formatter and callbacks.
- `lib/screens/edit_line/widgets/time_component_field.dart`: start/end time and sync controls use semantic colors; all time parser/controller update/validation callbacks and live video synchronization behaviors are preserved.
- `lib/screens/edit_line/parts/edit_line_time_section.dart`: time toggle uses semantic action tint rather than fixed orange.
- `lib/screens/screen_edit_line.dart`: imports the shared component style used by its Dart `part` extensions.
- `test/studio_cue_time_field_test.dart`: focused field/input behavior, all three skins x three modes, Malayalam/Arabic/English text, selected controller/undo preservation, time error semantics. Use zero theme transition animation and settle the frame before inspecting colors so palette tests are deterministic.
- Cleared a pre-existing unused test-helper parameter warning in `test/studio_appearance_settings_test.dart`.

## Intentional activation gate — SKIN-4 R3

**The new palettes are still not installed globally in `MainApp`.** This checkpoint repairs the actual Edit Line fields **under the existing live themes** and tests new palettes in isolation. The user can continue selecting/saving built-in skins and viewing the scoped Settings preview, but live Editor still uses legacy `AppThemes`.

Do **not** flip `ThemeState.themeData` to `StudioThemeFactory` until completing an audit of relevant controls that contain hard-coded colors, notably:

| Source | Remaining risk |
|---|---|
| `lib/screens/edit/widgets/subtitle_card.dart` | Fixed green, blue, white, red, selection and action colors; validate subtitles on all nine backgrounds |
| `lib/screens/edit_line/widgets/edit_line_menu.dart` | Many assorted blue/orange/green/purple icons and a fixed white element |
| `lib/widgets/formatting_menu.dart` | Fixed orange/blue states, fixed white button text and hard-coded panel highlight colors |
| `lib/screens/edit_line/parts/edit_line_layout.dart` | Explicit white app bar icon/text; should use appropriate per-skin onAppBar |
| `lib/screens/screen_edit.dart` | Waveform button alpha-white action colors and related contrast |
| `lib/screens/screen_home.dart` | Static brand colors and navbar controls; migrate before global palette switch |

Some special colors have functional meaning (subtitle formatting, color selection, or media overlay); do not blindly replace all with `primary`. Provide semantic roles, contrast and non-color status indicators as appropriate.

### R3 acceptance

1. Complete those risk sites and remove readibility-breaking usage of `colorScheme.primary` as an *entire editable field background*; maintain separate functional subtitle colors.
2. Resolve all skins, including validated community `StudioSkinDefinition`, from injected `StudioSkinCatalog` and selected `StudioAppearance` **without losing original skin ID if a community skin is missing**.
3. Switch theme through existing Riverpod `ThemeController`, not a new `MaterialApp` or route key. Respect custom font, dark/classic Android system chrome, pause/seek state and edited text.
4. Add Editor + Edit Line provider lifetime tests under actual nine-skin switching, plus focus, controller, selection, undo, raw text and time validation test coverage.
5. Test all nine palettes on Android (portrait, landscape, IME, long Malayalam and Arabic) and Windows with real native records, including saved Isar upgrades.
6. Keep CP86 waveform-native qualification independent.

## Known test result context

R1's two new widget test failures were **assertions read during Flutter's normal theme animation**, not older regression failures. The existing tests passed; analyzer step returned success but two warnings were printed. R2 makes theme tests deterministic and removes warnings. Claim R2 complete only on successful CI.
