# SubtitleStudio — Desktop/Mobile editor feature parity contract

Date: 2026-10-24
Track: Studio Dock, native desktop only
Reference: mobile `screen_edit.dart`, `screens/edit/parts/`, `widgets/edit_main_menu.dart`,
`screens/edit_line/` and the existing Riverpod/repository/media services.

## Non-negotiable scope

Studio Dock is **only a desktop UI layout redesign**. Every function the
mobile editor exposes must remain available on desktop, retaining the same
behavior, saved data, shared service, and history/undo semantics. Desktop may
use menus/dialogs/panels instead of mobile sheets; it must not silently omit
features, substitute demo behavior in a live session or modify mobile UI.

The statuses below describe the **implementation in source**, not Windows
acceptance. A wired callback is not proof of a working native interaction.

## Audited parity ledger

| Mobile capability | Studio Dock state | Required parity work / verification |
| --- | --- | --- |
| Create/open project, SRT/VTT/ASS/.msone import | Wired via desktop Home | Verify native file associations and reopened projects |
| Save, Save As, SRT export, complete .msone project save | Wired to shared services | Native filename/encoding/round-trip acceptance |
| Edit Mode (create subtitles from scratch) vs Translation Mode | Wired in DS5 R6 | Native mode-dependent inspector, cue insert/split, Source View and SRT export acceptance |
| Video attach, playback, fullscreen | DS5 R19 adds View → Toggle video fullscreen and the existing F11/Cmd+F manager action on the mounted player, on top of shared `VideoPlayerSection` / `VideoPlayerWidget`; Shift+Delete and Marked Lines also restored to desktop hotkeys | Native fullscreen keyboard/menu, attach/unload/replace, playback/seek, OS hotkey conflict and dialog acceptance |
| Playback-follow subtitle highlight and seek | Wired through shared playback link | Native bidirectional seek/scroll/accuracy acceptance |
| Waveform display and selected audio stream | DS5 R20 adds direct Generate/Hide and Regenerate controls in the desktop waveform band, using the same scoped Riverpod controller, PCM-cache invalidation and player-resolved audio selector; waveform zoom/time editing remain. **Floating playback controls and compact peak-cache regeneration require further verification** | Native waveform generate/regenerate/hide/show, selected-track fidelity, cached/uncached paths, player non-remount, floating-controls verification |
| Waveform gesture time edits and insertion | Wired in DS5 R9: shared waveform gestures and compact controls call guarded Studio Dock timing/insert services; successful edits reconcile the grid/player and history | Native drag precision, magnet/overlap behavior, cue creation, undo, media stability and synchronized scrolling acceptance |
| Secondary subtitles, visibility and saved selection | Wired in DS5 R8 through the existing secondary sheet, `VideoRepository` preferences, and shared player; original-text overlay reprojects from current cues | Native external/video-track picker, original-text updates and selection persistence acceptance; Project Settings remains separate |
| Edit text, start/end timing, formatting, nine-grid alignment | Wired to shared repositories and format tags | Native editor/controller interaction acceptance |
| Cue insert, delete, split and combine | Wired, guarded, undoable | Compare edge cases and keyboard semantics with mobile |
| History graph, checkpoints, undo/redo/forks | Wired to shared graph/repository | Native path/bookmark navigation acceptance |
| Find/replace and raw Source View | Wired to shared tools/parser | Compare regex/case/selection semantics and file fidelity |
| Marked lines, comments, resolve/reopen and filters | DS5 R18 extends the existing shared fullscreen player: mark/unmark and atomic mark+comment editing route to the desktop Notes checkpoint service; desktop-only Resolve/Reopen button, optimistic draft guard, refreshed player overlays (including comment-only/resolved changes), and unchanged mobile fullscreen defaults | Windows fullscreen mark/comment/Delete/Resolve/Reopen, OverlayEntry focus, Undo/Redo, repeated media transitions, unsaved-draft cancel acceptance |
| Copy selected subtitle text, select all visible | Wired in DS5 R5f using mobile copy format | Clipboard and multi-selection widget acceptance |
| Shift/delete selected cues, select by index/range | Wired in DS5 R11: index/range and pointer/keyboard multi-select, mobile-style selected timing stretch with duration preservation, guarded single-checkpoint multi-delete | Native selection, source edits, long-project scrolling, mixed selections and undo/redo acceptance |
| Go to Line and direct video seek | Wired in DS5 R12 to the Edit menu, grid, and shared `gotoLine` hotkey: 1-based input/slider, unsaved-draft guard, scroll-to-cue and attached-player start +50 ms | Native large-project keyboard input, slider, focus and seek-accuracy acceptance |
| Import comments from .msone project files | Wired in DS5 R13 to existing `ImportCommentsSheet`, `ProjectCommentImportPlan` and shared checkpoint-backed `ProjectCommentRepository`; successful imports refresh live cues, selected rows and history | Native .msone picker, match counts, Cancel, changed marking/resolution, Undo/Redo, narrow dialog acceptance |
| Subtitle synchronization | Wired in DS5 R15: first/last proportional anchors (durations preserved), positive/negative millisecond shift, selected-cue stretch, and video-gated framerate conversion (both bounds scaled); optimistic single-checkpoint history saves with canonical SRT range validation | Windows native video FPS detection, actual file sync, precision, selection consistency and Undo/Redo acceptance |
| Remove hearing-impaired annotations | Wired in DS5 R14 to the shared `HearingImpairedCleanupService` through a dirty-draft guard and source-snapshot preflight; after the checkpoint transaction Studio Dock reloads all cues | Windows real-file cleanup, cue deletions, translated text preservation, Undo/Redo acceptance |
| MSone submission (Existing Translator/Fresher, .msone or SRT pair) | Wired in DS5 R7 to the existing submission flow; shown only when MSone features are enabled | Native picker, completed form and route-return acceptance; never submit test data to the live endpoint |
| MSone banners and Malayalam Normalize | Wired in DS5 R16 to the existing mobile BannerConfigurationSheet and MalayalamNormalizationSheet with persisted MSone-feature gating, Tools menu/panel actions, popup/dirty-draft safeguards and shared history refresh | Native banner timing/overlap/edit, Malayalam preview selections, Cancel, Undo/Redo, and MSone enabled/disabled settings acceptance |
| Project Settings (encoding, media, secondary subs) | Wired in DS5 R10 to existing `ProjectSettingsSheet`, repository models and live media/secondary/history refresh after close | Native encoding selection/Save As, media unlink/replace, secondary clear, project rename, marked lines and route-return acceptance |
| App Settings, theme, typography, waveform limits, checkpoints | Wired to **existing** `SettingsSheet` in DS5 R5f | Verify immediate preference propagation and skin changes |
| Help & Documentation | Wired to **existing** `HelpScreen` in DS5 R5f | Navigation/back-stack widget and native acceptance |
| Desktop shortcuts | DS5 R17 manager: play/pause, previous/next cue+seek, Go to Line, find, mark/comment draft, split/combine, Save/Save As/Project, Help/Settings. DS5 R19: fullscreen, guarded Shift+Delete, Edit current cue, Show Marked Lines. Copy, Undo/Redo use focus-aware Flutter shortcuts | **Partial remaining hotkey parity:** line-format Bold/Italic, color picker, dictionaries, repeat/range playback, paste original; actual native chord registration, editor focus and conflicting OS bindings |

