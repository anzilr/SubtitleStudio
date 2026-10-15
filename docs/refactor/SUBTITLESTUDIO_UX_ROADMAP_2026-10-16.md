# SubtitleStudio UX roadmap — visual history, plain language, unified design, compact Edit Line

Date: 2026-10-16
Branch: `refactor/riverpod-architecture`
Status: **Approved roadmap requirements / proposed execution**, not implemented UI
Related: [Refactor roadmap v4](REFACTOR_ROADMAP_V4.md), [Checkpoint 72 mobile history](CHECKPOINT72_MOBILE_HISTORY_INTEGRATION.md), [Checkpoint 73 history safety](CHECKPOINT73_HISTORY_SAFETY_AND_SCALE.md), [Desktop reuse audit](DESKTOP_WORKSPACE_REUSE_AUDIT_2026-10-12.md).

## 0. Why this is needed and source audit

New user requirements:
1. A genuinely visual, usable checkpoint-history GUI, not only a list of technical commit cards.
2. Replace Git jargon with understandable labels and explanations for nontechnical subtitle editors.
3. Establish an exclusive, consistent SubtitleStudio visual language and palette across the app.
4. Reorganize the mobile Edit Line screen to be compact, productive and keyboard-friendly.

At this branch head, the history backend already provides an immutable `CheckpointHistoryGraph`, typed nodes, parent/child edges, current HEAD, attached branch, and named branch/bookmark references. `CheckpointHistoryPanel` still renders stacked cards, horizontal reference chips, and technical text including `HEAD`, `commit`, `detached`, `fork`, `branch`, and `checkout`. The classic checkpoint sheet is still available and has hardcoded orange/buttons.

`AppThemes` currently mixes several unrelated colors across light/dark/classic themes; editing widgets also specify additional hard-coded colors. The Edit Line layout uses a dense app bar, fixed-height (~100 px) original/edited text blocks, many inline actions, and differing mobile split-video modes. Most application state is already Riverpod-backed. **Do not rewrite repositories, checkpoint persistence, Media Kit or Isar to do UX work.**

The new visual system and copy are *not* part of the already completed 85 checkpoint fixes. The latest Android regression fixes, Project Settings encoding selector, and Riverpod disposal patch must be quality-gated before any large UI migration.

## 1. Product UX principles and guardrails

- Subtitle creation comes first: text editing, timings, playback, save, previous/next, comments and keyboard focus must remain one interaction away.
- Reduce visual noise through progressive disclosure, not by removing functions. Overflow, tool sheets, search, accessibility and keyboard shortcuts preserve less common operations.
- Design mobile portrait first, preserve fullscreen landscape video and editing-dialog round trips, then adapt to Android tablets and desktop independently.
- Use *one* semantic token system for all surfaces; allow light, dark and existing saved theme preferences during migration; never infer state from color alone.
- Plain language in visible UI; preserve `HEAD`, `refs/heads/*`, `checkpointId`, branch tips and all existing history transactional checks in the model, export and logs.
- No destructive rewrite or migration of Isar checkpoint records, ID, ancestry, branch references or portable `.msone` documents. History GUI consumes read-only view models and the same `HistoryGraphCommands`.
- Keep changes in `refactor/riverpod-architecture`; don't alter main/development/release tags. Scope UI refactors to isolated commits and run analyzer/tests at deliberate gates (about every 8–10 commits or after risky changes).

## 2. Studio design language — proposed brand direction

Working name: **SubtitleStudio / Frame & Cue**. Signature graphic: a tiny timeline tick + subtitle cue line, reused sparingly in navigation, history and waveform. Minimal, calm, precise, distinctly editing-oriented; no broad gradients or rainbow-coded toolbars.

### Draft semantic palette (review against actual Android screenshots before freezing tokens)

| Role | Light | Dark | Use |
| --- | --- | --- | --- |
| App background | `#F6F8FC` | `#111A2C` | Editing canvas and overall chrome |
| Raised/sheet surface | `#FFFFFF` | `#19243A` | Cards, dialogs, panels |
| Primary text | `#17223B` | `#EEF2FA` | Content, headings |
| Brand primary | `#5268D9` | `#A9B6FF` | Main actions, focus, active selection |
| Editing accent | `#188579` | `#62DBCA` | Playhead / positive editing highlights |
| Attention/unsaved | `#D99B37` | `#F2B85B` | Caution and important markers (not alone) |
| Error/danger | Material semantic `error` role | Material semantic `error` role | Failed save / destructive action |
| Outline/muted | ColorScheme outline variants | ColorScheme outline variants | Dividers, inactive controls |

