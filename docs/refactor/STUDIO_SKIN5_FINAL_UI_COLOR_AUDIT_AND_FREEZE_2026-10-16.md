# SubtitleStudio — Final UI fixed-color audit and appearance pause

**Date:** October 16, 2026  
**Scope:** `anzilr/SubtitleStudio`, `refactor/riverpod-architecture` only  
**Baseline:** R8 [469 Flutter tests and zero analyzer issues](https://github.com/anzilr/SubtitleStudio/actions/runs/38926044286)  
**Verification:** [GitHub Actions 38933989670](https://github.com/anzilr/SubtitleStudio/actions/runs/38933989670) **completed successfully — 470 Flutter tests passed, 0 analyzer issues**, verified code commit `5068731f7e1d6b988b950da5b3cd3b6fbbb4c2e0`.

## Purpose and scan

User requested one last app-wide inspection and repair of UI colors overriding selected skins, then a pause on theme work so technical roadmap items can proceed.

Reviewed roughly **203 UI-facing Dart files** under `lib/screens/`, `lib/widgets/`, `lib/themes/`, waveform UI, AI visual components and application boot UI, inspecting direct `Colors.<name>`, `Color(0x...)`, ARGB and theme-derived color sites. This is a source audit; it is **not** a claim that every combination was visually observed on native Android, Windows or other platforms.

Changed **more than 50 UI-facing source files** across multiple focused commits. No changes to the Isar schema, checkpoint serialization, user subtitle color tags, Media Kit decoder, plugin dependencies or upstream/release branches.

## Migrated surfaces

- **Editors and Home:** empty subtitle states, floating transport baseline retained from R8, Home session badges, common button grid, source-project dialog accents, new-file/merge/split confirmation, rename/search UI.
- **Comments and history:** Marked Lines semantic styling already in R8, Comment Dialog, checkpoint-history legacy dialog and branch node status, search/replace hits/buttons, comment import, warning/confirm actions.
- **Dictionary, AI, logs and feedback:** dictionary search form/error/status/result backgrounds and icons; Olam/Urban dictionaries; AI explanation inputs/buttons/loading/error states; feedback categories/messages and log manager confirmation/status semantics.
- **Tools and files:** subtitle creation, import/export, extraction, synchronization, Malayalam normalization, file replacement, Locate SRT, project/session selection, secondary subtitle sheet, first-run help and source/plugin utilities.
- **Waveform:** no forced blue/dark-only empty/loading/error surfaces; waveform errors and playhead follow semantic roles; edit/add selection/highlight/drag-bar colors in production painter derive from injected skin colors instead of orange/green/teal constants. Waveform toolbar was already made scrollable in R8.
- **Media controls:** video seek progress active/hover accents and settings highlights use the active theme. Overlay backgrounds and caption text directly over moving footage stay black/white for guaranteed visibility independent of skin.
- **Common UI:** base loaders, status, splash progress accent, color picker action highlight, Settings/reset warnings and danger actions use `Theme.of(context).colorScheme` or existing Studio semantic tokens.

### Semantic contract

- Action and selected affordance: `ColorScheme.primary`, contrasted by `onPrimary`.
- Secondary semantic category: `secondary/onSecondary`.
- Warning/review: `tertiary/onTertiary`.
- Destructive/error: `error/onError`.
- Text/outline/field: `onSurface/onSurfaceVariant`, `surfaceContainerLow/High`, `outline/outlineVariant`.
- Brand skins remain data-driven: Carbon Zero, Carbon & Jade, Copper Cinema and Aster Violet, each Light/Dark/Classic, all sharing identical component behavior.

## Legitimate fixed-color and non-theme exceptions

These are **not** alternate app theme palettes and must not be indiscriminately replaced:

1. **Subtitle content paint:** explicit SRT/ASS-like color tags, editable picker values, karaoke/highlight selections, and text/background colors authored into subtitle files must remain as authored.
2. **Video-composited text and controls:** white subtitles with black shadow/backdrop, black gradient scrims, media overlay volume/transport whites and black contrast surfaces are intentional visibility elements on arbitrary footage, which can be bright or dark regardless of the app's selected skin.
3. **Splash media/artwork:** white branding over a fixed dark splash graphic and dimming overlay remains a designed image composition. The animated progress accent uses the skin.
4. **Shadows, alpha-only scrims and color swatches:** neutral drop shadows and transparency have non-brand visual roles; theme preview swatches are actual palette values by definition.
5. **WaveformPainter constructor fallbacks:** retained to protect standalone/legacy/test painter callers that construct without Flutter `BuildContext`; all production editor painters explicitly supply skin-derived waveform, subtitle, playhead and highlight colors. The legacy no-theme fallback is not a user-selectable appearance.

Fixed status/error/primary decoration is forbidden in migrated normal UI. The new `test/studio_ui_color_freeze_test.dart` covers **31 identified surfaces** against reintroduction of legacy fixed blue, red, orange, purple and teal accents. Existing 12-theme controls tests and widget tests remain part of CI.

## Remaining acceptance/risk

- Final Flutter analyzer, 470-test suite and 31-surface static color guard **passed** in CI. They do not replace physical visual review on 360dp Android, landscape and Windows.
- Semantic color use does not guarantee every status color pair meets enhanced contrast with *custom future imported skins*; the importer must validate v1 token contrasts.
- Some older feature widgets may still use intentional fixed foregrounds; future bug reports should be corrected specifically, but broad appearance migrations **pause** after this gate.
- Android Flutter logs warned that the existing Gradle 8.14.0, AGP 8.13.0 and Kotlin 2.2.20 will need eventual isolated toolchain modernization. Do not force an untested native upgrade within a UI refactor.

## Pivot: next technical workstream

**Checkpoint 86 / Waveform native qualification**, independent of further theme design:

1. On **Android**, test existing large MKV + SAF `content://` session through initial decode, compact peak cache reopening, seek, playhead/scroll, explicit vs Auto audio track, stream changes and cancel/reload/disposal. Check bounded peak/tile memory and stale callback guards.
2. Capture debug **and profile** performance baselines, wall clock, memory, jitter, cache integrity and UI response; assess native FFmpeg stream identity and cancellation. Do not infer Windows performance from Android or Linux CI.
3. On **Windows**, validate path-based file open, ffmpeg track mapping, waveform peak pipeline, normal/replaced files and restart; keep source-tree dependency/platform updates separate.
4. Add focused regression tests for identified native equivalence bugs; keep cancellation/provider lifecycle fixes retained. Do not accidentally restore eager full-length PCM allocation on Android.
5. Following CP86: remaining typed file identity/SAF consolidation and injected persistence, project/checkpoint store ownership, Editor controller decomposition, logging/performance, and isolated platform toolchain upgrades. History UX, compact Edit Line and community-skin creator remain on UX backlog but are **not** the next workstream.

**Appearance freeze policy (in effect after successful CI):** no new skin features or broad UI recolors during the technical checkpoints; fix only reproduced contrast, accessibility, or regression defects. No upstream merge/release sign-off until native Android/Windows and historical Isar data-compatibility acceptance.

## Final gate corrections

The first guard run found a lone hardcoded orange repeat-mode icon in fullscreen controls; switched it to the selected skin's primary role. The subsequent analyzer gate identified a `const SizedBox` wrapping a runtime theme color in subtitle extraction; removed the invalid `const` and changed the primary action icon's foreground from `onSurface` to `onPrimary`. [Final Actions run 38933989670](https://github.com/anzilr/SubtitleStudio/actions/runs/38933989670) then passed the analyzer and all **470 tests**. These corrections were necessary to ship the freeze in a green state. They do not constitute a native Android/Windows acceptance test.
