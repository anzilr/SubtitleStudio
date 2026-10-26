# DS7 R16 — Moving Karaoke by grapheme and toolbar SVG refresh (2026-10-26)

Branch: `feature/studio-dock-integration` in fork `anzilr/SubtitleStudio`.

## Changes

- Moving Karaoke has a Word / Character (letter) choice in the shared effects
  sheet. Word stays the default and preserves existing project behavior.
- The Character option advances the highlighted substring over visible
  Unicode graphemes, skipping whitespace-only frames. It preserves full text,
  timing, intact Malayalam clusters, combining sequences and joined emoji.
- `SrtEffectFrames` remains the sole source for effect preview and export.
  The `unit` setting travels through all effect applications: edit-list,
  single-line editor, and Studio Dock. Group recognition, mark-all in collapsed
  rows, independent frame marks, and marked-lines projection continue to work
  on generated character-level frames without changing SRT schema.
- Included seven exact SVGs from the supplied ZIP: show/hide waveform,
  show/hide video, pause/resume subtitle flow, and marked-lines sheet. They
  replace corresponding mobile and desktop toolbar/action icons and are
  theme-colored by the existing `StudioAssetIcon` component.
- Deliberately did **not** copy or wire the supplied `add_effects.svg`, so the
  existing Add Effects icon and action remain unchanged.

## Tests / CI

- Added coverage of word vs character output, Unicode-cluster highlighting,
  timed cue export, moving-karoke auto-folding, UI config submission, and
  loading every supplied Flutter SVG asset.
- CI triggers only `flutter pub get`, `flutter analyze`, and `flutter test`;
  **no platform builds in GitHub Actions**.
- Verified source commit `3ce9c99a247d10ff80bd01154e62db87a82dd683`:
  - Studio Dock Flutter quality: **PASS**, analyzer clean, **373 tests**
    (run `40401982309`).
  - Migration quality checks: **PASS**, analyzer clean, **1,219 tests**
    (run `40401982869`).
- Platform/device visual QA is still needed to review toolbar SVG appearance,
  high-contrast themes, and playback while Character Karaoke frames advance.

## Candidate future effects limited to standard SRT cues

- Spotlight/pulse word or character with changing font-color tags.
- Reverse or center-out grapheme reveal (keeping combining sequences intact).
- Progressive emphasis via `<b>` / `<u>` tags, if supported by target player.
- Cursor-style typewriter and reverse-delete, implemented with timed frames.
- Glitch-to-clean text / rolling countdown via timed frame replacement.

Remember that SRT has no reliable native animation/position/alpha protocol:
effect frames are successive cues and inline formatting is player-dependent.
