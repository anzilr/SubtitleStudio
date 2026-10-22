# SubtitleStudio — CP91 R5: Compact history management and list mode

Date: October 22, 2026  
Branch: `refactor/riverpod-architecture`

## Delivered

- A **Manage** entry opens a scrollable bottom sheet, with separate
  **Editing paths** and **Bookmarks** groups. Each row shows its saved
  version, and the active editing path is labeled **In use**.
- Reference menus in the manager and existing quick-access strip share
  one set of available actions. The built-in **Main edits** path can
  be used but not renamed or deleted; in-use and protected reference
  restrictions continue to come from the history graph.
- A version-map/list button switches between connected graphical lanes
  and a text-first list. List mode omits the decorative rails and legend;
  version titles, numbers, parent relationships, selected-version state,
  bookmarks, and restore actions remain available.
- The management panel scrolls independently rather than requiring users
  to find an item in a long horizontal chip strip.

## Safety and compatibility

This is presentation-only work in `CheckpointHistoryPanel`.
`HistoryGraphCommands`, history validation, checked HEAD/branch-tip
updates, protected `refs/heads/main`, Isar storage, and `.msone` import/
export formats are unchanged. The map/list preference is local to the
currently open panel and is not persisted.

## Tests and limitations

Added three widget regressions for switching map/list views while
preserving version actions; grouping/renaming references with protected
main rules; and avoiding overflow at a 320px mobile width.

The [GitHub Actions quality run #39835416671](https://github.com/anzilr/SubtitleStudio/actions/runs/39835416671)
passed **749 Flutter tests** with **zero Flutter analyzer issues**.
Only dependency resolution, analysis, and unit/widget/integration tests
ran on Linux. No Android, iOS, web, Windows, macOS or Linux application
builds, and no multi-host CI matrix.

This verifies code-level behavior only. TalkBack/VoiceOver navigation,
text scaling, and device touch acceptance remain to be checked during
the later UX/native acceptance phase.

Verified code commit:
[`674c129`](https://github.com/anzilr/SubtitleStudio/commit/674c129786d70ea717f223bf7a7dba9df2a0f488).

## Next

CP91 R6: pilot a compact, portrait-first Edit Line layout with a
shorter header, focused text/timing controls, and optional collapsed
media area. Reuse the existing Riverpod/controller save contracts and
retain Carbon Zero/other shipped skin compatibility. Desktop UI
integration remains separate until the shared-core acceptance gate.