Color accessibility rules: light primary `#5268D9` is intended for white text; dark primary `#A9B6FF` needs dark text, not white. The teal/amber highlight roles require contrast-aware foreground choices. Do not use these raw hex codes as scattered constants: create light/dark `ColorScheme` and a `ThemeExtension` for additional subtitle editor semantics (current cue, edited cue, waveform, graph lanes, marked cue, saved indicator). Verify WCAG contrast against all foreground/background pairs in tests.

### Token and component system

- `StudioColors` / `StudioThemeExtension`: only semantic roles, never numbered colors in feature widgets.
- `StudioSpacing`: 4/8/12/16/24/32; radius 8 inputs, 12 cards, 16 sheets; touch targets at least 48 logical px; icon sizes 20/24.
- `StudioTypography`: title, cue text, timestamp (tabular numbers), metadata, label, caption; Malayalam/Unicode, RTL and custom-font fallback testing.
- Core components: `StudioScaffold`, `StudioTopBar`, `StudioCard`, `StudioSectionHeader`, `StudioIconAction`, `StudioPrimaryButton`, `StudioSheet`, `StudioCueField`, `StudioTimeField`, `StudioStatusChip`, `StudioEmptyState`, `StudioConfirmDialog`.
- Centralize focus/error/disabled/loading treatment, snackbar/dialog styling, bottom sheets, selection, navigation and motion. Honor reduced-motion and large text.
- Keep light/dark/classic preference data and user-loaded fonts readable; avoid breaking older saved settings. Decide whether legacy Classic remains selectable after migration only after testing.

**Rollout order:** inventory/screenshots of Home, Edit, Edit Line, History, Project Settings, Import/Export, Source View, player/waveform and tools → implement tokens and component gallery → migrate one pilot surface (Edit Line or History) behind an opt-in internal flag → migrate all other surfaces in small batches → retire scattered constants and duplicated widgets after regressions pass.

## 3. History GUI — **Edit History / Version Map**

### Surface and interaction

- **Top:** `Edit history`, current version, short plain-language status, actions `Save version`, `Help`.
- **Tabs or segment:** `Timeline` (default on mobile) and `Version map` (branch lane visualization). Optional `All / Saved / Pinned` filters and search; default show recent without hiding older routes.
- **History rows:** short readable action title, relative/absolute time (accessible timestamp), icon, current/saved/pinned markers, preview/restore action. A compact left rail shows connected version nodes/paths; use color **and** different marker geometry/line style. Avoid displaying internal IDs as primary labels.
- **Branch map:** horizontal lanes only when alternative edit paths exist, with connecting curves and visible junctions; show a narrow horizontally scrollable lane area or adaptive full-screen viewer for large graphs. User selects a node to open a *details/action* sheet, not restore on single tap.
- **Details sheet:** version title, timestamp, what changed (only if actual data is available), named editing path, pinned labels; `Continue editing from this version`, `Pin this version`, `Create another editing path`. Implement an actual before/after subtitle diff **only after** there is a safe, lazy historical diff API; do not simulate it from operation description alone.
- **Restore flow:** confirmation explicitly states current editing location changes; existing alternate paths are retained subject to retention policy, that new edits may form another path, and unsaved changes must be resolved. Do not promise permanent retention of unreferenced history.
- **Progress/errors:** show loading, empty, corruption/inconsistent graph, stale revision, retries and cancellation gracefully. Guard against double submission and stale HEAD like the existing transactional UI.

### Rendering architecture

- Retain `CheckpointHistoryGraph`, `HistoryGraphNode` and `HistoryGraphCommands`; add a pure deterministic `HistoryLaneLayout` that accepts immutable graph data and returns positioned nodes/edges/labels.
- Use a small `CustomPainter` for **visible lane connectors** and lazily built rows/cards for text and tap targets. Compute lane positions once per graph revision, not on every frame; limit painter work to the viewport.
- Rows should have predictable heights; expand details in a separate sheet rather than making all graph rows expensive. Preserve scroll and selection across filter/map mode switches; provide a plain linear accessible list alternative.
- Test long branching histories (at least existing 2,501-node fixture), backdated timestamps, disconnected corrupt refs rejection, multiple names per node, refresh while scrolling, transaction conflicts, text scaling, RTL and screen readers.
- On desktop later, reuse layout algorithm but present it in a dock/panel; do not clone history business logic.

