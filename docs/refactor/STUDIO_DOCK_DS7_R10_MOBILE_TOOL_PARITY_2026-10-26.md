# SubtitleStudio — DS7 R10: shared mobile tool access in Studio Dock

Date: 2026-10-26
Branch: `feature/studio-dock-integration`

## Desktop layout and parity

- Subtitle-list header now hosts the persisted video and waveform visibility
  toggles. The current review filter is its rightmost control; the compact
  filter icon replaces its dropdown on narrow center panes.
- The subtitle action group includes **Select by index**, using the existing
  guarded selection dialog. On narrow panes it appears in the cue-action menu.
- The project-encoding label in the status bar is a button when the live host
  can save encoding metadata. It lists only portable plus native-probed
  encodings, and uses the same `SubtitleRepository.updateEncoding` path as
  mobile Project Settings. Failed writes leave the original project metadata.
- The scrollable left rail exposes the same MSone/Olam/Urban dictionary
  widgets (with mobile icons and shortcuts), the shared marked-lines sheet,
  MSone submission when enabled, and the shared Project Settings dialog.
- Bold, Italic, Underline, Text Color, and Clear Formatting controls moved
  from Style into the Text inspector immediately below Edited Text. Tooltips
  advertise Ctrl/Cmd+B, Ctrl/Cmd+I, Ctrl/Cmd+U, Alt+C and Ctrl/Cmd+Alt+X.
  The existing edited-text draft and Apply/Discard guards remain authoritative.
- Style now focuses on the 9-grid position selector, Add Effects, and the
  formatted preview. Add Effects reuses the mobile beta UI and the mobile
  karaoke/typewriter generators; the live host applies the resulting lines
  through the existing checkpoint-backed effect replacement transaction.

## Safety and regressions

- A rejected effect never dismisses its configuration dialog or mutates the
  desktop cue list. Successful operations update all reindexed cues and the
  history view, preserving the existing shared undo/redo path.
- The host validates effect type/color/delay and rejects a stale cue snapshot
  before generating replacements.
- Tests exercise encoding selection, rail commands, effects dialog acceptance
  and failure, toolbar relocation, 9-grid independence, karaoke word/character
  selection, typewriter timing and empty/invalid-duration generation.
- CI performs only Flutter analysis and tests, never platform builds. Native
  Windows interaction and media acceptance still require the user's laptop.
