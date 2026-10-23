# SubtitleStudio — Studio Dock v1 Implementation Design Specification

**Date:** 23 October 2026  
**Status:** Design baseline locked; implementation not started  
**Design branch:** `feature/desktop-workspace-preview`  
**Production branch:** `refactor/riverpod-architecture`

## 1. Locked product decisions

Studio Dock is SubtitleStudio's PC-first single-window editing workspace, not an enlarged mobile layout. Preserve the existing isolated desktop prototype and reuse shared Riverpod, Isar, media, encoding, file and checkpoint services when production integration begins.

The following user decisions are final for v1:

- **Center dock vertical proportions:** 43% Video, 13% Waveform, 44% Subtitle Grid, calculated from usable center height after the top commands and status bar. The video band includes transport controls.
- **Right inspector:** tabbed **Text / Timing / Style / Notes**.
- **Subtitle grid:** **Original and Edited side by side** by default.
- Mobile layouts and the frozen four skin families remain unaffected. No unrestricted drag-to-redock system in v1.

## 2. Window composition

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ File  Edit  Subtitle  Timing  Tools  View  Help                         ☐ × │
├──────────────────────────────────────────────────────────────────────────────┤
│ [Project] ●unsaved       [Save] [Undo] [Redo]   [Find] [⌘ Actions] [Panels] │
├──────┬───────────────┬───────────────────────────────────────┬───────────────┤
│ ICON │ EXPLORER      │ VIDEO (43%)                           │ INSPECTOR     │
│ RAIL │ project tree  │ aspect-preserved frame + subtitle     │ Text | Timing │
│      │ primary SRT   │ playback/step/current time            │ Style | Notes │
│      │ secondary SRT ├───────────────────────────────────────┤               │
│      │ media         │ WAVEFORM (13%)                        │ current cue   │
│      │ versions      │ ruler / cursor / cue boundaries       │ draft actions │
│      │ bookmarks     ├───────────────────────────────────────┤               │
│      │               │ GRID (44%)                            │               │
│      │               │ # Start End Dur Original | Edited     │               │
│      │               │ selectable, editable, virtualized     │               │
├──────┴───────────────┴───────────────────────────────────────┴───────────────┤
│ Save status · cue count · encoding · media time · background operations      │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Proposed initial dimensions (Flutter logical pixels)

| Region | Initial size | Constraints |
| --- | --- | --- |
| Navigation rail | 56 px | Fixed; tooltips and focus |
| Explorer | 240 px | Resizable 200–340 px; collapsible |
| Inspector | 320 px | Resizable 280–440 px; collapsible |
| Status bar | 28 px | Always visible |
| Command strip | 44–48 px | Compact; overflow into menu |
| Video dock | 43% | Minimum 200 px including transport |
| Waveform dock | 13% | Minimum 96 px |
| Subtitle grid dock | 44% | Minimum 180 px |

Percentages apply until constrained. A deterministic minimum-size solver clamps panel dimensions and distributes remaining available space; it must not yield overflow or a clipped video transport. Video retains aspect ratio with letterboxing, never cropping.

**Breakpoints (design targets, not fixed device pixels):** ≥1600 px: explorer and inspector both visible; 1250–1599 px: inspector visible, explorer collapsed by default; <1250 px: secondary panels open as dismissible side overlays so the center remains usable. Test at 1366×768 and 1920×1080, 2560×1440, a 1024 px-wide resized window, 125% scaling and larger accessibility text. A narrow height should allow focus/maximize on one center band without hiding essential controls.

Dragging splitters changes layout immediately; persistence is debounced and flushed at close. Double-click restores the corresponding default ratio. **View → Reset Workspace** restores all defaults. Pane layout is desktop-local preference state, never serialized to `.msone` or subtitle history.

## 3. Interaction ownership — avoid seek loops

Distinguish: **focused grid row**, **selected row(s)**, **actively playing subtitle**, **playhead/media time**, and **unsaved inspector draft**. They may reference different cues. Selection must not secretly mutate media position or persisted project data.

