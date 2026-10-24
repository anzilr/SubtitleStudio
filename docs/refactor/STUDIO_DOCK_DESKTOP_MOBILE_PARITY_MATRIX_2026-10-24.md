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
| Video attach and video playback | Shared `VideoPlayerSection` / `VideoPlayerWidget` | Native controls and persistence acceptance |
| Playback-follow subtitle highlight and seek | Wired through shared playback link | Native bidirectional seek/scroll/accuracy acceptance |
| Waveform display and selected audio stream | Shared `WaveformWidget`/controller | Native zoom, regenerate, hide/show, audio/cache tests |
| Waveform gesture time edits and insertion | Wired in DS5 R9: shared waveform gestures and compact controls call guarded Studio Dock timing/insert services; successful edits reconcile the grid/player and history | Native drag precision, magnet/overlap behavior, cue creation, undo, media stability and synchronized scrolling acceptance |
| Secondary subtitles, visibility and saved selection | Wired in DS5 R8 through the existing secondary sheet, `VideoRepository` preferences, and shared player; original-text overlay reprojects from current cues | Native external/video-track picker, original-text updates and selection persistence acceptance; Project Settings remains separate |
| Edit text, start/end timing, formatting, nine-grid alignment | Wired to shared repositories and format tags | Native editor/controller interaction acceptance |
| Cue insert, delete, split and combine | Wired, guarded, undoable | Compare edge cases and keyboard semantics with mobile |
| History graph, checkpoints, undo/redo/forks | Wired to shared graph/repository | Native path/bookmark navigation acceptance |
| Find/replace and raw Source View | Wired to shared tools/parser | Compare regex/case/selection semantics and file fidelity |
| Marked lines, comments, resolve/reopen and filters | Wired to shared history with desktop filter | Preserve mobile comment-only lines and fullscreen overlay actions |
| Copy selected subtitle text, select all visible | Wired in DS5 R5f using mobile copy format | Clipboard and multi-selection widget acceptance |
| **Shift/delete selected cues, select by index/range** | **Partial**: shift *all*, single-cue deletion; multi-select supported | Shared bulk-selection transaction with one checkpoint |
| **Go to Line and direct video seek** | **Not yet exposed** | Reuse GoToLine behavior with desktop dialog |
| **Import comments from external files** | **Not yet exposed** | Reuse mobile import and merge/history service |
| **Subtitle sync editor** | **Partial**: whole-file fixed shift only | Reuse shared sync planners and UI behavior |
| **Remove hearing-impaired annotations** | **Not yet exposed** | Reuse `HearingImpairedCleanupService` with history guard |
| MSone submission (Existing Translator/Fresher, .msone or SRT pair) | Wired in DS5 R7 to the existing submission flow; shown only when MSone features are enabled | Native picker, completed form and route-return acceptance; never submit test data to the live endpoint |
| **MSone banners and Malayalam Normalize** | **Not yet exposed** | Reuse mobile MSone feature gating and shared editing/history actions |
| **Project Settings (encoding, media, secondary subs)** | **Not yet exposed** | Host existing `ProjectSettingsSheet` with fully connected callbacks |
| App Settings, theme, typography, waveform limits, checkpoints | Wired to **existing** `SettingsSheet` in DS5 R5f | Verify immediate preference propagation and skin changes |
| Help & Documentation | Wired to **existing** `HelpScreen` in DS5 R5f | Navigation/back-stack widget and native acceptance |
| Desktop shortcuts | Partially wired to existing hotkey manager | Reconcile every mobile/action binding, preferences and conflicts |

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

1. **P0 native acceptance:** Validate waveform time drags, cue creation,
   magnet snap, overlap, selected-cue scrolling and secondary-subtitle
   persistence/playback on a native desktop before declaring playback parity.
2. **P1:** Project Settings/encoding, sync, selected-cue batch edit/delete,
   import comments, Go To Line, hearing-impaired cleanup.
3. **P2:** MSone-gated banners/normalization, fullscreen comment and
   mark callbacks, hotkey parity, theme/accessibility and native media QA.

Keep this ledger current after each checkpoint. Studio Dock must not be called
"feature-parity complete" while any missing/partial row remains.
