# SubtitleStudio desktop workspace — source reuse audit

Date: 2026-10-12
Branch: `refactor/riverpod-architecture`
Checkpoint baseline: 61 R2 (`e42b411`, 209 tests passed, analyzer clean).
Scope: source-level architecture evaluation, **not** a desktop implementation or native-runtime verification.

## Verdict

**The business logic and much of the editing state are reusable. The existing desktop
screen composition is not yet PC-first.** Rebuild the desktop *shell* and dense subtitle
grid while retaining the same session-scoped Riverpod providers, mutation repositories,
subtitle models, player/waveform primitives, and history engine. Do **not** fork
financial/data/editing logic or duplicate Isar repositories for desktop.

A desktop replacement must not reuse the entire `EditScreen` with its current
two-pane layout: `lib/screens/edit/parts/edit_responsive_layout.dart` chooses
a `ResizableSplitView` of list vs video. Other behavior/UI remains attached
to the private `_EditScreenState` through `part` extensions.

## Reuse matrix

| Component / source | Reuse decision | Evidence and boundary |
| --- | --- | --- |
| `EditConfiguration`, `editControllerProvider`, `EditState` | **Reuse directly** | `lib/screens/edit/edit_controller.dart` scopes session + collection, initializes subtitle/video state, provides edit operations, and avoids widget-oriented persistence |
| `EditScreenHost` | **Reuse the provider/initialization pattern, NOT its final child** | `lib/screens/edit/edit_screen_host.dart` overrides `EditConfiguration`, watches the controller, then always renders `legacy.EditScreen` |
| `SubtitleRepository`, `EditLineRepository`, `CheckpointHistoryTransaction` | **Reuse directly** | session-scoped atomic V2 editing paths; desktop commands must call the same endpoints |
| `SourceViewReconciler`, `CheckpointStateReducer`, history validator/hash/reconstruction, project codec | **Reuse directly** | UI-independent pure logic/services, shared by all platforms |
| `VideoPlayerSection` and player controls | **Reuse with adapters** | `lib/screens/edit/widgets/editor_video_pane.dart` has explicit callbacks and composes player + waveform; no desktop player rewrite needed |
| `WaveformWidget` | **Reuse rendering/controller; extract docking and toolbar behavior** | `lib/features/waveform/widgets/waveform_widget.dart` accepts subtitles, playbackPosition, onSeek, session IDs, and highlight callbacks; controller still uses dispatch compatibility layer |
| `SourceViewPane` | **Reuse with sizing/selection improvements** | independently exported StatelessWidget in `lib/screens/edit/widgets/source_view_pane.dart`, provided entries + scroll controller + onChanged; current entries are parent-owned |
| `SubtitleCard` | **Keep mobile; do not use as desktop table row** | `lib/screens/edit/widgets/subtitle_card.dart` has many tap/selection callbacks and a card visual layout; PC needs compact, sortable, keyboard-navigable virtualized grid rows |
| `CheckpointSheet` | **Reuse repository, replace desktop visualization** | `lib/widgets/checkpoint_sheet.dart` includes mobile modal interaction and linear timeline; named branches/tree graph is a later checkpoint |
| `ResizableSplitView`, `ResponsiveBuilder` | **Reuse concept/helper, build independent dock layout** | `lib/utils/responsive_layout.dart` supports breakpoints/resizable panels; current desktop decision also enables large mobile tablets |
| Modal tool sheets, menus, shortcut wiring | **Refactor actions from presentations** | `lib/screens/edit/parts/edit_menu_actions.dart`, `edit_tool_sheets.dart`, and `edit_main_menu.dart` open bottom sheets/menus and bind private `_EditScreenState` |
| `ProjectCommentRepository`, normalization, sync and waveform operations | **Reuse the same V2 APIs** | checkpoint 61/62 history-safe operations are platform-neutral; both desktop and mobile must share them |

## Proposed PC-first composition

