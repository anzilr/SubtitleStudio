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
| Create/open project, SRT/.msone only | DS7 R23–R27: reviewed .msone import, SRT options, optional project save, extraction and new-project options are wired | Verify native file associations and reopened projects; VTT/ASS/SSA editing is future work |
| Save, Save As, SRT export, complete .msone project save | Wired to shared services | Native filename/encoding/round-trip acceptance |
| Edit Mode (create subtitles from scratch) vs Translation Mode | Wired in DS5 R6 | Native mode-dependent inspector, cue insert/split, Source View and SRT export acceptance |
| Video attach/unload, playback, fullscreen, repeat | DS5 R19 adds View → Toggle video fullscreen and the existing F11/Cmd+F manager action on the mounted player. DS5 R22 adds current-cue/custom-range repeat (View, fullscreen and shared hotkeys) with mobile-equivalent lead/tail timing and player-attachment guards. DS5 R25 adds direct View → Unload video through the existing repository, with cancel/failure preserving media and successful unlink detaching the existing surface. Shared `VideoPlayerSection` / `VideoPlayerWidget` remains the only native player | Native fullscreen keyboard/menu, attach/unload/replace, repeat boundary accuracy, playback/seek, OS hotkey conflict and dialog acceptance |
| Playback-follow subtitle highlight and seek | Wired through shared playback link | Native bidirectional seek/scroll/accuracy acceptance |
| Waveform display and selected audio stream | DS5 R20 adds direct Generate/Hide and Regenerate controls using the scoped Riverpod controller, PCM-cache invalidation and player-resolved audio selector; waveform zoom/time editing remain. DS5 R21 exposes the mobile-style optional floating play/pause button through View using the existing playback link, with focus-safe live state and no player remount. **Compact peak-cache regeneration and native floating transport still require verification** | Native waveform generate/regenerate/hide/show, selected-track fidelity, cached/uncached paths, player non-remount, floating-controls verification |
| Waveform gesture time edits and insertion | Wired in DS5 R9: shared waveform gestures and compact controls call guarded Studio Dock timing/insert services; successful edits reconcile the grid/player and history | Native drag precision, magnet/overlap behavior, cue creation, undo, media stability and synchronized scrolling acceptance |
| Secondary subtitles, visibility and saved selection | Wired in DS5 R8 through the existing secondary sheet, `VideoRepository` preferences, and shared player; original-text overlay reprojects from current cues | Native external/video-track picker, original-text updates and selection persistence acceptance; Project Settings remains separate |
| Edit text, start/end timing, formatting, nine-grid alignment | Wired to shared repositories and format tags; DS5 R23 adds selection-aware Bold/Italic via the existing formatting helper, a shared color dialog, and draft-first Paste Original | Native editor/controller focus and selection interaction acceptance |
| Cue insert, delete, split and combine | Wired, guarded, undoable | Compare edge cases and keyboard semantics with mobile |
| History graph, checkpoints, undo/redo/forks | Wired to shared graph/repository | Native path/bookmark navigation acceptance |
| Find/replace and raw Source View | Wired to shared tools/parser | Compare regex/case/selection semantics and file fidelity |
| Marked lines, comments, resolve/reopen and filters | DS5 R18 extends the existing shared fullscreen player: mark/unmark and atomic mark+comment editing route to the desktop Notes checkpoint service; desktop-only Resolve/Reopen button, optimistic draft guard, refreshed player overlays (including comment-only/resolved changes), and unchanged mobile fullscreen defaults | Windows fullscreen mark/comment/Delete/Resolve/Reopen, OverlayEntry focus, Undo/Redo, repeated media transitions, unsaved-draft cancel acceptance |
| Copy selected subtitle text, select all visible | Wired in DS5 R5f using mobile copy format | Clipboard and multi-selection widget acceptance |
| Shift/delete selected cues, select by index/range | Wired in DS5 R11: index/range and pointer/keyboard multi-select, mobile-style selected timing stretch with duration preservation, guarded single-checkpoint multi-delete. DS5 R24 also exposes all four actions through right-click, preserving or replacing the clicked row selection safely | Native selection, source edits, long-project scrolling, mixed selections and undo/redo acceptance |
| Go to Line and direct video seek | Wired in DS5 R12 to the Edit menu, grid, and shared `gotoLine` hotkey: 1-based input/slider, unsaved-draft guard, scroll-to-cue and attached-player start +50 ms | Native large-project keyboard input, slider, focus and seek-accuracy acceptance |
| Import comments from .msone project files | Wired in DS5 R13 to existing `ImportCommentsSheet`, `ProjectCommentImportPlan` and shared checkpoint-backed `ProjectCommentRepository`; successful imports refresh live cues, selected rows and history | Native .msone picker, match counts, Cancel, changed marking/resolution, Undo/Redo, narrow dialog acceptance |
| Subtitle synchronization | Wired in DS5 R15: first/last proportional anchors (durations preserved), positive/negative millisecond shift, selected-cue stretch, and video-gated framerate conversion (both bounds scaled); optimistic single-checkpoint history saves with canonical SRT range validation | Windows native video FPS detection, actual file sync, precision, selection consistency and Undo/Redo acceptance |
| Remove hearing-impaired annotations | Wired in DS5 R14 to the shared `HearingImpairedCleanupService` through a dirty-draft guard and source-snapshot preflight; after the checkpoint transaction Studio Dock reloads all cues | Windows real-file cleanup, cue deletions, translated text preservation, Undo/Redo acceptance |
| MSone submission (Existing Translator/Fresher, .msone or SRT pair) | Wired in DS5 R7 to the existing submission flow; shown only when MSone features are enabled | Native picker, completed form and route-return acceptance; never submit test data to the live endpoint |
| MSone banners and Malayalam Normalize | Wired in DS5 R16 to the existing mobile BannerConfigurationSheet and MalayalamNormalizationSheet with persisted MSone-feature gating, Tools menu/panel actions, popup/dirty-draft safeguards and shared history refresh | Native banner timing/overlap/edit, Malayalam preview selections, Cancel, Undo/Redo, and MSone enabled/disabled settings acceptance |
| Project Settings (encoding, media, secondary subs) | Wired in DS5 R10 to existing `ProjectSettingsSheet`, repository models and live media/secondary/history refresh after close | Native encoding selection/Save As, media unlink/replace, secondary clear, project rename, marked lines and route-return acceptance |
| App Settings, theme, typography, waveform limits, checkpoints | Wired to **existing** `SettingsSheet` in DS5 R5f | Verify immediate preference propagation and skin changes |
| Help & Documentation | Wired to **existing** `HelpScreen` in DS5 R5f | Navigation/back-stack widget and native acceptance |
| Desktop shortcuts | DS5 R17 manager: play/pause, previous/next cue+seek, Go to Line, find, mark/comment draft, split/combine, Save/Save As/Project, Help/Settings. DS5 R19: fullscreen, guarded Shift+Delete, Edit current cue, Show Marked Lines. DS5 R22: repeat current (Ctrl/Cmd+R) and custom range (Ctrl/Cmd+Shift+R). DS5 R23: Bold/Italic, color picker, MSone/Olam/Urban dictionaries and Translation Mode Paste Original wired to shared manager; editing commands guard non-cue fields and modal routes, draft changes require Apply. DS5 R24: right-click command parity for selected-cue batch operations, edit/insert/split/combine and review; Copy and Undo/Redo retain Flutter focus-aware shortcuts | Native key-chord registration, dictionary response/select, timecode/search focus, clipboard conflict and popup acceptance |

