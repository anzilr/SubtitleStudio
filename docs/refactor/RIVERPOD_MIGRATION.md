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

Every migration step should remain compilable for:

- Android
- iOS
- macOS
- Windows
- Linux

Android/Windows/Linux can be tested locally where available. iOS/macOS compilation is checked by GitHub Actions on macOS runners.

A migration PR is not considered stable while a platform compilation job is failing.

## State-management target

Use Riverpod for:

- application/domain state;
- async state;
- repositories and dependency injection;
- preferences;
- editor document/selection/navigation state.

Do not route high-frequency playback/playhead updates through broad application providers when a narrow `Listenable`, controller, stream, or `ValueNotifier` can repaint only the required UI.

## Large-file split policy

Split large files by responsibility using normal Dart imports. Do not use `part` files merely to reduce visible file length.

Examples:

- editor screen / toolbar / subtitle list / cards / dialogs;
- video surface / controls / tracks / fullscreen / subtitle overlay;
- waveform data / viewport / editing / rendering.

When a tracked file is moved, prefer a move-only commit before changing its contents so Git can detect history cleanly.

## Compatibility shims

Temporary export files may remain at old import paths during migration when that reduces merge conflicts and keeps intermediate commits buildable.

Remove compatibility shims only in a later cleanup commit.

## Database rule

Do not combine the Riverpod migration with the planned subtitle-storage schema redesign.

The Isar schema/data migration requires its own compatibility plan, backup/restore tests, schema versioning, and rollback strategy.

## Baseline CI

To conserve GitHub Actions minutes during the migration, ordinary refactor commits do **not** run the full cross-platform matrix.

The matrix runs only when:

- `.github/ci-checkpoint` is deliberately updated; or
- the workflow is started manually with `workflow_dispatch`.

Use a checkpoint roughly every 10 commits or after a major migration milestone. Do not trigger the full matrix for tiny file moves, comment changes, or intermediate extraction commits.

The cross-platform workflow intentionally copies `.env.example` to `.env` because the current `pubspec.yaml` declares `.env` as an asset.

This is a temporary compatibility measure. The application should later be changed so `.env` is genuinely optional and privileged secrets are never packaged in the client.

The workflow also skips `flutter test` only when no committed test files exist. Once regression tests are added, tests become a normal required check.