```text
DesktopEditorHost (Windows/Linux/macOS only)
  session ProviderScope + EditController (SHARED)
  ├─ Project rail: sessions / file / import / export / search
  ├─ DesktopCommandBar: same actions + desktop shortcuts
  ├─ SubtitleDataGrid: virtualized rows, original + edited, timestamps, selection
  ├─ MediaDock: VideoPlayerSection + WaveformWidget (existing primitives)
  ├─ InspectorDock: selected cue editor, comments, marks, style, AI
  ├─ HistoryDock: later true branch graph / HEAD / bookmarks
  └─ StatusBar: save status, counts, selected cue, encoding
MobileEditorHost
  session ProviderScope + EditController (SHARED)
  └─ EXISTING EditScreen / existing mobile widgets (unchanged)
```

This means **all functions/features are reachable from one desktop window**, not
that every form/menu must remain simultaneously open. Offer keyboard command
palette, toolbars, tabs and optional dock panes; avoid a crowded always-open
six-panel layout. The core video, waveform, table and inspector should fit on
one 1080p-class screen. Preserve ratios and visibility as **desktop-only**
preferences.

## Required architecture changes before building this UI

1. **Separate workspace logic from private widget state.** Review `_EditScreenState`
   callbacks for seek, selection, source-view buffer, line edits, file actions,
   save and history. Promote reusable workflows into injected controller/action
   services with explicit typed inputs/outputs, not BuildContext or widget keys.
2. **Introduce a new desktop shell rather than extending split-screen logic.**
   Select it on actual desktop platforms (Windows/macOS/Linux); do not replace
   `ResponsiveLayout.shouldUseDesktopLayout` wholesale, since that currently
   also affects landscape tablets. Keep mobile screen routes untouched.
3. **Reuse scoped providers without double initialization.** Extract the session
   provider scope and initialization gate from `EditScreenHost`, or introduce a
   desktop peer with one equivalent nested ProviderScope. Never embed a second
   `EditScreenHost` inside a dock.
4. **Extract presentation-independent commands** (add/split/merge/shift/sync,
   normalization, project save, import, export, checkpoint) so both the
   desktop toolbar/keyboard shortcuts and mobile sheets invoke the same action.
5. **Add desktop-specific view models**, e.g. selected cue, multi-select, column
   visibility, dock sizes and focus state. Do not store window docking in subtitle
   documents or mix it with undo history.
6. **Constrain the performance budget.** Use lazy/virtualized table rows,
   selective Riverpod subscriptions, bounded waveform redraws and
   single-owner video controllers. Avoid observing the entire Editor state in
   every row.
7. **Preserve platform capability checks.** `ResponsiveLayout.isDesktopPlatform()`
   currently treats web as desktop; **web is not an approved desktop runtime**
   here because the current Isar stack is native. Do not assume browser storage
   works merely because it shares a screen width.

## Desktop-specific verification matrix

- Route-scoped ProviderScope: opening/editing two different sessions does not
  leak selection, undo or video state across windows/routes.
- Shared edit commands: a change made in desktop mode has the same .msone export,
  Isar history/undo/redo and playback results as mobile.
- Zero regressions in Android/iOS layouts and touch interaction.
- 1366×768 minimum, 1920×1080 standard, 2560×1440 high DPI and multi-monitor
  resizes; dock changes do not lose edits or recreate controllers.
- Keyboard shortcuts, IME/unicode/Malayalam entry, focus transfer to video,
  grid multi-selection, and seek-highlight synchronization.
- Optional docks/video absent, waveform absent, empty project, 100k-line
  sparse/large projects; no mandatory all-feature widget build on startup.
- Native Windows/Linux/macOS builds at the separate planned platform gate.

## Sequencing

Checkpoint 62: atomic bulk-edit migration + this reuse audit, no desktop UI change.
Next: finish tracing legacy raw writes and expose clean shared command services.
Then build desktop shell/table/inspector with shared providers, while mobile
keeps its existing responsive route; independently build graphical history
docking after HEAD/bookmark reference design is verified.

**Do not present the desktop mockups as currently implemented features**:
their dockable grid, inspector, branch graph, and project rail remain designs.
