# Checkpoint 72 — Mobile history graph and named reference UI

Date: 2026-10-13
Branch: `refactor/riverpod-architecture`
Baseline: Checkpoint 71 R2 — 284 tests passed, 0 analyzer issues.

## Implementation
- Existing CheckpointSheet now defaults to a branch-aware mobile history
  panel with a toggle back to the classic timeline. Existing Save Point,
  Full Backup and Help actions remain unchanged.
- The separate CheckpointHistoryPanel consumes the Checkpoint 71 graph and
  action facade. It shows attached/detached HEAD, persistent named refs,
  parent IDs, fork markers, commit descriptions, and a lazy commit list.
- Branch and bookmark creation, rename and deletion use transactional
  repository commands. Branch checkout attaches HEAD. Direct commit or
  bookmarked commit checkout detaches HEAD.
- Confirmations explain what checkout and reference deletion do. On checkout
  failure no success is claimed. On success the caller is informed and
  the sheet closes, as in the previous mobile workflow.
- A request-generation guard prevents stale loads from overwriting updated
  state. The panel refreshes when existing snapshot actions finish.
- No database schema or cross-platform layout changes.

## Follow-up considerations
- Classic timeline remains during migration for compatibility, although it
  shows a linear list. Lane-routing a full graphical DAG is a future
  presentation enhancement; parent references/forks are accurate now.
- The existing "Full Backup" and "Save Point" buttons currently invoke
  the same manual snapshot service. Neither creates an independent
  backup file. Product language/semantics require a separate audit.
- Verify interactions on real Android/Windows, add accessible keyboard
  behavior for eventual desktop and review large-history scrolling.

Quality gate: flutter analyze and flutter test -j 1 at checkpoint.

## Test isolation
- Widget tests inject HistoryGraphCommands with an in-memory fake, avoiding
  native Isar async operations in Flutter's fake-async widget test zone.
- Real Isar atomic reference/checkout coverage remains in
  checkpoint_history_actions_integration_test.dart and existing integration
  suites. This keeps UI testing deterministic without losing persistence tests.

