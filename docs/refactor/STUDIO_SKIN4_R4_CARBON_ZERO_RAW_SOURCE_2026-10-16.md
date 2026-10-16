# SubtitleStudio — SKIN-4 R4 Carbon Zero, raw Source View and fullscreen Settings

**Date:** 2026-10-16  
**Branch:** `refactor/riverpod-architecture`  
**Flutter quality gate:** [R4 run 38909487358](https://github.com/anzilr/SubtitleStudio/actions/runs/38909487358) (verification status to be confirmed after workflow completion).  
**Native Android/Windows acceptance:** NOT YET PERFORMED.

## Intent and behavior

1. **Restore raw Source View presentation.** Both embedded Editor Source View and standalone Source View use a single multiline `TextField`, rather than separate cue/index/timestamp GUI controls. Existing SRT cue numbering, timeline, and subtitle text appear in ordinary raw SRT syntax. Styling is theme-aware, not a new GUI layout. Raw source edits are not lost on an inherited theme rebuild. Embedded Source View validates the raw text using `RawSrtDocument.parseStrict` before database synchronization; a malformed or empty document fails closed rather than silently persisting stale entries. Standalone Source View retains the actual raw text and the existing original-encoding/SAF write workflow.
2. **New signature built-in Carbon Zero.** Adds `StudioSkin.carbonZero`, stable ID `builtin.carbonZero`, and three achromatic, WCAG-oriented palettes. Light has a pure white canvas, Classic a pure black canvas; Dark uses charcoal. All semantic palette roles, including danger/caution/success, are grayscale; icons and words rather than hue distinguish meaning. The previous Carbon & Jade, Copper Cinema and Aster Violet palettes remain selectable. Four built-ins × three appearances = 12 variants. Carbon Zero is used for fresh/unset/missing skin IDs, but explicit saved preferences are preserved, including existing built-in and unavailable community IDs.
3. **Settings fullscreen and Appearance collapsed.** Home settings button/shortcut, Editor settings, and Edit Line settings all request fullscreen square-corner sheets with safe area. Main `SettingsSheet` occupies 100% available modal height and keeps sticky version footer. The Appearance expansion starts closed; on expansion, it displays the complete live mode/skin picker once, without a duplicate heading. The settings controls previously using fixed bright blue/orange/green/red/purple accents now generally inherit selected skin semantic colors.
4. **Supporting Android log regression.** Uploaded Android 14 debug log on OnePlus CPH2381 contained a `RenderFlex overflowed by 219 pixels on the bottom` from `positioning_buttons_widget.dart:132` after IME activity. The positioning sheet now scrolls vertically and reduces narrow-screen horizontal insets. A widget test exercises a 360×640 viewport with keyboard inset. The log also repeated a `ListTile background color or ink splashes may be invisible` assertion without a precise widget location; record a fresh stack/screen reproduction if it still appears. Gradle/AGP/Kotlin minimum-version deprecation warnings did not prevent the attached debug APK from building.

## Regression checklist

- Both Source View entry points show **one unformatted raw text editing surface**, preserving multiline Malayalam, Arabic/RTL, and SRT tags. Test Save/Discard, invalid incomplete cue, typing and focus while changing skin. Validate data integrity after returning to timeline.
- Verify Carbon Zero defaults only for unselected skin preferences; previously explicitly selected skins persist. Compare Light, Dark, Classic, and the other three skins. Keep all app UI controls readable, including dangerous confirmation text and dimmed states.
- Settings opens fullscreen from Home, Editor, and Edit Line with keyboard open. Appearance starts folded, expands, and can change four skins × three appearances. Close/relaunch to check persistence.
- Verify positioning sheet at narrow portrait with soft keyboard: no vertical or horizontal overflow; still permits grid selection, removing tags, and applying.
- Monitor debug logs for ListTile Material/ink assertions, editor state/cursor resets, subtitle data changes, and media player churn.

## Out of scope

- No upstream/default branch or release tag mutation.
- No Isar schema regeneration, audio decoder, waveform signal-processing or online MSone submission changes.
- Native Android, Windows, and historical on-disk Isar upgrade acceptance remain user-operated checkpoints.
