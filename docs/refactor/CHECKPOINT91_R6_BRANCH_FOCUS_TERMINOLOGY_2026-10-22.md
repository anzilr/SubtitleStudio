# SubtitleStudio — CP91 R6: Branch focus and history terminology

Date: October 22, 2026  
Branch: `refactor/riverpod-architecture`

## Language updated

| Previous UI label | New UI label |
| --- | --- |
| Restore this version | Restore this point |
| Start another editing path | Branch from this point |
| Save Version | Save History |
| Main edits | Main path |
| Current version | Current point |
| Bookmark this version | Bookmark this point |
| Use this editing path | Switch to this path |

The graph, menus, confirmations, status text and classic history controls
use the revised terminology. Names entered by users are not rewritten.
The protected reference remains `refs/heads/main` internally.

## Branch presentation and filtering

- Each named branch receives a separate, theme-contrast-aware highlight
  color in the selector, its exclusive commit-card markers and the
  corresponding graph tracks. The active branch is preferred for coloring
  shared ancestry, which necessarily belongs to several paths.
- Tapping a branch chip, a branch label on a point card, or a branch row in
  **Manage** focuses the timeline on that branch's tip and parents. The
  shared earlier commits are included, while sibling-only commits are
  hidden. **Show all** returns to the complete graph.
- This is a *display filter*, not a restore or checkout. The selected
  editor HEAD, guarded branch tips, bookmarks, persistence, and `.msone`
  compatibility remain unchanged. Switching the actual editing path still
  requires a separate menu action and confirmation.
- The branch-focused graph has one lane. In the complete map, the rail
  now uses at most **80px**, rather than the earlier 106px, regardless of
  how many branches exist. Many lanes may still become crowded in that
  fixed gutter; the UI advises focusing on a branch. The redundant,
  noninteractive HEAD chip no longer crowds the narrow branch strip.

## Tests and verification

Four pure graph/branch tests cover exact shared ancestry, distinct
ownership of fork tips, rejection of incomplete ancestry filters, and
the upper bound for the graph gutter. Three widget tests cover
branch-specific colors/filtering, management-panel filtering without
changing HEAD, and a dozen branches on a 320px phone viewport.

The initial [CI run #39839861321](https://github.com/anzilr/SubtitleStudio/actions/runs/39839861321)
passed analysis and 755 tests but exposed an off-screen tap in the new
narrow-screen test. The test now scrolls to the target chip, and the
compact branch strip omits the unnecessary HEAD chip.

The final [CI run #39840768237](https://github.com/anzilr/SubtitleStudio/actions/runs/39840768237)
passed **756 Flutter tests** and reported **zero analyzer issues**.
Only Linux dependency resolution, Flutter analysis and automated tests
ran; no native platform builds or multi-host test matrix.

Verified code commits:

- [`eb0efb4`](https://github.com/anzilr/SubtitleStudio/commit/eb0efb45acb2cbcbba7051c60ed332350f400c81) — history terminology, path colors and ancestry filtering
- [`c39f059`](https://github.com/anzilr/SubtitleStudio/commit/c39f0596e8e9584cd0905f1d116291dba0f27800) — narrow-screen selector and final test correction

Physical-device visual and TalkBack/VoiceOver accessibility checks are
still pending at the later acceptance gate. Branch highlight colors are
presentation values, not persisted branch metadata.

## Next

CP91 R7: compact portrait Edit Line productivity/layout pilot, keeping
existing Riverpod save contracts, source/timing preservation, shipped
skins and desktop workspace isolation intact.
