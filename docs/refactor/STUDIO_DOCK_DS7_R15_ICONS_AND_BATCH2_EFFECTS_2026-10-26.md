# DS7 R15 — Dictionary/toolbar SVGs and SRT effect batch 2 (2026-10-26)

Branch: `feature/studio-dock-integration` in fork `anzilr/SubtitleStudio`.

## What changed

- Added the five user-provided SVG assets unchanged: Olam (`ഓ`), Urban
  Dictionary (`ud`), Project Settings (folder/gear), and vertical waveform
  amplitude increase/decrease. Shared `StudioAssetIcon` uses a theme-aware
  tint with a supplied size; the assets remain Flutter package assets.
- Updated dictionary entry points in mobile line editing and desktop rail,
  desktop Tools popup, both dictionary sheet headers, project-settings
  menus/headers, and waveform full and compact vertical controls. App-level
  Settings remains distinct from Project Settings.
- Changed oversized legacy Karaoke/Typewriter cards into the same compact
  `ChoiceChip` selector used by the other effects. All eleven current effects
  appear in one responsive wrap in the shared Add Effects sheet.
- Added Batch 2: Blink/Flash (alternating visible and blank cues), Rainbow
  Text (phase-shifted color tags on complete Unicode graphemes), and
  Scramble Reveal (changing placeholder symbols replaced by original
  graphemes). Only SRT-compatible timed cues and `<font color>` tags are
  generated. Preview uses the same frame builder as export.
- Expanded Studio Dock's read-only recognition/folding for all three kinds.
  The existing `StudioDockEffectMarks` group/individual behavior and marked
  lines review projection apply to Batch 2 groups without further migration.
- Rejected too-short effects with no useful visible frames. Long final cue
  holds up to 1 second are included in folding tolerance. Scramble skips
  no-op whitespace reveals to keep consecutive frame recognition intact.

## Validation

- Unit/widget tests exercise preview picker choices, SVG asset loading,
  grapheme-safe frame generation, blink alternation, rainbow tags, scramble
  progression, timed cue export with end hold, and collapse detection.
- Final pushed source revision `de336ae31a778717a9c0546530eb72bcbf7e77e2`
  passed both GitHub Actions workflows: **Flutter analyze 0 issues**;
  **373 Studio Dock tests** and **1,217 full Flutter tests** passed.
  No platform builds were run in GitHub Actions.
- CI found desktop Tools menu Row overflows when dictionary SVGs were added.
  Dictionary labels now use a bounded, ellipsized flexible text widget;
  the fully passing rerun includes desktop menu regression tests.

## Next checkpoint

- Native visual verification (Android/Windows) for the five actual SVGs,
  all eleven picker choices, and end-to-end generated SRT effects.
- Maintain mobile/desktop functional parity as Studio Dock continues.
- Keep the current collapsed-mark semantics: a collapsed effect toggles
  all persisted cues; an expanded frame only toggles itself; marked-lines
  review must reflect those same real cue IDs.
