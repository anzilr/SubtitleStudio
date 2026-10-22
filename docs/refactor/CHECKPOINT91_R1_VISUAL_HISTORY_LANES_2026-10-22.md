# SubtitleStudio — CP91 R1: Visual Git-style checkpoint lanes

Date: October 22, 2026  
Branch: `refactor/riverpod-architecture`

## Scope and handoff

CP90 R14's full 718-test/clean-analyzer gate accepted the latest
controller navigation lifecycle changes. The existing history screen
already reads a checked checkpoint graph and uses head/tip-guarded
branch and commit checkout commands; a classic timeline remains
available in the owning checkpoint sheet. CP91 can therefore start
with **presentation only**, without a new database, history writer or
desktop-specific fork.

## What changed

- Added `CheckpointHistoryLaneLayout`, a deterministic and immutable
  graph-layout service that assigns lanes newest first while tracking
  open paths to *actual parent checkpoint IDs*. Parallel histories only
  connect at their shared persisted parent, regardless of timestamps.
- Added a theme-aware `CheckpointHistoryRailPainter` using semantic
  primary/outline/surface colors. The current HEAD receives a distinct
  filled marker; preceding history stays connected and alternative
  branch tracks converge at their shared checkpoint.
- Integrated the lane visualization into the existing lazily built
  checkpoint list beside each action card. Layout is cached with each
  loaded graph and rebuilt on refresh, checkout, branch operations and
  session changes. The rail is noninteractive; original descriptions,
  branch/bookmark labels, confirmation dialogs, keyboard/semantics
  affordances and guarded commands stay intact.
- The existing classic timeline remains an alternative presentation.
- No Isar schema, `.msone` archive contract, checkpoint mutation
  semantics, persistent reference format, file access or player behavior
  changes.

## Regression coverage

- Single linear history (one stable vertical lane).
- Forked history joining only at the shared parent.
- Detached HEAD with preserved parent links.
- Three simultaneous tips without false early joins.
- Long 1800-checkpoint history without recursive graph traversal.
- Existing widget regression now verifies rail rendering alongside the
  checkpoint card, head status and action menu.

## Verification

One Linux workflow runs `flutter pub get`, `flutter analyze`, and the
full `flutter test` suite. It does not build Android, iOS, desktop or
web artifacts, and it does not run the Windows/macOS host matrix.
The initial [Linux run 39825640596](https://github.com/anzilr/SubtitleStudio/actions/runs/39825640596)
passed analysis with zero issues and 722 tests, but one new fork-layout
test asserted the sibling IDs in the wrong display order. The graph
sorts equal-depth/equal-time sibling nodes by ID ascending, then displays
newest first. The follow-up test corrects the expected rows from
`[3,4,2,1]` to `[4,3,2,1]`, without changing the validated layout or
storage. The final clean gate will be recorded after completion.

## Next CP91 stages

Improve plain-language history action descriptions, visual legends,
compact branch/reference management and mobile Edit Line ergonomics,
without weakening confirmation and reference-protection checks. Keep
the single-screen desktop workspace preview isolated until shared
contracts have passed the agreed acceptance.
