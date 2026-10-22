# SubtitleStudio — CP91 R2: Plain-language checkpoint history

Date: October 22, 2026  
Branch: `refactor/riverpod-architecture`

## Motivation

CP91 R1 introduced connected Git-style history lanes. The UI still
exposed internal terms such as `HEAD`, `detached HEAD`, `commit`,
`checkout` and `pruning`, making safe history navigation harder
for editors who do not know Git.

## Implementation

- Added `CheckpointHistoryLabels`, a pure presentation mapping from
  immutable graph nodes and persistent references. It never changes
  reference names, IDs, branch attachment, permissions, or transactions.
- The header now reads "Working on [branch]" or
  "Version #[id] · Not on a branch". Version row summaries identify
  the first saved version, the current version, earlier edits on the
  current path, and branch points without exposing internal `HEAD` jargon.
- A compact horizontally scrollable legend explains current version,
  earlier versions and branch points. The existing visual graph,
  branch/bookmark chips and classic history list remain.
- Existing checkout actions now say "Restore this version" and
  "Switch to branch", with confirmations explaining that existing
  named branches/bookmarks stay unchanged and that edits made outside
  a branch continue on that separate path.
- Named-reference creation/renaming/deletion dialogs use more familiar
  language. Protected `HEAD`, `main`, and attached branch controls
  still defer to the same repository policies and guarded transactions.
- Corrected existing widget assertions for the new wording, without
  changing action IDs, branch ref paths, HEAD/tip expected IDs or the
  checkpoint/reconstruction implementation.

## Regression coverage

Six pure tests for reference labels, active-branch semantics, version
metadata, branch-point counts, and both forms of checkout explanation.
Three new widget tests for detached status, protected-main menu actions,
and bookmarked-version restore. Earlier widget tests for HEAD/tip
concurrency guards, bookmark persistence and corrupt graph recovery
remain in the suite.

## Compatibility

No changes to Isar generated schema, portable `.msone`, history
transaction semantics, reference name storage, video/file/media support,
appearance skins, or production desktop workspace. Classic history
view stays available for access and fallback.

## Verification

Use one Linux-only workflow with `flutter pub get`, `flutter analyze`
and the complete `flutter test` suite. No native app builds or
Windows/macOS host matrix. The initial [Linux CI run 39827855675](https://github.com/anzilr/SubtitleStudio/actions/runs/39827855675)
passed analysis (zero issues) with 730 tests passing and two test-only
failures in `checkpoint_history_panel_widget_test.dart`. One still
expected the renamed "Check out commit" menu item, and another matched
"current branch" in three widgets rather than the intended dialog.
The follow-up updates these expectations to the actual visible text;
no history action, concurrency guard, data model, or presentation
implementation changed. The final gate is recorded after verification.

## Next

CP91 R3: continue history accessibility/more compact branch/reference
management, then compact mobile Edit Line productivity changes.
Proceed to CP92 cleanup and CP93 native acceptance after CP91.
