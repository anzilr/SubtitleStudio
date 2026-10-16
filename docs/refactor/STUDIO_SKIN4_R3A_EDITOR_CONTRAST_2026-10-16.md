# SubtitleStudio — SKIN-4 R3-A Editor and menu contrast migration

Date: 2026-10-16
Branch: `refactor/riverpod-architecture`
Status: **Implementation committed; Flutter CI pending**
Quality gate: https://github.com/anzilr/SubtitleStudio/actions/runs/38894453717

## Scope of this implementation

This is a carefully scoped production UI migration following the verified [DESIGN-1 shared component themes](STUDIO_COMPONENT_SYSTEM_2026-10-16.md) and [SKIN-4 R2 input readability pilot](STUDIO_SKIN4_CUE_FIELD_PILOT_2026-10-16.md).

1. **Shared semantic popup item:** `lib/themes/studio_menu_item.dart` provides `StudioMenuItemContent` and explicit normal/destructive/muted roles. Item shapes, label typography, foregrounds and icon backgrounds are the same across Editor and Edit Line. Menus retain their exact `value` strings, parent PopupMenuItem ownership, selection callbacks, conditional entries, dividers and keyboard/menu behavior.
2. **Editor menu:** `lib/screens/edit/widgets/edit_main_menu.dart` now uses the shared row for timeline/source/selection menus and inherits central popup radius/elevation/surface from `ThemeData.popupMenuTheme`, not a local popup styling override. The `delete` choice is destructive; unrelated actions are not multi-colored badges.
3. **Edit Line menu:** `lib/screens/edit_line/widgets/edit_line_menu.dart` uses the same popup contract for Settings, video, secondary subtitles, navigation, history, mark, help and Delete; only Delete uses the danger role.
4. **Subtitle card:** `lib/screens/edit/widgets/subtitle_card.dart` uses `StudioDesignTokens` for selected/active card surface, cue text, timestamp/index metadata, mark indicators and selected icon. Removes formerly fixed background teal, blue, white, orange and gray choices that did not work consistently with all skins. Left/right swipe actions keep their original behavior and callbacks.
5. **Formatting popup/clear formatting:** `lib/widgets/formatting_menu.dart` menu radius/icon colors and confirmation sheet now inherit semantic roles and the shared bottom-sheet radius. Actual edited subtitle colors and the color-picker's initial white **remain subtitle content data**, not app component accent styles. `Clear All` retains its existing formatting-removal action; its destructive button uses `error`/`onError`.
6. **Unsaved changes:** `lib/widgets/unsaved_changes_sheet.dart` uses the shared primary and text-button designs, consistent spacing and semantic warning for Discard. Save/Discard Navigator/callback behavior is unchanged.
7. **Edit Line app bar/dictionary popup:** `lib/screens/edit_line/parts/edit_line_layout.dart` inherits app bar foreground and popup colors. Removed the white-only back/title/icon rendering and local dictionary-popup shape; retains dictionary commands, SVG and other click handlers.
8. **Regression coverage:** `test/studio_editor_skin_contrast_test.dart` exercises all 3 skins × Light/Dark/Classic for subtitle card foreground/card selection and menu semantic icons, and checks Editor/Edit Line popup value round trips and Save/Discard callbacks.

No changes to Isar schemas, waveform/player, subtitle parsing/encoding, native platform code, checkpoint graph or default/upstream branches.

## Activation gate: still pending

This R3-A subcheckpoint is **not** equivalent to activating `StudioThemeFactory` globally. As of this checkpoint, `ThemeState.themeData` continues to use the legacy `AppThemes`; the Appearance Settings sheet saves a skin preference and previews it without changing Editor route colors. This is intentional while remaining contrast-critical screens use local hard-coded colors.

### Remaining R3-B before global activation

- Migrate confirmation and selection sheets in `lib/screens/edit/widgets/edit_selection_dialogs.dart`, `lib/widgets/delete_confirmation_sheet.dart`, `lib/widgets/project_settings_sheet.dart` and remaining Edit Line dialogs into the shared modal/confirmation contract.
- Audit Editor and Edit Line toolbar, popup dictionary items, source/timeline controls and additional video/overlay actions for fixed colors or foreground/background combinations that can hide text.
- Validate meaningful editor selection and disabled/focus/error states at all nine appearances, including high-contrast Classic; preserve subtitle *content* colors.
- Connect selected `StudioSkinId` + `StudioAppearance` to `StudioSkinCatalog` → `StudioThemeFactory.fromDefinition` and retain unresolved community IDs; do not rebuild the Navigator or lose media/player/editor providers on changes.
- Test behavior when toggling modes/skins while edited text, IME composition, selection, UndoHistoryController and time fields are active.
- Validate physical Android and Windows screen layout, RTL/Malayalam, old on-disk Isar DB upgrade and desktop keyboard/mouse before release.
- Continue DESIGN-2 remaining custom components and DESIGN-3 visual accessibility gate; CP86 native waveform qualification remains a separate technical milestone.

**Quality claims:** use exact GitHub CI output. Do not claim global palette activation or physical-device testing at this stage.
