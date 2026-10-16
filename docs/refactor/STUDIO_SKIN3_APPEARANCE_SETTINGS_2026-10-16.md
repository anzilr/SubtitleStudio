# SubtitleStudio — SKIN-3 Appearance Settings

Date: 2026-10-16
Branch: `refactor/riverpod-architecture`
Status: **SKIN-3 R1 COMPLETE — committed and Flutter CI verified**
Quality gate: https://github.com/anzilr/SubtitleStudio/actions/runs/38872349945 — **418 passing tests; analyzer step successful**, verified code commit `06eb58421757c883b9bea01b0f0297cb1125b25d`.

## Implementation

- `lib/themes/studio_appearance_settings.dart`: new independent Appearance Settings section. It displays Light / Dark / Classic as one segmented selector; 3 built-in skin cards with three thumbnail variants each; current selection indicator; a local, theme-scoped Edit Line visual preview (English and Malayalam text); and reserved **My skins** section for future community installation.
- `lib/themes/studio_skin_catalog_provider.dart`: an injectable Riverpod provider wrapping the existing immutable built-in/community skin catalog. Future `SKIN-EXT-2` can replace its implementation without rewriting the Appearance UI.
- `lib/themes/studio_skin_preview.dart`: one shared palette thumbnail renderer for both bundled and community definitions. The existing SKIN-1 read-only gallery API is retained.
- `lib/widgets/settings_sheet.dart`: Appearance Settings is visible near the top of the pre-existing settings sheet, above unrelated settings and font controls. Existing options and editor routes are untouched.
- `lib/themes/theme_switcher_button.dart`: toolbar mode switch uses typed `StudioAppearance` (Light → Dark → Classic → Light), preserves selected skin, removes hard-coded white Classic icon, exposes the current mode in the tooltip and reports a failed save.
- `test/studio_appearance_settings_test.dart`: narrow-screen sizing, nine built-in previews, independent persistent choices, all modes, community definitions through injected provider, unavailable skin ID preservation, failure rollback/snackbar and toolbar mode cycling.

## Key honesty/safety boundary

**SKIN-3 is not app-wide palette activation.** Switching Light / Dark / Classic changes the existing legacy app appearance and saves the mode; selecting Carbon & Jade / Copper Cinema / Aster Violet **persists the skin ID and changes only the preview**. The screen expressly states this. Applying the skin palette to the actual Editor and Edit Line comes **after SKIN-4 neutral text field redesign**. That prevents regression of unreadable text currently forced white on `colorScheme.primary` backgrounds.

The preview is scoped using `Theme(data: StudioThemeFactory.fromDefinition(...))`, never a new `MaterialApp`, Navigator, or Editor provider scope. The parent route and unsaved editor state are not reset by the preview itself. No project/checkpoint changes, Isar code generation, native libraries, platform build or remote import added.

## Community skins

A runtime-injected catalog may include validated community skins already in memory; the same tiles/rendering and IDs work. The normal app catalog currently contains only the three built-in skins. Native file import, install/remove/export and the website remain **SKIN-EXT-2/3**, not implemented here.

## QA status and next steps

- [x] UI widgets and Settings integration committed.
- [x] Widget regression test coverage added.
- [x] GitHub Flutter analyzer and full test gate green (418 tests).
- [ ] Physical Android/Windows visual review at release-integration gate.
- [ ] SKIN-4: reusable accessible Original/Edited/Time fields; then enable the new skin resolver globally.
- [ ] SKIN-5/6: remaining screens, accessibility, full-platform smoke and device safety.
- [ ] SKIN-EXT-2/3: native community importer and client-side Skin Creator.
- [ ] CP86: waveform native qualification remains a separate technical workstream.
