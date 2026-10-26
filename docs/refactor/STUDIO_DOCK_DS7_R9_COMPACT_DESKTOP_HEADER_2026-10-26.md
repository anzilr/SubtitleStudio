# SubtitleStudio — DS7 R9: single-row desktop menu and subtitle header

Date: 2026-10-26
Branch: `feature/studio-dock-integration`

## Layout changes

- Consolidated the old 32px File/Edit/Subtitle/Timing/Tools/View/Help row and
  48px toolbar into one **44px** row. This gives the editing bands about 36px
  more vertical room without changing their chosen video/waveform/list shares.
- Brand now reads **Subtitle Studio**, with Studio using the active accent.
  The project filename is no longer repeated beside the brand; it remains in
  the 24px status bar. The read-only indicator also lives in that bar.
- File/Edit/Subtitle/Timing/Tools/View/Help immediately follow the brand.
  A contrasting, tinted **Commands** control sits after these text menus and
  before the right-aligned action buttons (Ctrl/Cmd+K unchanged).
- Global action order at desktop widths: New project, Import subtitles or
  project, Attach/change video, Save, Undo, Redo, Project Explorer, Inspector.
  On narrow windows the first three appear in a project-actions overflow;
  the remaining global controls retain their normal buttons.
- Video and waveform visibility controls remain accessible through **View**.
  Their existing saved panel-state handling is unchanged. Project Settings
  remains in **File** and its shared host route is unchanged.
- The subtitle grid header uses the actual subtitle count/filtered count as
  its title. Removed the redundant `SUBTITLE LINES` words, placed search
  directly after the title, and moved Insert/Split/Combine/Delete beside that
  search. On narrow center panels, those four operations collapse into an
  editing menu, preserving access without an extra header row.
- Go to Line now uses a numbered-list icon instead of `#`. Follow-subtitles
  now uses sync/sync-disabled icons rather than a location target. The
  history, draft guards, selected-cue actions and their shortcuts are intact.
- Subtitle search no longer jumps to a second 34px row below 850px panel
  width, preserving additional subtitle-list height on narrow layouts.

## Verification

- Widget regressions cover right-hand toolbar order, separate header action
  order, the 44px merged bar, narrow editing overflow, the changed icons,
  view-menu media visibility toggles and the existing project settings entry.
- Flutter CI remains dependency resolution, analyzer and tests only. Platform
  builds and native Windows pointer/resize acceptance are deferred.

User item 9 was submitted blank and is intentionally not interpreted.
