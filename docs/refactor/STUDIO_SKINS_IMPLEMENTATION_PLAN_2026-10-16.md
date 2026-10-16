# SubtitleStudio — Three-Skin Appearance Architecture: Approved Plan

Date: 2026-10-16
Branch: `refactor/riverpod-architecture`
Decision status: **ARCHITECTURE APPROVED; SKIN-1 R2 COMPLETE (theme factory and gallery code, not yet activated in MainApp)**
Verification: [successful SKIN-1 R2 CI](https://github.com/anzilr/SubtitleStudio/actions/runs/38867646977): **392 tests passed, zero analyzer issues**. Verified code: `fa6aa09c887af916104ec03930e85919bcf8d2b2`.
Implementation report: [SKIN-1 report](STUDIO_SKIN1_THEME_FOUNDATION_2026-10-16.md).
Preferred first preview: **Carbon & Jade / Dark**
Checkpoint 85 R6: **Android stability test complete (user-confirmed)**.
Last CI-verified code gate: CP85 R5, run 38861456875, 386 tests passing, analyzer clean.
Related: [Refactor roadmap v4](REFACTOR_ROADMAP_V4.md), [UX roadmap](SUBTITLESTUDIO_UX_ROADMAP_2026-10-16.md), [nine palette definitions and contrast research](STUDIO_PALETTE_DECISION_2026-10-16.md).

## Decision record — user-approved requirements

1. Three built-in skins: **Carbon & Jade**, **Copper Cinema**, **Aster Violet**.
2. Each skin has three appearance modes: **Light**, **Dark**, **Classic** (3 × 3 = **9** combinations).
3. Skin and appearance mode are **independent user settings**. Both must persist across restarts.
4. Changing mode keeps skin; changing skin keeps mode; changing custom font keeps both.
5. **Carbon & Jade / Dark** is the initial review target and proposed new-install starting combination, **not** an instruction to replace an existing user's explicitly saved appearance mode.
6. Classic is a distinct near-black, high-contrast appearance per skin, **not** an alias for Flutter `ThemeMode.system` or the same scheme as Dark.
7. All combinations use **one shared semantic design system and widgets**. Do not build nine independent screens or scatter direct hex colors through feature code.
8. Implement in isolated, reviewable steps. Preserve checkpoint/project data, native media behavior, and Android/Windows and other supported platforms.
9. Keep all work confined to `refactor/riverpod-architecture`; no changes to `development`, `main`, upstream or release tags without separate approval.
10. UX appearance work is a parallel **design dependency**. The original next technical workstream remains **Checkpoint 86: waveform native qualification**; do not relabel it as a theme milestone.

## Reference skin token matrix — approved families

These were proposed and visually reviewed. Detailed contrast pairs and working swatches are in the palette decision document. Exact values may be tuned after device review without renaming the skin.

| Skin | Light canvas / field / action | Dark canvas / field / action | Classic canvas / field / action |
|---|---|---|---|
| Carbon & Jade | #FFFFFF / #F0F8F4 / #0A7860 | #0E1517 / #213135 / #55E0BC | #050909 / #1B2926 / #56DEB6 |
| Copper Cinema | #FFFEFC / #FFF8EF / #93601E | #151414 / #302826 / #FFBE78 | #090909 / #27221D / #F4B969 |
| Aster Violet | #FFFEFF / #F7F1FC / #7444AA | #15121D / #30273A / #D6ADFF | #08070B / #251F2D / #C8A1FF |

In every mode, the Original and Edited cue fields use a **neutral fieldSurface with contrasting onSurface**, not an action-colored block. Keep `selection`, `focusBorder`, `inputBorder`, `mutedText`, `onPrimaryAction` and semantic error/warning/success colors explicit.

## Source audit / current integration points

- `lib/themes/theme_controller.dart`: `ThemeState` contains `ThemeMode themeMode` and custom-font values; `ThemeState.themeData` switches between three static `AppThemes` objects. `_themeModeFromString` maps `'classic'` and null to `ThemeMode.system`. `setCustomFont(null)` constructs a new `ThemeState(themeMode: ...)`; new skin state must survive this and all font operations.
- `lib/themes/theme_preferences_repository.dart`: `ThemePreferencesRepository` already uses injected Isar and `PreferencesStore`, storing `Preferences.themeMode`. **There is currently no saved skin field.**
- `lib/database/models/models.dart`: `@collection class Preferences` stores `String? themeMode`, app font path and name. A new independent persisted skin value will require a design decision and isolated model migration.
- `lib/database/models/models.g.dart`: generated Isar code is tracked. Any new field in the Isar model requires the appropriate generator output and migration/compatibility tests before use; do not hand-edit generated schema code.
- `lib/themes/theme.dart`: light/dark/classic static themes. Classic currently reuses the dark `ColorScheme` and dark semantic tokens with a black canvas, so it is not yet independently designed.
- `lib/themes/studio_design_tokens.dart`: existing extension defines semantic colors, but lacks distinct `fieldBorder`, `focusBorder`, `selection`, etc.; `classic = dark`.
- `lib/main.dart`: `MainApp` watches `themeControllerProvider`, passes `themeState.themeData` into `MaterialApp`, but computes status/navigation bar brightness from `themeMode == ThemeMode.dark`. Classic should be treated as dark in system chrome based on resolved brightness, not enum equality.
- `lib/themes/theme_switcher_button.dart`: cycles `ThemeMode.light` → `dark` → `system`; change to dedicated three-mode type without altering skin. Ensure icon colors use semantic on-surface role, including Classic.
- `lib/widgets/settings_sheet.dart`: settings currently show custom font but no full Appearance section. Add a dedicated child component rather than expanding this already-large sheet.
- `lib/screens/edit_line/parts/edit_line_original_section.dart`, `edit_line_edited_text_section.dart`, `lib/screens/edit_line/widgets/edit_text_field.dart`: source/target field containers use `colorScheme.primary` as background; hard-coded white input text, faint white labels and unrelated orange/turquoise action/border accents. These must migrate to reusable semantic editing fields.
- CP85 R5 stable `EditScreenHost` / `EditSubtitleScreenHost` provider scopes and guarded navigation must be preserved. Skin/mode changes should trigger only visual rebuilds, **never** recreating session controllers.
- Existing settings widgets contain additional hard-coded colors. Migrate incrementally after first pilot, not via broad replace.

## Architecture and data contracts

### Domain types

```dart
enum StudioSkin { carbonJade, copperCinema, asterViolet } // built-in presets
enum StudioAppearance { light, dark, classic }

// Value-object identity, NOT an enum: built-in + community.<opaque-id>.
class StudioAppearanceSelection {
  final StudioSkinId skin;
  final StudioAppearance mode;
  const StudioAppearanceSelection({required this.skin, required this.mode});
}
```

Persist the **namespaced `StudioSkinId.value` string** (`builtin.carbonJade`, `builtin.copperCinema`, `builtin.asterViolet`, `community.<opaque-id>`), never an enum ordinal or display name. Legacy built-in identifiers (`carbonJade`, etc.) remain parseable. Missing imported skins fall back safely to Carbon & Jade **with a future user-visible explanation** while retaining the unrecognized ID for relinking.

**Open-source extensibility (SKIN-EXT):** `StudioSkinDefinition` contains data-only Light/Dark/Classic palettes, `StudioSkinCatalog` registers built-ins + validated community definitions, and `StudioThemeFactory.fromPalette` renders all skins through one factory. File contract: [community skin v1 specification](COMMUNITY_SKIN_FORMAT_V1.md) and [machine-readable JSON Schema](../../schemas/subtitlestudio-skin-v1.schema.json). The importer/website are later milestones, not enabled by SKIN-1.

### Shared theme resolver

```dart
// All skins, including future imported ones, feed the same renderer.
ThemeData StudioThemeFactory.fromPalette(
  StudioPalette palette, {
  String? fontFamily,
});

// Built-ins retain a convenience factory:
ThemeData StudioThemeFactory.resolve(
  StudioSkin builtInSkin,
  StudioAppearance mode, {
  String? fontFamily,
});
```

The future injected catalog resolves `StudioSkinId` to `StudioSkinDefinition` then `StudioPalette`. Make a single factory build `ThemeData` from palette data and `StudioDesignTokens`; share component/theme typography and spacing. Do **not** keep a separate `ThemeData` implementation per combination. Define all 9 palette **data** combinations and test exhaustive resolution; cache pure theme data when practical, while custom-font overrides remain safe.

Semantic roles at minimum:
- canvas, surface, raisedSurface, fieldSurface, onSurface, mutedText;
- divider, fieldBorder, focusBorder, selection, caret;
- primaryAction, onPrimaryAction, editingAccent, onEditingAccent;
- warning/onWarning, error/onError, success/onSuccess;
- selectedCue, timeField, waveform (separate channel/peak/playhead semantics);
- history node/current/alternate-lane roles with non-color indicators;
- disabled, hovered, pressed, focused states; appBar and system status/nav bar icons.

`StudioDesignTokens` is extended backward-compatibly with corresponding constructors/`copyWith`/`lerp`. Existing users and legacy screens should continue to render during migration. Restrict special colors to functional roles.

### Independent persisted settings — recommended approach

**Recommended canonical solution:** retain `Preferences.themeMode` as the mode field and add a new nullable **namespaced `String? Preferences.skinId`** field to the **same existing Isar Preferences collection**, accessed **only** via `PreferencesStore` / `ThemePreferencesRepository`. This gives two genuinely independent persisted values without fragmenting preferences into Isar and SharedPreferences. It requires one isolated Isar schema/code-generation change. Do **not** change subtitle collection/checkpoint schemas or project documents.

Implementation gate:
1. Confirm compatibility and generated `models.g.dart` output with the pinned `isar_community` generator. If generation isn't possible in the execution environment, use the normal local build_runner process and obtain/verify the generated file rather than manually editing it.
2. Add regression tests opening an existing database fixture and validating old preferences survive and the new nullable field defaults gracefully; no unexpected database reset/duplicate Preferences singleton.
3. Test persisted independent changes and process restart, concurrent saves, invalid values, and undoing partial/mid-write errors.
4. Existing saved mode strings `light`, `dark`, `classic` remain valid; do not silently overwrite them. The **new-install** proposed first-run default is Carbon & Jade/Dark. Existing users whose mode is saved retain that mode and gain the default skin; decide behavior for legacy null-mode records explicitly before migration (old behavior treated null as Classic).
5. Do not mix schema changes with new UI widgets or native media changes in one commit. If a schema migration proves risky, pause and review an alternate two-key preferences store strategy rather than introducing ad hoc storage.

### Initialization/race safety

`ThemeController.build()` currently returns a fallback state and starts an unawaited async preference load. Design a guarded initialization path (prefer a single state snapshot after both skin+mode+font load) so selecting a skin before load completes cannot be overwritten by stale data, and the UI does not briefly flash a different visual skin. Provide an error/fallback state if a persisted custom font cannot be loaded. Preserve `skin`, `mode` on set/remove-custom-font. Persist each setting independently through the same injected repository and serialize concurrent writes appropriately.

### UX behavior

- Settings → Appearance: 3 skin preview cards/tiles (name and small 3-mode swatches), segmented Light / Dark / Classic, current selection and mini live preview of Original/Edited fields. Native touch targets and accessible controls.
- Home/Editor theme button: cycle **Light → Dark → Classic** for the selected skin only; do not change skin; tooltip states current mode and next action. Appearance Settings is the place to switch skins.
- Prefer preview-first behavior that keeps the current editor session mounted; never remount MaterialApp by changing its key or route host keys.
- Custom font controls remain independent. If preview can be canceled, draft state must not overwrite persisted selection until Apply; otherwise provide instant apply with accessible feedback and reliable persistence.
- System-following appearance is **not** one of these three modes. Flutter `ThemeMode.system` must not represent Classic; optional Follow System is a separate future requirement if desired.

## Sequenced work packages and gates

| Milestone | Deliverable | Gate |
|---|---|---|
| SKIN-0 **approved** | Decision record, palette definitions, roadmap and source audit | This document and roadmap links committed; no production theme changes |
| SKIN-1 **COMPLETE** | Typed enums, nine pure `StudioPalette` variants, factory, distinct Dark/Classic schemes, extended semantic tokens and read-only preview gallery | Successful CI R2, 392 passing tests, analyzer clean; all nine contrast and narrow gallery tests passing; factory not yet activated |
| SKIN-2 | Independent skin/mode Isar persistence, migrated `ThemeController`, startup/loading concurrency and custom-font safety | Isar generated code verified; old DB compatibility; restart tests; old mode retained; no route/controller disposal |
| SKIN-3 | Appearance Settings previews, mode cycle button, system bar/nav styling | Widget tests: select 3 skins × 3 modes, persist, switch/reopen, keyboard navigation, labels, font retention |
| SKIN-4 | Semantic `StudioCueField`/`StudioTimeField` and targeted Edit Line pilot (source/edited and time fields) | Android physical testing all modes; unsaved text and cursor/IME/undo retain state; Malayalam, Arabic/RTL, large fonts |
| SKIN-5 | Incremental migration: Home, Editor/toolbars, Project Settings, history, Source View, import/export, sheets, waveform visuals | Per-screen audit and tests; semantic warnings and graph lane distinction retained; dark/classic screenshots |
| SKIN-6 | QA and stabilization; theme goldens, accessibility, performance and platform smoke | Contrast/focus/selection/disabled checks; Android+Windows verification, analyzer/tests; final 5-platform gate at integration PR |

Do not advance SKIN-4 until SKIN-1–3 and Editor lifecycle tests are green. Keep visual migration separate from CP86 waveform native decoding/sync changes. CI analyzer/tests at deliberately grouped changes (~8–10 commits or meaningful risk gate), not per routine commit; real Android/Windows verification is required before marking a visual milestone complete.

## Test matrix — acceptance criteria

| Scenario | Expectation |
|---|---|
| Select all skins and all modes | 9 distinct, stable theme combinations share component geometry |
| Restart after skin selection | Same skin and same independent mode |
| Toggle only mode | Skin remains unchanged |
| Toggle only skin | Mode remains unchanged |
| Legacy saved `light`/`dark`/`classic` | Preserved exactly; missing skin defaults Carbon & Jade |
| Fresh install | Proposed Carbon & Jade/Dark (do not conflate this with upgrade migration) |
| Custom font add/remove/fail | Skin and mode unchanged; readable fallback |
| Android theme/skin change in Editor and Edit Line | No loading reset, crash, disposed ref or video restart |
| Text typed before theme change | Exact text, selection, undo history, focus and keyboard preserved |
| Subtitles with Malayalam, Arabic, emoji and long lines | No invisible text, clipping, bidi corruption or layout overflow |
| Classic dark system chrome | Proper icon/status/navigation bar contrast; no light-mode assumption |
| Accessibility | 200% text scale, screen reader semantics, non-color status, >=48dp important touch actions |
| Isar upgrade | Old projects/checkpoints unaffected; generated schema consistent and restore works |

## Community extensibility — required future milestones

- **SKIN-EXT-1:** typed namespaced skin IDs, immutable definitions/catalog, shared data-only renderer, portable JSON v1 codec, validation and public schema. Code implementation precedes SKIN-2 so the database stores a generic string instead of an enum.\n- **SKIN-EXT-2:** local preview/import/export on Android/desktop, safe app-owned storage, duplicate-ID collision handling, missing-file fallback and accessibility tests.\n- **SKIN-EXT-3:** open-source, client-side web Skin Creator for editing the 12 semantic color roles across all three modes, live Editor preview, contrast help, schema validation and portable export. No account/backend required for v1.\n- **SKIN-EXT-4:** optional future advanced customizations subject to security, accessibility and user testing. Executable code or arbitrary CSS/HTML is not in v1.\n\nFull spec: [Community skin format and creator roadmap](COMMUNITY_SKIN_FORMAT_V1.md).\n\n## Out of scope

- A fourth **bundled** skin is not planned. Community-created skins and local imports **are supported architectural requirements**, implemented later in SKIN-EXT-2, while the v1 format supports custom semantic colors.
- Automated skin changes based on time of day.
- A fourth `Follow System` mode (can be proposed separately).
- Desktop-specific shell redesign or storage rewrite.
- Waveform decode/native player modifications within skin commits.
- Editing/project/checkpoint schema changes; skin persistence is global application preferences only.

**Approved selection: all three skins. First preferred preview: Carbon & Jade / Dark. SKIN-1 foundational Dart code is now committed and CI verified, but the production `MainApp`, controller, saved preferences and Edit Line fields are still unchanged. Next implementation milestone: SKIN-2 persistence/controller migration.**
