# SubtitleStudio — Studio Dock DS4 R1.1: Desktop-Only Navigation

Date: 2026-10-24  
Branch: `feature/studio-dock-integration`

## Product decision — fixed

**Studio Dock is the default and only user-facing workspace on native Windows, Linux and macOS.** The previous classic Home/Editor handoff is no longer an accepted transition. Android and iOS keep their existing mobile editor.

## Implementation

- `MainApp._getInitialScreen()` always returns `StudioDockDesktopHome(initialFilePath: initialFile)` on native desktop, including command-line/file-association launches. It never chooses the classic `HomeScreen`.
- `StudioDockDesktopHome` removes the legacy import/create route and its `classicHomeBuilder` testing hook. Its Projects dialog now offers **Import file** and **New project** alongside session selection. Empty-library welcome offers those actions directly.
- `StudioDockProjectActions` uses existing `SubtitleEncodingDecoder`, `SubtitleParser`, `SubtitleImportRepository` and `SessionProjectImportRepository`: read SRT, VTT, ASS/SSA, and complete .msone archives with history preservation. It never opens an Editor or Source View route. On success the new session becomes active directly in Studio Dock.
- Cancelling the picker creates nothing; invalid/missing file rejects import without a created session. New empty projects require explicit Create, store no external SRT path, and display a branded empty Studio Dock state (add-cue UI is not yet implemented).
- The classic Editor's temporary toolbar shortcut to read-only Studio Dock was removed; it is not required once Studio Dock owns native desktop routing.
- Existing active-session media player, checkpoint-backed text Apply, cursor navigation and standalone hotkeys remain inside Studio Dock. Mobile is unchanged.

## Acceptance and limitations

- Focused Flutter quality workflow: analyzer of all Dart source and `test/studio_dock*_test.dart` (Flutter only). Full Flutter workflow still analyzes/tests; **no native app builds in Actions**.
- Widget regression checks for only Studio Dock import/create actions, cancellation, empty project creation dialog and session switching.
- Isar integration checks for blank-line-preserving SRT import, VTT, create-empty, invalid/missing input; .msone imports use the production history import repository and should be validated with a representative archive on Windows.
- Existing programmatic desktop screens such as the legacy mobile Editor remain in source to serve mobile; they are not reachable by the default native desktop navigation.
- DS5 must supply native Save/Export, add-cue editing, full file relinking, formatting/notes/timing tools and other feature-parity workflows. Until then, these are incomplete **Studio Dock** functions—not reasons to fall back to the old desktop UI.
- Test command-line open from Explorer (SRT, VTT, ASS, MSONE), project creation, normal startup, switch projects, text Apply, media player, and large/small window geometry on the Windows host.

## Prior checkpoints
- [DS3 R2 guarded text editing](STUDIO_DOCK_DS3_R2_TEXT_EDIT_2026-10-24.md)
- [DS4 R1 media ownership](STUDIO_DOCK_DS4_R1_MEDIA_OWNERSHIP_2026-10-24.md)

Next: DS4 R2 waveform, followed by DS5 native file/export and editor feature-parity; maintain the **Studio Dock only** desktop constraint across all future work.

## Automated verification (final source)
- [Studio Dock Flutter quality run #40029860147](https://github.com/anzilr/SubtitleStudio/actions/runs/40029860147): **passed** — zero analyzer issues, **39 Studio Dock tests passed**.
- [Full Flutter quality run #40029875543](https://github.com/anzilr/SubtitleStudio/actions/runs/40029875543): whole-repository analyzer passed; full regression status is tracked independently.
- Fixed during verification: empty project's theme color, New Project dialog closing without disposing a live field controller, and dirty-draft protection before the new direct-toolbar Import/New actions. Added focused regressions covering this behavior.
- Previous DS4 full gate #40028084316 completed successfully with 838 tests; the newer full gate must not be called complete until GitHub confirms.
- Windows native acceptance is still required: file association startup; import and project creation; edited text persistence; playback and pane resizing. No native platform build was run in CI.