### Terminology changes (UI strings only)

| Existing technical term | Proposed default user label | Essential truthful meaning |
| --- | --- | --- |
| Checkpoint / commit | Version / saved change | A recorded editing state |
| HEAD | Current version | Version used for subsequent edits |
| Attached to branch | Editing on path `[name]` | Named path that advances with edits |
| Detached HEAD | Editing from an earlier version | This is an active editing position; new edits form a separate path until selecting a named path |
| Branch | Editing path | Alternate chain of versions |
| Fork / children | Other editing paths | More than one continuation from a version |
| Checkout commit | Continue editing from this version | Changes the active editing state; not a read-only preview |
| Switch branch | Switch editing path | Changes the active editing path/version |
| Bookmark | Pin version | A lightweight reference to existing data; not a backup copy |
| Create branch | Start another editing path | Named continuation/reference |
| Save Point (creates checkpoint) | Save version | Creates a new recorded history entry |
| Snapshot (full state) | Save full version | Creates a full history state **if** the underlying action does so; explicitly not an exported backup |
| Root / parent | First version / Previous version | Position in the graph |
| Delete bookmark or branch | Remove pin / Remove path label | May make unreferenced history eligible for future cleanup; not always equivalent to deleting data |

Terminology requires one `HistoryCopy` catalog, accessible descriptions and tooltips, and consistent use across history sheet, dialogs, Help, search and notifications. Provide an optional developer/advanced detail pane for exact IDs, HEAD and refs instead of exposing them to everyone. Validate ambiguous words such as `Restore` vs `Continue editing` with usability testing before locking translations.

**Do not label a history Save Point or pinned version as a backup file.**

## 4. Edit Line — compact, productive portrait-first proposal

### Mobile portrait wireframe (layout proposal, not implementation)

```text
┌────────────────────────────────────────┐
│ ←   Line 128 / 842       ♧  ⋯     Save │  short stable top bar
├────────────────────────────────────────┤
│ ▷ Video preview    00:04:21   ▾       │  optional compact/collapsible
│ [mini media player, ~140–180dp]        │
├────────────────────────────────────────┤
│ IN  00:04:19,120   OUT  00:04:22,300 │  one-row timing; expand for detail
│          ↺ Sync       ± Shift        │
├────────────────────────────────────────┤
│ ORIGINAL                   Copy   ▾   │  read-only/expand; translation mode
│ This is the source subtitle ...        │
├────────────────────────────────────────┤
│ TRANSLATION / EDITED                   │
│                                        │
│ Main text editor (grows with viewport) │
│                                        │
│                        28 / 42 chars  │
├────────────────────────────────────────┤
│ B  I  Color  Align  Dict  ⋯           │  fixed formatting strip above IME
├────────────────────────────────────────┤
│ ◀ Previous       ▶ Play       Next ▶   │  compact navigation/transport
└────────────────────────────────────────┘
```

### Behavioral recommendations

1. **Stable top:** Back with unsaved-edits guard, line index/total, marked/comment state and explicit Save; move theme switch and rare actions to More. Keep saving/error state visible, disable double-save.
2. **Video as optional tool:** collapsed compact transport when keyboard opens, expandable 16:9 preview when needed, fullscreen via existing player. Hide video without leaving a blank 240 px placeholder; no rebuilding/reparenting `VideoPlayerWidget` between simultaneous GlobalKey owners.
3. **Timing immediately accessible:** start/end display as compact paired fields, tap to enter exact timing or use +/- frames/milliseconds; Sync-to-playhead available. Do not lose keyboard timing precision or video seek logic.
4. **Original/edited focus:** original is typically read-only/collapsible in translation mode; in edit mode keep existing original/edit permissions and do not invent a second simultaneous editing surface. Edited field gets flexible vertical space, selectable Unicode text, line break support, char/line guidance, and undo/redo.
5. **Action priority:** permanent formatting row for bold/italic/color/alignment and More; Dictionary/AI/sync/normalization/marking/comment remain reachable via a labeled action sheet or menu. Avoid tiny icon-only clusters; all actions get tooltips/semantics.
6. **Bottom navigation:** Prev / Play–Pause / Next, with current Auto-Save on navigation semantics preserved; prompt on unsaved changes when required. Support one-hand mobile use without accidental taps.
7. **Keyboard-aware:** on IME opening keep edited field and formatting strip visible; video may collapse, navigation row can temporarily hide; no layout jump, focus reset or full-editor rebuild for each keyboard frame. Maintain selection and cursor during rotation.
8. **Desktop/tablet:** reuse editing field, timing controls and command models in a new resizable pane; no extra mobile Media Kit state owner. A future dedicated desktop workspace remains a separate roadmap workstream.

