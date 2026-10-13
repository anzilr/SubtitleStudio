# Checkpoint 73 — History concurrency, UI lifecycle and scalability

Date: 2026-10-13
Branch: `refactor/riverpod-architecture`
Baseline: Checkpoint 72 R3 — 287 tests, analyzer zero issues.

## Changes

- Public repository and shared history actions accept optional expected HEAD
  IDs on checkout. Branch checkout also accepts the displayed expected branch
  tip. A changed HEAD or tip rejects checkout; the persistence layer still
  revalidates inside the Isar write transaction. Older callers remain
  compatible through optional parameters.
- Mobile history dialogs reserve an interaction while confirmation/name
  dialogs are open. Refused actions refresh the graph and no success is
  reported. The owning sheet closes before notifying the editor callback,
  avoiding a second accidental route pop after editor navigation.
- Name-entry uses TextFormField with an initial value, without early
  TextEditingController disposal. Branch renaming now visibly prefills its
  existing name. UI errors avoid claiming that a rejected write definitely
  left everything unchanged when a post-write read might fail.
- Mobile history rendering indexes the stored topological graph in reverse
  rather than allocating a reversed list on every build. Named refs use lazy
  horizontal ListView.builder. The compatibility timeline builds cards with
  ListView.builder and computes descendant counts using bounded adjacency
  traversal rather than nested repeated ancestry scans. Legacy reloads ignore
  stale requests.
- The existing "Full Backup" label was misleading. The button/dialog now
  say **In-app Snapshot** / **Snapshot**, and explain that no separate
  recovery file is produced. "Save Point" remains the existing named snapshot
  workflow; lightweight bookmarks are a separate history-graph action.
- No Isar schema change, desktop layout, native builds or upstream changes.

## Regressions

- Real-Isar integration coverage for stale HEAD checkout and stale branch
  tips, including a successful guarded branch switch.
- Widget tests verify the displayed HEAD and branch tip are passed to
  command-level checkout guards.
- Large forked descendant traversal regression covers 2501 checkpoints.

## Deliberate boundaries

- This is an incremental safety/performance step; user-facing graphical lane
  routing is not implemented.
- Native Android/Windows UI interactions, released backup upgrades and
  actual media-scale performance remain qualification work.
- Checkpoint snapshots do not replace separate project backups.

## CI
Flutter analyzer/tests milestone gate required before declaring verified.
