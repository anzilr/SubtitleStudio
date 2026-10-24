# SubtitleStudio — DS5 R19 Source-level Feature Parity Audit

Date: 2026-10-24
Branch: `feature/studio-dock-integration`
Source: mobile `edit_main_menu.dart`, `edit_menu_actions.dart`,
`edit_shortcuts.dart`, `MSoneHotkeyManager`, native
`studio_dock_workspace.dart` and its mounted player/surface.

## Implemented during R19

**Fullscreen** — Studio Dock's View menu now offers Toggle video fullscreen
when an attached video surface exists. The existing
`HotkeyAction.toggleFullscreen` uses the same native player's public
`toggleCustomFullscreen` method. The host callback remains registered from
first mount even if the media path resolves later. No second Media Kit player
or waveform session is created.

**Delete selection** — Reuse the mobile Shift+Delete manager chord. A single
selected cue uses the existing confirmation dialog and checkpoint-backed
delete; more than one uses the existing batch-delete confirmation and one
optimistic history transaction. Text-field typing and modal routes block
destructive shortcuts, as in R17.

**Edit current / Marked lines shortcuts** — The existing actions now navigate
to the desktop Text inspector or its marked-lines review filter. Marked-line
navigation respects the unsaved draft gate and preserves history; it does
not add a second independent marked-line screen.

## Mobile vs desktop command inventory

| Capability | Desktop status / evidence |
|---|---|
| Save/Save As/project export/open/import/new | Wired via File menu/Home; native round-trip pending |
| Editor text and timecode editing, split/combine, formatting/alignment | Wired inspector/grid; native input acceptance pending |
| Mark, comment, resolved/reopened, history/Undo | Wired via Notes and fullscreen player; native overlay QA pending |
| Search/replace, Go to Line, selection tools | Wired; native large-document QA pending |
| Secondary subtitles, sync, import comments, clean hearing-impaired | Wired via shared services; file and video acceptance pending |
| MSone submit/banners/Malayalam normalization | Wired behind existing MSone preference; never live-submit test data |
| Play/pause, next/previous cue, fullscreen | Shared media path and manager now wired |
| Unload video | Accessible through Project Settings, but not yet a direct mobile-equivalent toolbar action |
| Waveform Generate/Regenerate/Hide and floating controls | **Partial** — shared waveform works; mobile direct actions not yet audited/wired |
| Video repeat and repeat range | **Partial** — fullscreen/player supports some controls; native desktop exposure and hotkeys need auditing |
| Format/dictionary/color picker/paste-original hotkeys | **Partial** — corresponding inspector/menu features may be present, but direct hotkeys still missing |
| Native Windows/macOS/Linux keyboard, media, file picker | **Not tested**; cannot be certified by Linux Flutter widget tests |

## Regression and limits

New widget tests verify View menu fullscreen enable/disable, shared fullscreen
hotkey, dialog/text-focus protection, Shift+Delete confirmation and marked
lines filtering. Fullscreen's standard F11 action on Windows/Linux and Cmd+F
on macOS is inherited unchanged from the shared manager. Cmd+F may conflict
with Find on macOS; verify on a native machine before calling shortcut parity
complete. There is no separate desktop hotkey implementation.

CI only runs `flutter pub get`, `flutter analyze`, focused Studio Dock
`flutter test` and full Flutter tests. Never run platform application builds
in GitHub Actions. The user's Windows machine is unavailable for acceptance.

## Next actionable checkpoints

1. Close mobile Generate/Regenerate/Hide Waveform and video floating-control
   command parity by exposing existing player/waveform controller actions.
2. Reconcile dictionary, line-format, original-paste and repeat shortcuts with
   Flutter focus priority, without hijacking text editor shortcuts.
3. Full desktop widget/service acceptance and eventual Windows device QA,
   including Edit Mode and real MSone workflows.
