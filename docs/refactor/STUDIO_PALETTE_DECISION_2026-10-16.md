# SubtitleStudio — Approved Three-Skin Palette Matrix

Date: 2026-10-16
Branch: `refactor/riverpod-architecture`
Decision: **APPROVED — include all three skins; each has Light / Dark / Classic (9 total)**. Production themes have **not yet been migrated**.
Preferred first preview: **Carbon & Jade / Dark**.
Implementation: [Three-skin appearance architecture plan](STUDIO_SKINS_IMPLEMENTATION_PLAN_2026-10-16.md).
Prerequisite: Checkpoint 85 R6 Android stability gate **reported complete by the user**. The last separately verified GitHub Actions code gate remains CP85 R5 (386 tests, 0 analyzer issues).
Related: [Refactor roadmap v4](REFACTOR_ROADMAP_V4.md), [Studio UX roadmap](SUBTITLESTUDIO_UX_ROADMAP_2026-10-16.md).

## Why a new palette needs an explicit gate

Review of `lib/themes/theme.dart`, `lib/themes/studio_design_tokens.dart`, and Edit Line parts revealed an architectural design issue: Edit Line source/target text containers use `Theme.of(context).colorScheme.primary` as the background, with hard-coded white foreground, faint semi-transparent white helper labels, turquoise borders, and orange copy/paste buttons. The shared `OptimizedTextField` repeats this pattern. Changing the accent without decoupling fields from primary buttons will make editing surfaces hard to read in either theme. Global theme defaults alone cannot fix all hard-coded widget colors.

Goals:
1. Bright, clean Light; readable charcoal-toned Dark; genuinely near-black high-contrast Classic.
2. Neutral elevated editor fields (not saturated action colors), with visible input boundaries and clearly labeled source/target text.
3. One theme-brand accent for primary actions, focus, active tools and progress. Functional warnings/errors use semantic tokens, not decorative rainbow sections.
4. Always define matched foreground for each background, caret/selection/focus/disabled states, keyboard and long/multilingual text behavior.
5. Use separate card divider and **input stroke** tokens; editable control outlines should be distinguishable at >=3:1 when relied on for boundary identification.
6. Do not use palette decisions as permission to change video/FFmpeg, Isar, checkpoints, controller ownership or text persistence.

## Skin A — Carbon & Jade (first preview: Dark)

| Role | Light | Dark | Classic |
| --- | --- | --- | --- |
| Canvas | #FFFFFF | #0E1517 | #050909 |
| Surface | #F7FBF9 | #182427 | #131B1A |
| Edit field | #F0F8F4 | #213135 | #1B2926 |
| Primary text | #192B25 | #F2F8F5 | #F5F8F3 |
| Muted text | #526960 | #B4C8C2 | #B6C8C1 |
| Action/focus | #0A7860 | #55E0BC | #56DEB6 |
| On action | #FFFFFF | #07281E | #07281E |
| Input stroke | #698A7D | #7A8E8B | #798E85 |

Intent: distinct fresh subtitle-editing identity, subtle green-charcoal neutrals, energetic mint accent without neon backgrounds.

## Skin B — Copper Cinema

| Role | Light | Dark | Classic |
| --- | --- | --- | --- |
| Canvas | #FFFEFC | #151414 | #090909 |
| Surface | #FFFFFF | #242020 | #1D1B19 |
| Edit field | #FFF8EF | #302826 | #27221D |
| Primary text | #2F2521 | #FFF4E8 | #FBF4E9 |
| Muted text | #69584D | #D6BFB1 | #D8C5B1 |
| Action/focus | #93601E | #FFBE78 | #F4B969 |
| On action | #FFFFFF | #322010 | #322010 |
| Input stroke | #A08570 | #9A8073 | #968271 |

Intent: cinematic, warm, professional, less like a generic productivity app. Risk: overly gold/brown if applied too broadly.

## Skin C — Aster Violet

| Role | Light | Dark | Classic |
| --- | --- | --- | --- |
| Canvas | #FFFEFF | #15121D | #08070B |
| Surface | #FFFFFF | #251F30 | #1A1721 |
| Edit field | #F7F1FC | #30273A | #251F2D |
| Primary text | #251B31 | #F8F2FC | #F8F3FF |
| Muted text | #6C597B | #CBBFD7 | #C7BFD2 |
| Action/focus | #7444AA | #D6ADFF | #C8A1FF |
| On action | #FFFFFF | #241332 | #21132C |
| Input stroke | #9479AB | #9885AD | #9985B0 |

