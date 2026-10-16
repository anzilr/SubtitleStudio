# SubtitleStudio — SKIN-1 nine-appearance theme foundation

Date: 2026-10-16
Branch: `refactor/riverpod-architecture`
Implementation status: **SKIN-1 R2 committed, final verification pending**
Initial successful quality gate: https://github.com/anzilr/SubtitleStudio/actions/runs/38867202442 — 391 tests, 0 analyzer issues.\nR2 gallery-inclusive quality gate: https://github.com/anzilr/SubtitleStudio/actions/runs/38867646977 (pending).

## What changed

- `lib/themes/studio_skin.dart`: typed `StudioSkin` (Carbon & Jade, Copper Cinema, Aster Violet), `StudioAppearance` (Light, Dark, Classic) and immutable independent `StudioAppearanceSelection`; stable explicit persistence identifiers.
- `lib/themes/studio_palette.dart`: nine immutable `StudioPalette` definitions with canvas, raised/surface/field levels, user text, muted text, action text, fields/input stroke, app bars and functional warning/error semantics. Classic is a **distinct** near-black palette, not an alias for dark.
- `lib/themes/studio_design_tokens.dart`: new semantic roles `fieldBorder`, `focusBorder`, `selection`, `caret`, `disabledText` in the existing `ThemeExtension`. `copyWith` and `lerp` maintain these fields. The existing light/dark/classic legacy token definitions remain functional.
- `lib/themes/studio_theme_factory.dart`: one shared `StudioThemeFactory.resolve(skin, appearance, fontFamily: ...)` producing Material3 `ThemeData` with deliberate `ColorScheme`, cue field decoration, type, buttons, app bar, surface, dialogs and selection. No duplicated screen/widget implementations for each palette.
- `lib/themes/studio_skin_preview.dart`: a shared **read-only** gallery displaying all three skins in all three modes, designed for later SKIN-3 Settings integration. No persistence or interaction is performed.\n- `test/studio_skin_theme_test.dart`: all nine palettes, persisted-id type contract, independent selection copy behavior, readability/field-border contrast, distinct Classic, custom-font inheritance and text-controller survival across theme previews; compact 320px-wide gallery widget smoke test.
- `.github/ci-checkpoint`: analyzer + full Flutter suite gate only; no native platform builds.

## Scope and data safety

**Do not confuse this checkpoint with enabling skins in the app.** The new factory is opt-in and is **NOT YET** connected to `lib/main.dart` / `ThemeController`. The current production themes and user's persisted `Preferences.themeMode` are unchanged. No Isar schema, project/checkpoint files, player, waveform, controller lifecycle or platform implementation was modified.

This order is deliberate: the existing `Edit Line` source/edited text widgets use `colorScheme.primary` as the input-field background and force white text. Turning on the nine-theme resolver application-wide before migrating these widgets would create unreadable inputs in some modes.

## What next

### SKIN-2 — persistence/controller migration

1. Review a nullable `skinId` field in the existing Isar `Preferences` record and generate `models.g.dart` with the pinned builder, preserving all old records. **No manual edits to generated schema**.
2. Preserve legacy saved `light`/`dark`/`classic` mode strings exactly; missing skin maps to Carbon & Jade; new-install target is Carbon & Jade/Dark while preserving explicit legacy mode selection.
3. Replace `ThemeMode.system` used as Classic with `StudioAppearance.classic` at the **app preference boundary**. Real system-following appearance is a separate optional future feature.
4. Ensure `ThemeController` state protects skin+mode from custom-font set/remove operations and asynchronous initial preference load.
5. Ensure Android system status/navigation bar brightness resolves from actual palette brightness, including Classic.
6. Before enabling live route-wide skin switching, guard existing white-on-primary legacy widgets, especially Edit Line text inputs; coordinate with SKIN-4 pilot and migration feature flag.

### SKIN-3 through SKIN-6

Appearance Settings with independent selection and mode toggle; neutral reusable cue and time-input fields; incremental screen-by-screen theme rollout; Android and Windows device verification, accessibility and final integration gate.

**Checkpoint 86 native waveform qualification remains the next original technical roadmap milestone, separate from SKIN-2.**