## DS5 R19 source-level difference audit

Compared the mobile main/selection menu and hotkey actions against Studio
Dock's native menubar, shared services, and player controls:

- **Wired (UI action parity)**: save/Save As/.msone, import/open/new, Edit
  Mode/Translation Mode, Project and App Settings, history, Source View,
  Go to Line, find/replace, marked/review filters, comments import, sync,
  MSone tools and submission, hearing-impaired cleanup, secondary subtitle
  controls, selected cue actions, waveform editing, media seek/playback,
  subtitle fullscreen, and Help.
- **Alternative route requiring native acceptance**: R25 closes direct mobile
  Unload Video access in desktop View (Project Settings remains another path).
  Mobile Show Marked Lines is a dedicated sheet while Studio Dock uses the
  grid review filters and shortcut. This is an interaction difference, not
  verified identical behavior.
- **Open implementation audit**: R20 added waveform Generate/Regenerate/Hide;
  R21 added optional floating play/pause; R22 added repeat current/custom
  range on the existing player with shared mobile dialog; R23 wires the
  formatting/dictionary/Paste Original hotkeys into the shared draft path.
  R24 adds the mobile multi-selection commands and per-cue actions to the
  desktop right-click menu. R25 adds direct saved-video unlink with draft and
  media safety guards. **R26 wires** mobile Edit Line's original fallback,
  navigation-save and original-field toggles through the shared Isar settings,
  adds a transient formatted preview, and keeps the original/edited desktop
  grid intact. Auto-save uses the existing checkpoint-backed Apply, never
  copies an untouched original fallback into persisted edited text; notes,
  media and project transitions retain their explicit draft guards. These
  behaviors still require native Windows acceptance.
  Native loop behavior, actual OS chord handling,
  dictionary provider selection and pointer context menu behavior are not
  accepted. Do **not** mark these native behaviors complete.
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

1. **P0 implementation + native acceptance:** Validate R23 dictionary/format/
   paste-original focus and selection on desktop, then exercise the R24
   context-menu actions and R25 direct Unload Video on real desktop input.
   Validate waveform time drags, cue creation,
   magnet snap, overlap, selected-cue scrolling and secondary-subtitle
   persistence/playback on a native desktop before declaring playback parity.
2. **P1:** Verify synchronization and import comments, Go to Line, selected-cue batch operations and the
   now-wired Project Settings on native desktop when available.
3. **P2:** Verify native MSone banners/normalization and DS5 R18 fullscreen
   review callbacks, desktop hotkey chords/conflicts, theme/accessibility and media QA.

Keep this ledger current after each checkpoint. Studio Dock must not be called
"feature-parity complete" while any missing/partial row remains.

## DS7 parity verification update — 2026-10-31