| Interaction | Selection and editor effect | Media seek? |
| --- | --- | --- |
| Single click grid row | Select it, reflect in inspector and highlight waveform segment | **No** |
| Keyboard Up/Down in grid | Move focus/selection | **No** |
| Ctrl+click / Shift+click | Multi-select or range-select | **No** |
| Double-click Edited cell / F2 | Inline edit | **No** |
| Double-click a timecode / explicit Go to cue | Navigate to start/end | **One explicit seek** |
| Click waveform time ruler | Move playhead intentionally | **One coordinated seek** |
| Drag waveform while paused | Visually move immediately | **One seek on release** |
| Drag waveform while playing | Preview rate-limited | **Bounded seeks, then final** |
| Scroll, hover, resize or change inspector tab | No edit or media side effect | **No** |

Reuse the CP93 R4/R5 stable waveform seek coordinator, first/end visual padding and shared timecode pointer semantics. A stale native position callback cannot override an active manual scrub. Playback subtitle highlights must never feed back into native seek requests.

## 4. Subtitle grid

Default columns: **# | Start | End | Duration | Original | Edited | Status**. Original and Edited consume the majority of flexible width, with independent minimums; preserve full millisecond precision and tabular digits for timestamps. Rows default approximately 36–40 px high, with optional multiline expansion. Rendering should be virtualized for large projects.

- Single click focuses/selects; double-click Edited (or F2) edits; Enter begins editing when grid owns focus.
- Shift+arrow extends range; Ctrl+click toggles discontiguous selection; Escape exits an edit after respecting dirty-draft rules.
- Context menu: Edit, Copy timecodes, Set Start/End from playhead, Add Before/After, Split, Merge, Delete, Mark, Comment and Go to Time. Disable invalid actions with a reason. All mutations use existing transactional undo/checkpoint commands.
- Filters/search/sort change only the *view*; never reindex persistent cue identities or reorder exported SRT merely because a column was sorted.
- Active playback cue, keyboard focus, selected rows and marked/edited state must be visually distinct without relying solely on color.
- Grid should preserve the original text even when Edited is empty or replaced; blank cues and newline semantics must remain intact.

## 5. Right inspector

Four tabs share one **per-cue draft controller** and a stable active cue identity.

**Text:** read-only Original, editable Edited, multiline/IME composition, plain-text copy and existing normalization/formatting operations.

**Timing:** Start, End, Duration, frame stepping when frame rate is known, waveform playhead insertion, validity checks (nonnegative, end after start, supported bounds). Millisecond-precise representation.

**Style:** Existing supported subtitle formatting/color/alignment/tag tools; actions not supported by the actual SRT/model are disabled rather than simulated.

**Notes:** Existing comments, marks, bookmarks/review metadata applicable to the cue. Do not invent persisted fields.

Switching tabs, resizing or opening a tool **does not discard a draft**. Switching cues with a dirty draft prompts Apply / Discard / Cancel in a desktop dialog. Failed apply preserves the draft and shows actionable, non-path-leaking error text. Applying a cue draft writes through the existing shared edit transaction and creates undo/checkpoint state according to current rules; **Ctrl+S** saves the project/file via its normal destination and encoding pathway, and is a distinct operation. Window/project close uses a desktop unsaved-changes dialog.

Multi-selection shows shared/batch tools and selection count; do not misrepresent one cue as the whole multi-selection.

## 6. Menu, shortcuts and focus

Menu bar: **File, Edit, Subtitle, Timing, Tools, View, Help**. Toolbar includes only high-frequency commands; advanced tools belong to menus, command palette and accessible rail.

| Shortcut | Action | Scope |
| --- | --- | --- |
| Ctrl+O | Open | Desktop native picker |
| Ctrl+S | Save | Document persistence, not just inspector draft |
| Ctrl+Shift+S | Save As | Cancel ≠ success |
| Ctrl+Z / Ctrl+Y | Undo / Redo | Active text field undo first, otherwise shared editor |
| Ctrl+F | Find | Focus search |
| Ctrl+K | Command palette | Global outside conflicting text-input shortcuts |
| Space | Play / Pause | Only when no editable control has focus |
| Up / Down | Navigate cues | Grid-focused only |
| Shift+Up / Down | Extend selection | Grid-focused only |
| F2 / Enter | Edit cue | Grid-focused only |
| Ctrl+Enter | Apply inspector draft | Inspector-focused only |
| Escape | Dismiss menu/exit edit | Never silently lose dirty draft |

