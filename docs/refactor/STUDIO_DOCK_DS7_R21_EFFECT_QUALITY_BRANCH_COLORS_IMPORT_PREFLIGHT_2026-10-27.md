# SubtitleStudio — DS7 R21 quality, history and parity checkpoint

Date: 2026-10-27  
Branch: `feature/studio-dock-integration`

## Effect-aware subtitle quality

- Reuse the conservative SRT effect detector already shared by collapsed
  subtitle rows and the effects filter. Tag every recognized frame with its
  real persisted effect group identity before quality review.
- Treat generated frame text, spaces and duration as animation states, not
  independent dialogue. Suppress per-frame CPS/line/duration/empty/repeated
  text warnings and misleading gaps **inside** a detected animation only.
- Preserve malformed timecodes, invalid durations, out-of-order timestamps,
  and overlap/gap warnings against unrelated subtitles.
- Do not propose per-frame text or timing changes to recognized effects.
  The guarded batch writer re-detects effect groups against the persisted
  source before accepting suggestions so a forged/stale fix cannot silently
  destroy an effect.
- Imported effects outside the conservative recognition patterns can still be
  reported as ordinary cues; extend detector patterns through regression
  fixtures rather than suppressing quality for all short subtitles.

## Edit-history branch colors

- Every branch chip now uses its unique lane color even when not selected.
  The attached path has stronger label emphasis; focusing a path adds its
  selected tint without changing what HEAD is attached to.
- Branch labels on checkpoint cards use the same color token and tinted
  background. The branch picker and graph rail continue sharing this map.

## First P1 parity slice: SRT import encoding and preview

- Studio Dock desktop now asks for source encoding and offers a text preview
  *before* storing a newly opened SRT. Cancel is a no-write action.
- The selected encoding goes into the existing strict extended source decoder,
  the same decoder used by mobile import preview, and persists on the imported
  subtitle collection. Invalid UTF-8 does not silently fall back or create a
  session; an explicit Windows-1252 (or available system charset) can be used.
- `.msone` project import continues through its existing route; the desktop
  package preview/replace/relink/history-fallback decisions remain a separate
  P1 gap. Desktop HI cleanup/overlap-merge and import-time project saving are
  also still open. Mobile/desktop Save As vs Export semantics, extraction,
  creation options, and native acceptance remain listed in the R19 audit.

## Verification

Tests added/extended for effect-frame quality, real overlap safety, desktop
quality UI, branch chip colors, explicit legacy encoding and import preview
Cancel/Confirm. Run `flutter analyze`, Studio Dock widget tests and the full
Flutter suite through the existing GitHub quality workflows only (never
platform builds in CI). Native Windows import-dialog and history-theme checks
remain required.
