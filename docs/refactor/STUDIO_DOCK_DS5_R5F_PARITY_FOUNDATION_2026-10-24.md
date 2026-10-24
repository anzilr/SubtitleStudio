# SubtitleStudio — DS5 R5f: Desktop parity foundation

Date: 2026-10-24
Branch: `feature/studio-dock-integration`
Predecessor: `STUDIO_DOCK_DS5_R5E_REVIEW_RESOLUTION_2026-10-24.md`

## Clarified objective

The user's instruction is unequivocal: Studio Dock replaces **only** the
desktop layout. It must eventually expose every mobile editor feature with
the same behavior and shared component/service, while keeping mobile UI
unchanged. This checkpoint starts an explicit parity audit instead of treating
currently connected desktop functions as the complete editor.

Read `STUDIO_DOCK_DESKTOP_MOBILE_PARITY_MATRIX_2026-10-24.md` for the full
supported/partial/missing ledger. Keep it updated as functionality is wired.

## Changes

- Converted previously inert Edit/Subtitle/Timing/Tools/View/Help desktop
  menu labels into real popup menus, reusing existing guarded Studio Dock
  actions for undo/redo, Find/Replace, Add/Delete/Split/Combine, inspector
  Text/Timing/Notes, tools, Source View and editing history.
- Reused the **actual mobile `SettingsSheet`** as a desktop dialog through
  the live session host. No parallel preferences storage. The Settings rail,
  View menu and command palette invoke it without discarding a cue draft.
- Wired **actual mobile `HelpScreen`** to the Help menu and command palette.
- Added Select All Visible and Copy Selected Subtitle Text using the same
  effective-text format as mobile (`edited` text, blank line between cues).
- Preserved the nullable persisted edited value in the desktop cue projection.
  Clipboard output now distinguishes a never-edited cue (copy original text)
  from a deliberately blank edited cue (copy blank), as mobile does.
- Corrected wide-screen inspector commands so they reveal the docked panel
  rather than creating a second overlaid inspector instance.
- Kept the mobile code and underlying editing repositories unchanged.

## Regression acceptance

- Widget: Settings from rail and View menu retains an unsaved cue draft.
- Widget: Help menu invokes the host's shared Help route.
- Widget: Edit/Subtitle/Timing/Tools menus navigate real sections/actions.
- Widget: multi-cue clipboard text matches the mobile separator format.
- Flutter analysis and both focused Studio Dock and full test suites in
  GitHub Actions only. **Never build native applications in CI.**

## Remaining

Feature parity is **not yet complete**. Prioritize the P0/P1/P2 rows in the
parity ledger, especially secondary subtitle playback and waveform editing,
then project settings/encoding, selected-cue operations, sync and specialized
mobile tools. Native Windows acceptance is deferred until the user's machine
is available.

## CI

- **Focused Studio Dock PASS:** [run 40084792597](https://github.com/anzilr/SubtitleStudio/actions/runs/40084792597), `flutter analyze` successful, **151 tests passed**. Earlier run passed 149 tests but identified a wrong live-edit key and an unmocked clipboard platform channel in the new widget tests; both were corrected.
- **Full Flutter PASS:** [run 40084983040](https://github.com/anzilr/SubtitleStudio/actions/runs/40084983040), `flutter analyze` successful, **954 tests passed**, including the nullable edited-text projection correction.
- No native/platform builds executed. Windows live acceptance remains deferred.
