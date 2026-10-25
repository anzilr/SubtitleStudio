# DS5 R26 — Edit Line display and navigation preferences

Date: 2026-10-25
Branch: `feature/studio-dock-integration`

## Objective

Bring mobile Edit Line's original-line, original-field, navigation-save and
formatted-display controls into **the sole native desktop Studio Dock UI**.
The existing original/edited grid, checkpoint-backed Apply, raw text editing,
and Edit Mode are preserved.

## Implementation

- Desktop `View` now offers the shared `Show Original Line`, `Auto-save with
  navigation` (only while showing original lines), and `Show Original Text
  Field` preferences, plus a session-only `Formatted View` toggle.
- The live host reads and updates the *same* Isar preferences used by the
  mobile Edit Line. Enabling Show Original Line atomically disables auto-save;
  disabling it automatically enables auto-save, per mobile behavior.
- Show Original Line is a **display-only fallback** when the persisted edit is
  empty. Merely navigating through such a line never writes original text to
  the edited field. Editing that visible fallback explicitly creates a draft.
- Cue-to-cue navigation uses existing checkpoint-backed Apply only when
  auto-save is permitted. Save conflicts prevent selection change and leave
  the draft intact. Notes require the existing explicit confirmation. Other
  transitions (media, project, file, source) always retain draft confirmation.
- Formatted View renders a read-only formatted preview alongside the editable
  source field so desktop formatting never makes the text impossible to edit.
  The original inspector field can be hidden without hiding the side-by-side
  subtitle grid.
- Preference failures do not optimistically change the UI. Formatting state
  stays transient, matching mobile.

## Gates

- Flutter static analysis and focused Studio Dock widget tests; then full
  Flutter tests via GitHub Actions. **No platform builds in Actions.**
- Native Windows interaction acceptance remains deferred until the user's
  Windows machine is available.

## Follow-up

Audit whether any further mobile Edit Line controls need a desktop-native
entry point; finish waveform input/seek precision and native acceptance.
