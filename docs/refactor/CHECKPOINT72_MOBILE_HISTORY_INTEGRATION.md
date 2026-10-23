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


## Verified Checkpoint 72 R3

- Code gate: [`6667a4e`](https://github.com/anzilr/SubtitleStudio/commit/6667a4ea317e9603d674309b8999f2f5e5e04fda).
- [Successful GitHub Actions run](https://github.com/anzilr/SubtitleStudio/actions/runs/38452604391).
- `flutter analyze`: **No issues found** (including warnings).
- `flutter test -j 1`: **287 tests passed**, three additional widget tests
  beyond Checkpoint 71.
- R1 used native Isar in a widget-test fake async zone and was replaced by an
  injectable fake command contract; the first run was cancelled.
- R2 found a real TextEditingController early-disposal bug in the new dialog
  (285 passed, two failed). Replaced dialog controller with local onChanged
  input state; R3 is green.
- No native builds, changes to database schemas, upstream changes, desktop
  workspace or release tag changes.