This dated update supersedes the older wording above where subsequent DS7 R19–R27
checkpoints closed source-level gaps. **Source parity and native acceptance are
different states.** All checked import/edit/export routes operate on SRT or
portable .msone projects; ASS/SSA/VTT editing and conversion remain future work.

| Mobile capability / desktop route | Current source/test evidence | Native acceptance |
| --- | --- | --- |
| Open/import SRT; encoding preview, hearing-impaired cleanup, overlap merge, optional .msone save | DS7 R21, R22, R26; SRT dialog, import and on-disk repository tests | **Pending** real file pickers, charset fixtures and Cancel/no-write checks |
| Import .msone as new or replace; source relink and history-fallback choice | DS7 R23; project plan, dialog and atomic repository tests | **Pending** actual archive/replacement and history-recovery paths |
| New Edit Mode project; encoding and optional initial SRT/.msone locations | DS7 R27; dialog and create-to-reopen integration tests | **Pending** native Save As locations and cancel paths |
| Save SRT, Save As (relink) and Export SRT (copy) with original/edited track, encoding and tag | DS7 R24; file actions, export dialog, stale/overwrite guards and on-disk tests | **Pending** native path selection, export/reopen and Windows file association |
| Reopen the last selected project and subtitle line | SessionRepository and DS7 R17; rapid-reopen queued-write regression added in c210255 | **Pending** actual desktop app restart and immediate project switching |
| Extract embedded text subtitles from video | DS7 R25; shared mobile extraction sheet, desktop navigation/widget and codec-filter tests | **Pending** real video with multiple text/bitmap subtitle tracks and FFmpeg availability |
| Video playback, fullscreen, repeat, secondary subtitles and synchronized list/waveform | DS5 R18–R25; shared player/repositories and desktop media/widget tests | **Pending** interactive seek/drag/track switching and runtime-error inspection |
| Text/timing/formatting, inserts/splits/combines, multi-selection, context menu and keyboard commands | DS5 R11–R26; command palette, hotkey, inspector, context-menu and service tests | **Pending** physical keyboard modifiers, focus/shortcuts and pointer acceptance |
| Marked/resolved lines, effects, Edit History, Source View, search/replace and quality review | Shared services; graph, effect-grapheme, notes/history/source/quality tests | **Pending** real documents and desktop gesture/undo acceptance |
| App/Project Settings, Help, dictionaries and MSone submission | Shared mobile surfaces and desktop wiring tests; MSone gated by settings | **Pending** native dialog focus, route return and optional account/network flows; do not send test submissions to production |

### Native Windows acceptance pass (operator checklist)

Use a disposable test project and copies of source media. Record PASS/FAIL,
OS, Flutter build mode, exact steps, and Debug Console logs for any failure.
Do not use live MSone submission accounts for test payloads.

- [ ] Open a UTF-8 SRT and a Windows-1252 SRT. Verify preview, encoding override,
      import-time toggles, Cancel/no-write and the expected unchanged source bytes.
- [ ] Create a new Edit Mode project with each file-location choice; reopen
      the saved SRT and .msone, then check subtitle text, timing and encoding.
- [ ] Import a complete .msone as new and replace an existing project; try
      archived/located/unlinked SRT options and incompatible-history recovery.
- [ ] Save, Save As (switch working file), Export SRT (separate copy), restart,
      and confirm both the linked source and last edited line survive.
- [ ] Attach video, select an audio track, generate/regenerate waveform,
      zoom to a 4–5 s window, drag start/end and verify cursor/list/video sync.
- [ ] Check repeat current/custom range, fullscreen, secondary subtitles,
      original text overlay, floating transport and media unload/reload.
- [ ] Extract text subtitles from a real video; verify bitmap-only streams
      are not offered, select a text track, and reopen the extracted SRT.
- [ ] Exercise keyboard navigation, Shift+Enter focus, shortcut toggle-close,
      right-click multi-selection, mark/resolve, undo/redo and history branches.
- [ ] Test App and Project Settings, dictionaries, Source View, comments,
      effects (including Malayalam graphemes), and modal focus/escape behavior.

### Automated evidence at this checkpoint

- Local Flutter analysis: **0 issues** (2026-10-31).
- Local Flutter test suite: **1,299 passed** (2026-10-31) with
  `flutter test --concurrency=4`, including desktop rapid-reopen cursor and
  newly added FFmpeg dependency-message regressions. The default-concurrency
  run stalled without a failure summary; its last active inspector test also
  passed in isolation (19/19).
- Latest-source native Windows Release startup: **PASS** on 2026-10-31
  with `flutter run -d windows --release` (197.8 s build). The process
  initialized Impeller, FFmpegKit, MediaKit, Isar and registered the desktop
  hotkeys. No startup exception was logged. Interaction checks remain
  **pending** until completed on actual mouse, keyboard and media fixtures.
- Windows extraction now detects the backend's current missing FFmpeg/FFprobe
  signature and offers bundled-installer repair guidance; Linux directs the
  user to PATH-installed tools. This is source/test verified, not real-video
  extraction acceptance.
- Platform builds must remain local, never in GitHub Actions.
