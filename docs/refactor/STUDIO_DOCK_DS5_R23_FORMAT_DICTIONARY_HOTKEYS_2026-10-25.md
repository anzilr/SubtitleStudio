# SubtitleStudio — DS5 R23 Formatting and Dictionary Hotkeys

Date: 2026-10-25
Branch: `feature/studio-dock-integration`

## Desktop source changes

- Register the already-defined `MSoneHotkeyManager` commands for Bold,
  Italic, color picker, MSone Dictionary, Olam Dictionary, Urban Dictionary,
  and Paste Original. The mobile editing route is not changed.
- The Text inspector's focused `EditableText` uses the existing
  `toggleTextFormatting` helper so selection-local formatting matches mobile.
  When the cue field is not focused, the existing whole-cue Style action is
  used. Editing a timecode, search, note or other field cannot trigger the
  formatting/dictionary shortcuts. Modal routes suppress all workspace
  commands, including Save.
- The desktop Subtitle/Edit/Tools menus expose the same actions for mouse
  access; dictionary lookups use the existing provider widgets with the
  original subtitle as their initial query in Translation Mode. Olam and
  Urban result cards gain an opt-in desktop-only "Use meaning" button; their
  existing mobile copy-only experience is unchanged.
- Dictionary selection, formatting, color and Paste Original update a **local
  unsaved draft** and require Apply to create the normal checkpoint. No new
  subtitle persistence service or database is introduced. Paste Original is
  unavailable in Edit Mode, where subtitles are created from scratch.
- External edits such as dictionary selections, color, alignment and style
  toolbar changes increment the draft-field revision so an already-mounted
  `TextFormField` displays the new value. Direct focused text edits keep their
  existing controller and selection without remounting.

## Verification

- Flutter widget tests check formatted draft text, Apply-only persistence,
  timecode focus suppression, Paste Original draft and Edit Mode exclusion.
- CI acceptance: Flutter analysis, focused Studio Dock tests and full Flutter
  test suite. The repository CI does **not** run platform builds.
- **Not yet accepted on native desktop:** Windows/macOS/Linux hotkey collision,
  focus restoration after dictionary/color dialogs, live Olam/MSone/Urban
  provider responses, selected-text range behavior under IME composition,
  popup dismissal ordering and a real project round trip.

R23 is Flutter source-level parity, not native OS acceptance.
