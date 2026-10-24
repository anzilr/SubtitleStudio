# SubtitleStudio — DS5 R5c: Production Find, Replace and Tools

Date: 2026-10-24
Branch: `feature/studio-dock-integration`
Predecessor: `STUDIO_DOCK_DS5_R5B_STYLE_NOTES_2026-10-24.md`

## Scope and implementation

- Replaced the placeholder **Find** navigation screen with in-project
  effective subtitle text search, case sensitivity, whole-word matching,
  occurrence list, per-occurrence selection and a way to jump to its cue.
  Queries use the authoritative session snapshot, including nullable edited
  values; read-only sessions can search without obtaining write access.
- **Replace selected** and **Replace all** require confirmation and reuse
  `SubtitleSearchReplacePlanner` plus the existing
  `SubtitleRepository.updateMultipleLinesWithHistory` transaction. Match
  snapshots are compared with the window baseline and repository values;
  stale text or review metadata rejects an entire affected-cue batch.
  One Replace action creates one checkpoint; original text, timing, comments,
  marks, and resolution are preserved.
- Replaced the placeholder **Tools** screen with production, guarded bulk
  operations: shift every cue's start/end by a signed millisecond delta while
  preserving durations, and clear the supported formatting/color/alignment
  tags from effective text without altering original subtitles or review
  metadata. The shift validates canonical timecodes and 24-hour boundaries
  before saving. Both tools use one atomic shared history transaction.
- The command palette exposes Find, Replace, Tools, and all four Inspector
  tabs. Inspector shortcuts now respect the existing unsaved-draft guard.
  Ctrl/Cmd+F opens the Find panel through the app hotkey manager. This
  remains the only native desktop editor; Android/iOS layout is unchanged.
- **No platform builds** in GitHub Actions. The Windows-native acceptance
  session is explicitly deferred until the user has access to that machine.

## Regression acceptance

- `studio_dock_search_tools_integration_test.dart` covers nullable edits,
  case/word queries, selected replacements, stale snapshots, atomic bulk
  shifts, negative time rejection, concurrent notes, and tag cleanup.
- `studio_dock_search_tools_widget_test.dart` covers navigation, Find/Replace
  UI, confirmation/cancellation, tool execution, failure display, and input
  retention.
- Run `flutter pub get`, `flutter analyze`, the focused Studio Dock suite
  and the complete Flutter repository test suite through GitHub Actions.

## Next

1. **DS5 R5d:** remaining multi-cue review/selection actions, context-menu
   affordances, shortcut refinement and cross-skin/narrow-layout widget
   regression; production Settings integration if feasible.
2. **DS6 deferred:** native Windows media, waveform, file round-trip, theme
   and scaling acceptance at the user's machine; targeted macOS/Linux
   native checks when available.

## CI

Pending.
