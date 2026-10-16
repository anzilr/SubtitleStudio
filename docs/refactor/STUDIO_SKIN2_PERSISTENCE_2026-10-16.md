# SubtitleStudio — SKIN-2 R2 independent appearance persistence

Date: 2026-10-16
Branch: `refactor/riverpod-architecture`
Status: **IMPLEMENTED; R2 verification in progress**
R1 verified: [GitHub Actions 38870334769](https://github.com/anzilr/SubtitleStudio/actions/runs/38870334769) — 409 tests passed, analyzer 0 issues.
R2 quality gate: https://github.com/anzilr/SubtitleStudio/actions/runs/38870812828 (pending)
Prerequisite: [SKIN-1 R2 + community skin SKIN-EXT-1](STUDIO_SKINS_IMPLEMENTATION_PLAN_2026-10-16.md)

## Implemented

1. **Isar Preferences schema**: added optional `String? skinId` to existing Preferences record in `lib/database/models/models.dart`, leaving all unrelated records and collection definitions intact. This stores `builtin.carbonJade`, `builtin.copperCinema`, `builtin.asterViolet` or future `community.*` IDs. `themeMode` remains an independent string field with unchanged `light/dark/classic` wire values. **No enum ordinal is persisted.**
2. **Generated schema**: Used the pinned Flutter 3.47.5 / `isar_community_generator` workflow rather than manually editing `models.g.dart`. Verified [schema code generation run 38869796258](https://github.com/anzilr/SubtitleStudio/actions/runs/38869796258); bot commit `0d0c19a` updated `lib/database/models/models.g.dart` only. The workflow also verified `HistoryRefSchema` survived.
3. **Repository snapshot**: `ThemePreferencesRepository` implements small injectable `ThemePreferencesStore`, loads both skin and mode plus font metadata in one read and saves the skin and mode in separate atomic `PreferencesStore.update` transactions.
4. **Controller state**: `ThemeState` now stores `StudioSkinId` and `StudioAppearance` independently. `ThemeController.setSkin` and `setAppearance` update one choice without resetting the other or the custom font. `setTheme(ThemeMode)` and `themeMode` remain compatibility adapters for existing UI; **Classic is not represented by a Flutter ThemeMode internally**.
5. **Safe startup**: hydration of a saved snapshot is guarded per preference dimension by revision counters. A new user choice made while the async startup read/font loading is pending wins over a stale snapshot, even when the chosen value happens to equal the temporary startup fallback. Snapshot read failures keep a safe fallback state.
6. **Rapid tap safety**: queued writes per field prevent slow earlier persistence calls from overwriting more recent skin/mode selections. Failed writes propagate and roll back only if they are still the latest revision.
7. **Fresh/legacy behavior**: a fresh Preferences-free installation resolves to `Carbon & Jade / Dark` in the typed state. A legacy existing Preferences record without `skinId` uses Carbon & Jade and **retains** its existing saved mode. A legacy row with null mode retains the previous Classic behavior. Unknown skin values fall back safely until community skins are installed.
8. **Font lifecycle**: replacing/removing a custom app font now preserves the skin and appearance. Native loading still happens through existing `FontLoader` behavior; no app font asset changes were introduced.
9. **System UI**: Android system/status/nav bar brightness now uses `appearance != light` so Classic receives appropriate dark-chrome icon contrast.

## Safety boundary

**This does not yet turn on the new skin palettes.** `ThemeState.themeData` still uses `AppThemes.lightTheme`, `darkTheme`, `classicTheme` until SKIN-4 replaces existing Edit Line and Editor white-on-primary input fields with semantically styled cue fields. `StudioThemeFactory` supports all built-in/community palettes and remains opt-in at this stage. `MaterialApp` route keys and Riverpod Editor/Edit Line controllers are untouched, and the UI currently has no skin picker (SKIN-3).

No subtitle records, projects, checkpoints, playback, waveform extraction, native platform build configuration, upstream or release tags were altered.

## Test coverage

- Real temporary Isar DB: old-format-style Preferences rows where `skinId == null`; intact `themeMode`, app font metadata, checkpoint preference, auto-save and row identity after setting skin.
- Empty DB snapshot performs no write.
- Concurrent skin and mode saves create one Preferences row; one dimension does not overwrite the other.
- Fake injectable repository: preserved old Light/Dark/Classic modes, fresh install defaults, custom font removal, legacy `setTheme` adapter, failed-save rollback, stale async startup race (different and same-as-fallback choices), ordered rapid mode switches.
- Prior Editor/Edit Line scoped-controller lifecycle widget tests and all existing integration tests run in the full CI suite.

**Not yet physically verified:** upgrading a historical real Android/Windows binary Isar database through the new generated schema (the current tests create legacy-shaped records under the new schema); Android/Windows full-app UX, custom font from real device, skin setting across process restart. These remain native qualification requirements before the new palettes can become default or the feature can be considered release-ready.

## Next steps

- **SKIN-3:** Add an accessible Appearance Settings component using the 3×3 preview gallery and independent skin/mode controls (including community-ID-aware catalog lookup). Provide a skin preview that doesn't reset Editor routes or affect autosave.
- **SKIN-4:** Fix Original/Edited/Time input readability, focus states, cursor/selection, and status/help copy first; then activate `StudioThemeFactory.fromDefinition` through the theme controller. Do not activate the new factory globally while legacy Edit Line text fields force white foreground on primary backgrounds.
- **SKIN-EXT-2/3:** App-side custom skin picker/storage and open-source web Skin Creator later; no importer or site exists in this checkpoint.
- **Checkpoint 86:** Real waveform native qualification remains independent.
