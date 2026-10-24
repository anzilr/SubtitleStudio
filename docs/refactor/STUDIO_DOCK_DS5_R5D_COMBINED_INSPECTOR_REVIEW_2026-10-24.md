# SubtitleStudio — DS5 R5d: Combined Text/Timing inspector and review tools

Date: 2026-10-24
Branch: `feature/studio-dock-integration`
Predecessor: `STUDIO_DOCK_DS5_R5C_SEARCH_TOOLS_2026-10-24.md`

## Accepted design change

- The user requested that Timing move below text editing instead of occupying
  an independent inspector tab. The production inspector now exposes **Text,
  Style, Notes**. Text contains original and edited content followed by the
  Start, End and Duration fields and one sticky, always-visible **Apply
  changes / Discard** pair beneath the scrollable inspector.
  The command palette's inspector entries reflect those three tabs.
- The shared `StudioDockCueEditService` applies simultaneous text and timing
  edits as **one** optimistic transaction and one history point. No partial
  text save is possible if timing is invalid or the cue/annotation changed
  in another window. Text-only and timing-only drafts keep their existing
  shared edit services; source, review metadata and neighboring cues remain
  untouched. Draft navigation still requires Apply/Discard/Cancel.
- Mark and unmark a multi-cue selection through the new shared
  `StudioDockBulkReviewService`, using the existing checkpoint transaction
  and preserving multi-selection after refresh. The subtitle grid exposes a
  review toolbar menu and right-click actions; the command palette and
  existing mark-line shortcut reuse the guarded flow. Unmarking explicitly
  clears the chosen cues' comments and resolution, with a warning and
  confirmation whenever data would be cleared or multiple lines selected.
- Theme colors come from active semantic tokens. No broad appearance rewrite,
  Isar schema change, classic desktop editor, or mobile layout change.

## Regression acceptance

- `studio_dock_combined_cue_edit_test.dart`: one transaction, invalid timing,
  stale review state, safe no-op and exact cue field preservation.
- `studio_dock_bulk_review_test.dart`: multi-line checkpoint, preserving text,
  explicit unmark semantics and conflict rejection without partial writes.
- `studio_dock_text_draft_widget_test.dart`: Text contains Timing; the old
  Timing tab is gone; one Apply handles combined content; validation and
  unsaved-draft dialogs remain effective.
- `studio_dock_review_layout_widget_test.dart`: multi-selection and grouped
  mark/unmark dialog behavior; narrow 1100×768 inspector overlay access.
- GitHub Actions **only** run `flutter pub get`, `flutter analyze` and tests.
  Never build Android/iOS/Windows/macOS/Linux apps in CI.

## Remaining

1. DS5 R5e: production Settings/shortcuts UI and remaining context-menu
   refinements, with multi-skin and narrow-layout widget assertions.
2. DS6 native acceptance remains **deferred**: the user does not currently
   have the Windows computer. Later validate video/waveform follow/seek,
   controllers, file encoding and project reopening, and layout scaling.

## CI

- **Focused Studio Dock quality: PASS** — [run 40079814187](https://github.com/anzilr/SubtitleStudio/actions/runs/40079814187), `flutter analyze` successful, **142 focused tests passed**. Earlier focused run caught three obsolete inspector-layout assertions; these were corrected before acceptance.
- **Full migration quality: PASS** — [run 40080002082](https://github.com/anzilr/SubtitleStudio/actions/runs/40080002082), `flutter analyze` successful, **944 Flutter tests passed**.
- No native/platform builds executed; native desktop acceptance remains deferred until a Windows machine is available.
