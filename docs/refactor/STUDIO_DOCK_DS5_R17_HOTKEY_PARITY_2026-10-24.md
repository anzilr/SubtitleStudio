# SubtitleStudio — DS5 R17 Desktop Hotkey Parity Audit

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Existing manager reused

Studio Dock registers its current live actions only through the established
`MSoneHotkeyManager` (`HotkeyScope.inapp`). In parent-Editor embedded
mode, the parent manager stays callback-suppressed and Studio Dock does not
override the parent's existing bindings. Standalone native desktop owns
its callbacks and unregisters them on workspace disposal.

## Shared manager mapping

| Action | Existing desktop binding | Studio Dock result |
|---|---|---|
| Play/pause | Ctrl+Space (Windows/Linux); Shift+Space (macOS) | Native mounted player's play/pause |
| Next/previous cue | Primary+period/comma | Guard unsaved drafts; scroll/select cue and seek shared player |
| Find and Replace | Ctrl+F | Existing search section |
| Go to Line | Primary+J | Existing validated/seek Go to Line dialog |
| Mark | Primary+M | Existing guarded review persistence |
| Mark and comment | Primary+Shift+M | Open Notes inspector with a draft mark; persist only when Apply is pressed |
| Split/combine | Primary+Alt+V / Alt+L | Shared guarded structure services |
| Save/Save As | Primary+S / Primary+Shift+S | Existing charset-aware SRT file actions |
| Save project | Primary+E | Complete .msone project save via existing save flow |
| Help/Settings | Ctrl+H or macOS Cmd+Shift+H / Alt+S | Existing routes/Settings section |

The canonical manager's primary modifier is Cmd on macOS and Ctrl elsewhere.
The existing Ctrl+F on macOS remains unchanged to avoid colliding with the
shared `toggleFullscreen` Cmd+F shortcut. Home mode also assigns Ctrl+E
to extraction; never mount/register Home and Studio Dock bindings together.
Review these existing system bindings in a native macOS/Windows acceptance pass.

## Focus safety

- Focus-aware Undo/Redo (Ctrl/Cmd+Z and shift variants) and command palette
  (Ctrl/Cmd+K) remain local Flutter `CallbackShortcuts`.
- Ctrl/Cmd+C is also scoped through Flutter's shortcut tree, *not* native
  hotkey_manager, so EditableText's own Copy action wins within the text
  inspector. A focused subtitle grid copies selected subtitles with the
  existing mobile's effective-text/blank-line formatting.
- Manager callbacks check whether the Studio Dock's route is current before
  dispatching, preventing actions behind dialogs and other routes.
- Focused EditableText blocks non-save manager actions; Save/Save As and Save
  Project continue using their existing guarded save transactions.
- Media shortcuts use the existing player instance; there is no second player.
- Existing edit draft guard prevents cue navigation and history mutation from
  discarding pending text, notes or timing changes.

## Deferred native acceptance

Hotkey_manager is platform-specific. Widget tests exercise callbacks through
a test-only dispatcher (without registering a native system chord), check
modal guarding, cue seek linkage, playback callback, clipboard focus and
mark-and-comment draft behavior. Native Windows/macOS/Linux acceptance must
still verify actual modifier chords, fullscreen conflicts, focus ownership and
returning from sheet/dialog routes. Extra mobile hotkeys (repeat range,
dictionary, fullscreen and line-level formatting) remain part of the separate
fullscreen/editor-tool audit, not silently counted complete.

## CI

Run only Flutter pub get, analyzer, focused Studio Dock tests and repository
Flutter tests through GitHub Actions. No native/platform builds.
MSone submission, the mobile editor and production MSone network API remain
unchanged.