Provide visible keyboard focus, screen-reader labels, high contrast on all existing skins, non-color-only state, tooltips and usable pointer targets. Preserve the established Carbon Zero default plus Carbon & Jade, Copper Cinema, Aster Violet, each with Light/Dark/Classic support, using semantic theme tokens. Avoid reintroducing fixed accent colors.

## 7. Project, history, Source View, and background operations

Explorer includes current project, primary/secondary subtitle sources, video, attachments, and versions/bookmarks when actually present. File names may display in the UI but must not leak into logs. History opens in an accessible dock/view with graph/list options, plain-language history labels and existing guarded branch/bookmark transactions. Source View is a desktop pane/view using the shared charset/BOM/newline and file access service. Native desktop dialogs handle open/save; preserve SAF and macOS bookmark rules in the shared backend.

Long import/export/FFmpeg/waveform jobs show bounded activity in a compact status surface, with cancellation and typed error reporting when available. No blocking fullscreen spinner for routine nonblocking work.

## 8. Architecture and implementation boundaries

The currently isolated entrypoint `lib/main_desktop_preview.dart` uses sample cues and a simulated waveform/player. Keep it **explicitly demo-only** until production integration. Introduce a separate desktop presentation shell; do **not** duplicate Isar collections, Riverpod domain controllers, media engine, file-service logic, encoding rules, or checkpoint semantics. Keep exactly one authoritative player/video widget owner; resizing and panel toggles must not recreate native media or mount a duplicate GlobalKey.

- **DS1 — Visual shell** on preview branch: implement 43:13:44 dock, splitter constraints, tabbed inspector, two text columns, command strip, grid and responsive breakpoints using demo data.
- **DS2 — Interaction prototype:** multi-select, keyboard focus, context menus, command palette, draft state and pane-persistence adapter. Still demo-only.
- **DS3 — Shared editor integration** following CP93 acceptance: bind real sessions, cue list, drafts, transactions, Undo/Redo; no mobile layout modifications.
- **DS4 — Media/waveform integration:** connect the shared `media_kit` ownership and waveform, verify seek/throttle/edge behaviors and lifetime.
- **DS5 — Project integrations:** file pickers, save/export, Source View, history, comments and tool panels via shared services.
- **DS6 — Native desktop acceptance:** Windows first, then Linux/macOS where available, including high-DPI, files with thousands of cues, keyboard/IME, native playback and compatibility round trips.

All CI remains **`flutter pub get`, `flutter analyze`, `flutter test`** (no Android/Windows/macOS/Linux/iOS application builds in GitHub Actions). Native builds and smoke checks run on actual hosts.

## 9. Acceptance checklist

- [ ] At typical desktop resolution the vertical bands resolve to the selected **43/13/44** split.
- [ ] Inspector has exactly **Text, Timing, Style, Notes** tabs; changing tab does not destroy a draft.
- [ ] Grid defaults to **Original + Edited side by side**, with persistent column widths and intact cue identity.
- [ ] Single click or scroll in grid causes **zero unintended native seeks**; an explicit seek targets the correct millisecond.
- [ ] Paused waveform scrub remains responsive/accurate with one final seek, including start/end edges.
- [ ] Pane resize, collapse/expand and skin change do not recreate media or lose draft/focus.
- [ ] Saving, cancelling, reopening and .msone/SRT round trips preserve original text, blank cues, encoding and history.
- [ ] All features reachable within one window via menus, rail and panels; no mobile bottom sheets.
- [ ] 1366×768 / 1920×1080 / 2560×1440 and high-DPI accessibility checks do not overflow.
- [ ] All Flutter checks green; **native acceptance independently recorded**.

## 10. Deliberately deferred

Arbitrary dock reparenting/multiwindow workspace composition; new domain schemas; waveform algorithm experiments; skin designer; changes to mobile screen layout; claiming production acceptance based solely on the demo preview.

**Design outcome:** approved foundation and exact layout/inspector/grid choices are locked. Remaining values above are implementation defaults to refine through visual prototype testing without reopening the locked decisions.
