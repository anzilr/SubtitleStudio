# SubtitleStudio — DS5 R30 desktop/mobile review navigation parity

Date: 2026-10-25
Branch: `feature/studio-dock-integration`

## Mobile command versus desktop entry-point audit

This audit compares the mobile `edit_main_menu.dart`, `edit_line_menu.dart`
and selection menu against the Studio Dock's live host callbacks and menus.
Studio Dock remains the **only desktop editor**. All editing continues through
the shared session and checkpoint services; this checkpoint does not introduce
an alternate editor, store or media player.

| Mobile capability | Desktop entry point |
| --- | --- |
| Create/open project and load/unload video | Project toolbar and video controls; guarded unload in View |
| Save subtitle, Save As, save `.msone`, project settings | File menu and existing host callbacks |
| Source View and timeline return | Source View section and editor rail |
| Find/replace and Go to Line | Edit menu, search rail and grid action |
| Select, copy, shift, delete and batch-range tools | Edit/Subtitle/Timing menus and cue context menu |
| Mark/unmark, resolved/reopen, review notes | Grid review actions, Notes inspector and context menu |
| **Show Marked Lines** | **Tools menu, shared hotkey and grid review filter** |
| History and checkpoint navigation | History rail, Tools menu and Undo/Redo |
| Secondary subtitles and comment import | Tools menu and session callbacks |
| Sync, cleanup, MSone banners/normalize/submission | Timing and Tools menus |
| Waveform visibility, generation and regeneration | Live waveform toolbar with the shared waveform engine |
| Floating controls/fullscreen/repeat | Dock transport and View commands |
| Original field, auto-save navigation, formatted view | View preferences bound to the same Edit Line settings |
| Settings/help | View/Help menu and rail |

This is a **source-level command access audit**. Native mouse behavior,
visual layout, project I/O and audio decoding still need acceptance on a
real Windows build. Mobile-only keyboard resize intentionally has no desktop
equivalent.

## Bug fixed

The grid review dropdown previously changed the active filter immediately,
even when the selected cue had unsaved text, timing or notes. This could hide
the edited row without the normal Apply/Discard/Cancel decision. The mobile
main menu also exposed a direct Show Marked Lines action which had no matching
desktop menu item (although the hotkey and grid dropdown worked).

- The review-filter dropdown now uses the existing unsaved-edit confirmation.
  Cancel or a rejected Apply leaves the filter and draft intact; Apply must
  succeed before the view changes. Existing batch selection is preserved.
- Tools → Show marked lines invokes the same guarded route as the pre-existing
  desktop hotkey, waiting for the popup to finish closing before any modal.
  It opens the grid, removes its text query and uses the Marked filter.
- The existing All / Marked / Unresolved / Resolved options, Notes inspector,
  resolved flags, and mobile editor code remain unchanged.

## Regression coverage

Four widget tests exercise filter Cancel, successful Apply, rejected Apply and
the new Tools menu route. Flutter-only focused Studio Dock CI and the full
Flutter analyzer/test gate must pass before native acceptance. GitHub Actions
must **not** build Android, Windows, Linux, macOS or iOS applications.

## Pending native acceptance

- Studio Dock review dropdown and Tools menu focus/animation on Windows.
- Unsaved text, timing and notes drafts with every review filter.
- Selected and non-selected cue context actions in a large project.
- Edit Mode creation and Translation Mode parity with real `.msone` save,
  reopen, MSone submission and Undo/Redo.
- Long-media waveform responsiveness and precise seek/timing interactions.