### Reuse strategy

Extract widgets by responsibility from `lib/screens/edit_line/parts/edit_line_layout.dart` and `edit_line_{original,edited,time}_section.dart`: `EditLineHeader`, `EditLineVideoHeader`, `EditLineTimingBar`, `EditLineSourcePane`, `EditLineTargetEditor`, `EditLineFormattingBar`, `EditLineNavigationBar`. Maintain `EditLineController` and existing persistence, playback callbacks, shortcuts, check/validation logic; consolidate duplicate video callback construction only with regression coverage. Add a pure view-mode/layout-state model so orientation does not accidentally rebuild/dispose the player.

## 5. Phased rollout and quality gates (proposed, checkpoint numbers TBD)

| Stage | Deliverable | Gate before proceeding |
| --- | --- | --- |
| UX-0: baseline | Finish Android CP85 encoding and Riverpod disposal verification; capture light/dark Android editor/history screenshots; inventory inconsistent colors and screens | Clean analyzer, targeted tests, device smoke check |
| UX-1: foundation | Design tokens, theme extensions, typography, icon/action/sheet/form components and design guidelines | Widget/golden tests on both modes, contrast, Unicode/custom-font/large-text |
| UX-2: history words | Plain-label catalog, action explanations, confirmations, Help updates; use existing history actions | Exact underlying branch/HEAD behavior unchanged, stale-HEAD and no-data-loss tests |
| UX-3: history visualization | Mobile timeline lane rail + optional true branch map, node details; maintain classic fallback temporarily | Deterministic lane layout, >=2,501 nodes, performance, semantics, Android portrait/landscape |
| UX-4: Edit Line pilot | New compact mobile composition behind opt-in toggle; reuse existing controller/Media Kit | Save/cancel/back, marks/comments, edit vs translate, timing, IME, rotation, seek, test with/without video |
| UX-5: app-wide rollout | Home/Editor/Import-Export/Project Settings/Source View/tools converted to shared components, one surface per batch | Screenshot comparisons, golden widget tests, navigation, no new hard-coded color exceptions |
| UX-6: consolidation | Retire redundant theme constants/widgets, old history fallback only after parity, publish style guide | Android/Windows smoke, analyzer/tests; eventual deliberate five-platform gate before upstream PR |

**Sequence with existing technical roadmap:** finish Checkpoint 85 and experimental waveform native testing first, or run the low-risk UX-1 token work in a separate small branch while waveform tests proceed. Avoid a simultaneous wholesale media-player redesign. Finish history terminology and graph work before visually replacing old history screens; pilot Edit Line after theme tokens are stable. Complete major UX changes before the dedicated desktop shell, which reuses the same styles and underlying editor services.

## 6. Explicit acceptance checklist

- [ ] Normal users can identify their current version, pinned version, and different editing paths without knowing Git.
- [ ] History never silently deletes earlier paths on `Continue editing` or deleting a label; explanatory copy describes retention behavior accurately.
- [ ] Full history visually represents split and reunion **only if represented in actual data**; parent/child graph integrity is preserved. No fake diff or merge edge.
- [ ] Light/dark mode, custom fonts, Malayalam, long filenames, 200% text and accessibility navigation remain usable.
- [ ] Tokens/style cover Home, Edit, Edit Line, History, Source View, Project Settings, Import/Export, player/waveform and major tool sheets.
- [ ] Edit Line portrait offers original text, editable translation, timecodes, player, mark/comment, formatting and navigation without scrolling through unrelated actions.
- [ ] No unsaved edits are lost with Next/Previous, Back, keyboard, rotation, dialogs or fullscreen video comment.
- [ ] Large history graphs/long subtitle files do not block input or repaint the entire graph during playhead updates.
- [ ] Android and Windows native tests are recorded; cross-platform behavior is not asserted from Linux CI alone.
