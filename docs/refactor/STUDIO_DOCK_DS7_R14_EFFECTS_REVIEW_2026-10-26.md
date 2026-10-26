# DS7 R14 — SRT effects and collapsed review marks (2026-10-26)

Branch: `feature/studio-dock-integration` (fork `anzilr/SubtitleStudio`).

## Scope

- Added six SRT-compatible, timed-cue effects: Word Reveal, Moving Karaoke
  Highlight, Typewriter with Active Character, Backspace, Line Reveal, and
  Color Transition. No ASS/SSA script tags or additional subtitle formats.
- `SrtEffectFrames` is the shared pure frame generator for new effects. The
  mobile/desktop effects-sheet preview renders those generated frames and
  uses grapheme boundaries. The existing karaoke/typewriter previews were
  corrected to avoid UTF-16 slicing and discarded whitespace.
- Both the classic mobile editor and Studio Dock call the same persistence
  operation with checkpoint history; source cue marks are inherited.
- Recognition distinguishes additional frame patterns conservatively, then
  folds them without mutating original cues or SRT output.
- A collapsed effect's mark icon now has none/partial/all states. Marking or
  unmarking it targets every real frame in a single bulk-review history step.
  Expanded frames retain independent marks. The marked-lines sheet folds
  fully marked groups, exposes their frame count and comments, and expands
  for individual notes; desktop additionally supports an atomic group unmark.

## Validation

- New tests: `test/srt_effect_frames_test.dart` and marked-lines widget test.
- Expanded existing recognition test for Moving Karaoke.
- `git diff --check` clean before CI request.
- CI: Flutter analyze/full tests and Studio Dock suite are dispatched via
  `.github/ci-checkpoint` and `.github/ci-studio-dock` on this branch.
- R14a: Corrected the demo multi-selection toggle regression reported by
  both first-pass CI runs. A collapsed group toggles uniformly; unrelated
  selected cues keep their existing independent toggle semantics.

## Follow-up

- Verify the live Android/Windows visual behaviors (especially dialogs,
  native playback synchronization and very large marked groups).
- Preview existing legacy Karaoke/Typewriter through the exact persisted
  frame pipeline too, including selected-span karaoke, in a later pass.
- Preserve offline Isar data, `.msone` compatibility, and all supported
  platforms; never place platform builds in GitHub Actions.
