# SubtitleStudio UX-1 — shared design foundation (implementation pending verification)

Date: 2026-10-16
Branch: `refactor/riverpod-architecture`
Scope: low-risk opt-in design foundations; no redesign of Editor, Edit Line, waveform, history or database.

## Implementation

- `lib/themes/studio_design_tokens.dart` defines `StudioDesignTokens` as a Flutter `ThemeExtension`, covering light/dark/legacy Classic schemes with shared semantic roles for surfaces, text, active actions, editable cues, warning states and alternate history paths.
- Tokens include `copyWith` and `lerp` so widget theme animations remain supported; compact spacing, radii and minimum action-size constants establish a common layout rhythm.
- `AppThemes.lightTheme`, `AppThemes.darkTheme`, and `AppThemes.classicTheme` register these new extensions. Their **existing** `ColorScheme`, typography, saved modes, fonts and general app styling are not changed yet.
- `lib/themes/studio_components.dart` introduces `StudioSurface` (a proper Material surface, no decorated ink obstruction), `StudioSectionHeader`, `StudioPrimaryAction`, and `StudioStatusMessage`.
- `lib/widgets/project_settings/project_encoding_selector.dart` is the first migrated pilot. It retains searchable list integration, runtime options, selected-value preservation, busy/loading states, and error guidance; visual chrome now comes from reusable Studio tokens and components.

## Proposed visual palette

- Light: canvas `#F6F8FC`, surfaces white, primary action `#5268D9` (white foreground), text `#17223B`, muted `#66728D`, editing accent `#14796F` (white foreground).
- Dark/Classic pilot: canvas `#111A2C`, surface `#19243A`, primary action `#A9B6FF` (dark foreground), text `#EEF2FA`, muted `#B5C0D8`, editing accent `#62DBCA`.
- Semantic amber caution roles, alternate history path colors, and Material error palette for actionable error text.
- Palette is a **pilot**; user screenshot review can refine visual feel before large-scale adoption.

## Tests added

`test/studio_design_system_test.dart` covers:
- Presence and 4.5:1 contrast of action/editing/surface/muted text pairs across light/dark/Classic.
- ThemeExtension interpolation and copy behavior.
- Primary action callback, button minimum touch size and textual status indicator.
- Narrow Android-width dark-mode rendering of the Project Settings encoding pilot.

Previous `test/project_settings_encoding_selector_test.dart` remains relevant for search, selection, unsupported source encodings and loading/saving guards.

## Safety and limits

- No Isar schema changes, persistence code modifications, video player ownership changes, history logic changes, new dependencies, desktop workspace or release/main branch modifications.
- New tokens are registered across all themes but **do not** automatically recolor non-migrated legacy widgets; app-wide uniformity is an incremental roadmap goal.
- No real Android or Windows widget-rendering evidence for this stage yet. The code was source-reviewed; a Flutter analyzer/test/device gate is required.
- Do not trigger the five-platform build matrix for this change. Preserve deliberate analyzer/test CI cadence (every ~8–10 meaningful commits).

## Verify on local Flutter installation

```powershell
git fetch origin refactor/riverpod-architecture
git merge --ff-only FETCH_HEAD
flutter analyze
flutter test test/studio_design_system_test.dart
flutter test test/project_settings_encoding_selector_test.dart
flutter run -d d6e22c3f --debug
```

On Android, open an SRT project, open Project Settings and inspect Character Encoding. Test search, choose a supported legacy encoding, reopen and confirm selection. Check dark/light/Classic themes, small viewport, long encoding names and unsupported saved values. Confirm the Edit Line save/navigation and video fullscreen comment scenarios remain unchanged.

## Follow-up implementation sequence

1. Stabilize UX-1 gate and fix any analyzer/test/device observations.
2. UX-2: add a **central history-copy catalogue** and migrate buttons, messages and Help to plain user terms; preserve internal git-like identifiers/actions and retention semantics.
3. UX-3: pure graph-lane geometry and history timeline/map renderer with lazy rows, accessibility and large-history tests.
4. UX-4: compact portrait Edit Line pilot after tokens are validated; keep playback and data state owners unchanged.
5. UX-5: migrate Home, Editor, tools, import/export and Source View to new components one screen at a time, with screenshot/golden tests.