Intent: creative workstation, distinct from navy/blue. Risk: purple-tinted surfaces may tire users during long subtitle sessions; restrained usage needed.

## Preliminary contrast calculation (WCAG relative luminance)

Measured pairs in the order Light / Dark / Classic. These are numerical prototype checks, **not** yet contrast certification for all interactive states, overlays or typography.

| Palette | Main text on field | Muted text on field | On-accent button | Input border vs field |
| --- | --- | --- | --- | --- |
| Carbon & Jade | 13.75 / 12.55 / 14.09 | 5.48 / 7.70 / 8.64 | 5.43 / 9.60 / 9.40 | 3.51 / 3.90 / 4.33 |
| Copper Cinema | 14.16 / 13.28 / 14.42 | 6.42 / 8.20 / 9.41 | 5.34 / 9.55 / 8.88 | 3.28 / 3.92 / 4.30 |
| Aster Violet | 14.80 / 12.93 / 14.67 | 5.65 / 8.11 / 9.00 | 6.67 / 9.29 / 8.37 | 3.39 / 4.26 / 4.83 |

Main and muted text ratios exceed 4.5:1. Border ratios exceed 3:1. Final component states, shadowed media backgrounds, icons, selection highlight, error text and disabled text still need implementation-specific checks.

## Theme modes and architecture

- **Light:** clean white canvas, gentle neutral cards, warm/cool off-white field separation (never global grey overlay).
- **Dark:** charcoal or colored-charcoal canvas and elevation; enough separation between canvas/panel/field.
- **Classic:** near-black canvas with higher contrast, same brand family but not the same colorScheme instance as Dark.
- Define per-mode semantic roles in one `StudioDesignTokens` / `ColorScheme` mapping: `canvas`, `surface`, `raisedSurface`, `fieldSurface`, `fieldBorder`, `focusBorder`, `onSurface`, `mutedText`, `primaryAction`, `onPrimaryAction`, `selection`, `danger`, `warning`, `success`, `historyPath`. Keep a global palette choice separate from saved theme mode.
- Use themed reusable `StudioCueField` (original, edited), `StudioTimeField`, and section/card/action components. Labels should use solid high-contrast text rather than low-opacity white overlays; avoid tiny overlapping button/field labels; minimum touch targets 48 logical px.
- Source vs translated/edited text should differ by label, icon and focus treatment, **not** by filling a whole text area with brand color.
- Long-duration editing: use comfortable 15–17sp base text with scalable typography, optional monospaced tabular timing, caret visibility, multiline wrap and preserved selection/undo. Validate Malayalam, Arabic/RTL, CJK and custom fonts.
- Semantic functional colors stay carefully differentiated. A muted color system does not mean hiding warnings or current/alternative history branches.

## Decision and rollout gates

- [x] CP85 R6 Android stability gate — **user-reported**.
- [x] Source audit and three candidate palette proposals, numerical basic contrast.
- [x] User approved all three skins with independently selectable Light / Dark / Classic modes; Carbon & Jade / Dark is the initial preview.
- [x] Approve three skin families and the 9-mode reference palette matrix (values still subject to real-device visual/contrast adjustments).
- [ ] Complete semantic role definitions including focus, selection, disabled, error and warning for all 9 combinations.
- [ ] Build a narrow **Edit Line input-field pilot** first, behind current theme architecture; no persistence changes.
- [ ] Android screenshots of original/edited multiline subtitles in dark/classic/light, with keyboard focused and unfocused; user acceptance.
- [ ] Check contrast, typography, focus, selection, error, disabled, warning, touch size and accessibility; widget/golden tests.
- [ ] After pilot passes, migrate Main Editor, Project Settings, Home and remaining sheets in small batches. Do not use wholesale search-and-replace for all `Colors.*`.
- [ ] Continue original technical roadmap, starting with waveform native qualification after this design decision.

**Approved plan only:** implement independent persisted skin + appearance choices with proposed new-install default Carbon & Jade / Dark while preserving existing saved theme modes. No app styling has been changed yet. See [implementation gates](STUDIO_SKINS_IMPLEMENTATION_PLAN_2026-10-16.md).
