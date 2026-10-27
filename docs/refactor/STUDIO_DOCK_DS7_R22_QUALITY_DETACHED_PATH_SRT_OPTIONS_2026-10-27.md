# SubtitleStudio — DS7 R22 quality, detached history and import parity

Date: 2026-10-27  
Branch: `feature/studio-dock-integration`

## Quality source selection

- Quality review previously sent `StudioDockCue.edited` to the analyzer. This
  field is empty for an unedited imported cue; the displayed/exported caption
  actually comes from `storedEdited ?? original`.
- The review now uses the persisted effective text, keeping explicit empty
  edits (`storedEdited == ''`) truly empty. Nested `<font>`/`<b>` Malayalam text
  is tested as visible and is not misclassified as missing dialogue.
- Existing effect-group awareness remains in place. Quality suggestions and
  their guarded persistence still share the same effective-text contract.

## Branch graph styling (desktop screenshots)

- User screenshots show `Editing from point #25 · Separate branch` and only
  one named ref, `Main path`. The edited continuation has detached HEAD, not
  a saved branch name, so prior `displayOwners` returned no owner/color.
- The history view assigns a **display-only** detached owner after named
  branch ancestry has claimed its nodes. The detached continuation is blue;
  shared/main ancestry keeps the main branch hue. An on-screen legend names
  the current separate path without pretending it is a persistent branch.
- Does not change checkpoint IDs, refs, attached HEAD or checkout behavior.

## Desktop SRT import parity (next P1 slice)

- The native SRT preflight now adds opt-in hearing-impaired text cleanup and
  merging of **adjacent cues with identical start and end times**, using the
  same processing pipeline as mobile. Both defaults remain **off**.
- The selected source encoding/preview and Cancel/no-write behavior from R21
  are preserved. Optional transformations apply only to the imported working
  copy; they do not rewrite the selected source SRT.
- Import-time `.msone` save is still absent, as are the separate `.msone`
  desktop preview/replace/relink/history-fallback flow, Save As/Export
  consistency, native extraction and creation-location parity from R19.

## Verification

New tests cover source-vs-explicitly-empty quality text, nested Malayalam
styling, detached rail coloring and shared-parent ownership, checkbox choices,
and import-transform opt-in/non-overwrite behavior. Run the existing Studio
Dock and full Flutter analyzers/tests; no platform builds in GitHub Actions.
Native Windows UI and SRT import acceptance remain required.
