# Riverpod Architecture Migration — Repository Safety Rules

This document defines the repository rules for the Subtitle Studio state-management and architecture migration.

## Protected baseline

- `main` remains the release branch.
- `development` remains the integration baseline.
- Release tags are never rewritten or moved.
- Experimental architecture work happens only in `refactor/riverpod-architecture` and follow-up feature branches.

## Commit discipline

Do not combine unrelated structural changes.

Preferred sequence:

1. move/rename only;
2. import-path adjustment;
3. extract widgets/services without behavior changes;
4. add Riverpod provider/controller;
5. switch one consumer at a time;
6. remove the old BLoC/Provider/GetX code only after replacement is validated.

Avoid commits that combine file moves, reformatting, state-management replacement, database changes, and logic fixes.

## Platform gate

The migration must preserve Android, iOS, macOS, Windows, and Linux support.

During active refactoring, GitHub Actions intentionally runs only analyzer and
unit/regression tests to conserve Actions minutes. Android/Windows/Linux can be
smoke-tested locally when convenient. A full cross-platform compilation gate
will be run deliberately before the refactor is proposed for integration; it
is not run on ordinary checkpoint commits.

## State-management target

Use Riverpod for:

- application/domain state;
- async state;
- repositories and dependency injection;
- preferences;
- editor document/selection/navigation state.

Do not route high-frequency playback/playhead updates through broad application providers when a narrow `Listenable`, controller, stream, or `ValueNotifier` can repaint only the required UI.

## Large-file split policy

Split large files by responsibility. Prefer normal Dart imports for independent
widgets, services, models, and controllers. A `part` file is acceptable for
private extensions or private UI helpers that intentionally remain in the same
library and require access to the owning State object's private members; it
must represent a real responsibility boundary, not just arbitrary line counts.

Examples:

- editor screen / toolbar / subtitle list / cards / dialogs;
- video surface / controls / tracks / fullscreen / subtitle overlay;
- waveform data / viewport / editing / rendering.

When a tracked file is moved, prefer a move-only commit before changing its
contents so Git can detect history cleanly.

## Compatibility shims

Temporary export files may remain at old import paths during migration when that reduces merge conflicts and keeps intermediate commits buildable.

Remove compatibility shims only in a later cleanup commit.

## Database rule

Do not combine the Riverpod migration with the planned subtitle-storage schema redesign.

The Isar schema/data migration requires its own compatibility plan, backup/restore tests, schema versioning, and rollback strategy.

## Baseline CI

To conserve GitHub Actions minutes, ordinary refactor commits do not trigger
Actions. Updating `.github/ci-checkpoint` (or manually using
`workflow_dispatch`) runs one Ubuntu quality job containing:

- `flutter pub get`;
- `flutter analyze --no-fatal-infos --no-fatal-warnings`;
- `flutter test` when committed tests exist.

Use a checkpoint roughly every 10 commits or after a major migration milestone.
Do not trigger a checkpoint for tiny file moves, comments, or intermediate
extractions.

`pubspec.lock` is committed to the repository, so the quality workflow is
read-only and does not create bot commits or upload temporary lock artifacts.

The former `.env` Flutter asset and client-side privileged credentials have
been removed. CI no longer creates an `.env` file. Any future feature that
requires privileged credentials must use a trusted server-side service or a
user-owned credential stored with an appropriate platform-secure mechanism.

A full Android/iOS/macOS/Windows/Linux compilation matrix is deferred until a
deliberate pre-integration gate.
