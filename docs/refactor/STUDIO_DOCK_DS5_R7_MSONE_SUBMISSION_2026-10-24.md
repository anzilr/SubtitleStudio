# SubtitleStudio — DS5 R7: MSone submission parity

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Scope

Expose mobile's established **Submit to MSone** workflow from the native
desktop Studio Dock. The desktop workspace is only a UI redesign, so it must
not fork the existing submission form, API contract, persistent translator
profile, choice logic, or route-navigation recovery.

## Implementation

- Reads the existing Isar-backed `msoneEnabled` app preference. Disabled or
  unreadable preference keeps the desktop action hidden. Rechecks after the
  shared Settings dialog changes the preference.
- The live Studio Dock Tools menu opens the shared `showMsoneSubmissionFlow`
  with the active subtitle collection ID. Empty projects can also open the
  shared workflow from the empty editor toolbar.
- Retains the existing **Existing Translator** and **Fresher** paths, the
  `.msone` project or original-plus-translated files attachment choices, and
  the API request assembled by `MsoneSubmissionScreen`.
- Waits for the desktop Tools popup route's outgoing overlay to complete
  before opening the choice bottom sheet. Then delegates all subsequent
  route completion and Android gesture recovery to the existing shared flow.
- Before leaving the editor for submission, prompts to Apply, Discard, or
  Cancel any dirty cue/notes/source draft. Cancelling does not navigate or
  send anything; repeated clicks cannot open overlapping submission routes.
- No changes to the mobile Editor, submission API, or Isar schema.

## Validation boundaries

- Widget: disabled flag hides the desktop menu; enabled callback shows it.
- Widget: Existing Translator and Fresher routes return to Studio Dock after
  system Back without retaining modal barriers.
- Widget: unsaved cue Cancel blocks opening the submission workflow; a
  confirmed Discard allows it; empty projects remain usable.
- Persistence: reading and toggling the existing `msoneEnabled` preference.
- Analyzer, Studio Dock tests and complete Flutter tests in GitHub Actions.
  **No platform builds or actual online submissions in CI.**

Native Windows acceptance is still pending, especially file selection,
attachment readability, layout, and navigator focus after dismissal. Existing
Android route-return tests remain in the full suite unchanged.

## Next parity work

P0 is still secondary subtitle playback and waveform timing gestures. MSone
banners and Malayalam normalization remain separate missing desktop actions.
