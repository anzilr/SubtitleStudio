# Checkpoint 71 — Reusable history graph and command boundary

Date: 2026-10-13
Branch: `refactor/riverpod-architecture`
Starting green baseline: Checkpoint 70 R3 (276 tests, analyzer clean).

## Implementation

- `CheckpointHistoryGraph` is a pure, immutable view of the persisted
  checkpoint DAG and named `HistoryRef` records. It provides deterministic
  topological ordering, direct parent/children edges, depth, HEAD ancestry,
  attached/detached branch state, and lightweight labels on each node.
- The graph checks session/collection ownership, positive/unique IDs, parent
  completeness, cycles, exactly one consistent HEAD, and reference targets.
  Broken or racing snapshots **fail closed**, never silently prune a node.
- The reader performs any legacy reference migration first, then loads refs
  and checkpoints in a single Isar read transaction for a consistent view.
- `CheckpointRepository.getHistoryGraph(sessionId)` exposes the view to
  feature controllers. `CheckpointHistoryActions` exposes session-scoped
  create/rename/delete/bookmark/branch and checkout commands; writes continue
  to use existing transactional Checkpoint 70 APIs. A refused checkout returns
  null rather than displaying fabricated success.
- No Isar schema changes and no mobile or desktop layout changes.

## Regression coverage

Pure graph tests cover forks, clock skew, ordering, attached/detached HEAD,
immutable lists, foreign/missing/cyclic history, corrupt refs, and deep chains.
The next UI milestone can consume the same graph and command facade.

## Pending

- Integration through a visible history screen, confirmation/warnings and
  accessibility/keyboard interactions. Intentionally deferred until the
  presentation milestone.
- Extended symmetric SRT charset import/export, measured waveform caching,
  real released backup fixtures and platform build gates.

Verification: GitHub analyzer/tests checkpoint gate is required; do not
report counts until the run completes.