## DS5 R19 source-level difference audit

Compared the mobile main/selection menu and hotkey actions against Studio
Dock's native menubar, shared services, and player controls:

- **Wired (UI action parity)**: save/Save As/.msone, import/open/new, Edit
  Mode/Translation Mode, Project and App Settings, history, Source View,
  Go to Line, find/replace, marked/review filters, comments import, sync,
  MSone tools and submission, hearing-impaired cleanup, secondary subtitle
  controls, selected cue actions, waveform editing, media seek/playback,
  subtitle fullscreen, and Help.
- **Alternative route requiring native acceptance**: mobile Unload Video uses
  Project Settings for media unlink; mobile Show Marked Lines is a dedicated
  sheet while Studio Dock uses the grid review filters and shortcut. This is
  an interaction difference, not verified identical behavior.
- **Open implementation audit**: direct Generate/Regenerate/Hide Waveform,
  floating playback controls, video repeat/range controls and corresponding
  hotkeys, line-format/dictionary/paste-original hotkeys, and context menu
  feature visibility. Do **not** silently mark these complete.
- **Platform-only remaining**: native fullscreen media focus, video/track
  picker behavior, timecode/encoding round trips, player/waveform stability,
  keyboard chord conflicts and all documented platform acceptance checks.

## DS5 R5f implementation scope

- Replace inert native desktop menu labels with actual actions for existing
  editor functions. Routes do not recreate editing repositories or state.
- Host the actual shared App Settings and Help surfaces through the live
  desktop session; keep dirty cue drafts in place while opening Settings.
- Expose the same selected-subtitle text-copy format as mobile (effective
  edited text, blank line between cues), and Select All Visible.
- Keep demo/non-live routes from advertising production callbacks they cannot
  execute. Add widget regression tests and Flutter-only CI.

## Next acceptance order (not optional feature cuts)

1. **P0 implementation + native acceptance:** Close repeat/dictionary/format
   shortcut and floating player controls gaps after R20 waveform commands;
   validate waveform time drags, cue creation,
   magnet snap, overlap, selected-cue scrolling and secondary-subtitle
   persistence/playback on a native desktop before declaring playback parity.
2. **P1:** Verify synchronization and import comments, Go to Line, selected-cue batch operations and the
   now-wired Project Settings on native desktop when available.
3. **P2:** Verify native MSone banners/normalization and DS5 R18 fullscreen
   review callbacks, desktop hotkey chords/conflicts, theme/accessibility and media QA.

Keep this ledger current after each checkpoint. Studio Dock must not be called
"feature-parity complete" while any missing/partial row remains.
