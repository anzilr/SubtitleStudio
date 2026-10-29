# Studio Dock DS7 R26 — optional project saving during SRT import

Date: 2026-10-29
Branch: `feature/studio-dock-integration`

## Desktop parity

- SRT import offers an optional **Save a portable project file after import**
  checkbox, off by default. This matches the mobile choice to save an `.msone`
  copy as part of the import workflow.
- The source SRT is decoded and imported first. If selected, the app then
  offers a native `.msone` Save As dialog using the existing guarded project
  save coordinator. Its document includes the subtitle collection and edit
  history references.
- Canceling the Save As picker, declining replacement, or failing to write a
  project copy does **not** undo the successful SRT import or modify the
  original source file. A status message distinguishes import success from
  project-copy save failures.
- Replacing an existing `.msone` requires a second explicit confirmation.
  Stale-document and changed-session checks remain active during the picker.
- The new choice does not apply to `.msone` project imports, which retain
  their separate import-source and history-replacement workflow.

## Regression coverage

- Desktop SRT import-dialog tests cover default-off behavior and opting into
  portable project saving while retaining the other import selections.
- Project-save integration covers importing an actual SRT, default unlinked
  state, optional `.msone` export, correct project linkage, and source-byte
  preservation. Existing tests cover overwrite refusal and stale saves.

## Remaining parity checks

- Native Windows/Linux/macOS picker and overwrite dialogs require manual
  smoke testing on an actual desktop.
- Next: new-project name/encoding/file-location parity, followed by full
  round-trip SRT Save/Save As and `.msone` import/replacement acceptance.

Verification policy: pull and run Flutter analysis/tests in the connected
VS Code workspace. Use GitHub Actions only if VS Code is unavailable; never
build platform binaries in Actions.
