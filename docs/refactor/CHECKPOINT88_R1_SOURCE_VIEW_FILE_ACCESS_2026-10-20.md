# CP88 R1 — Source View typed file-access boundary

Date: 2026-10-20
Branch: `refactor/riverpod-architecture`
Scope: Phase 7 (file identity) of [refactor-to-desktop completion plan](REFACTOR_TO_DESKTOP_EXECUTION_2026-10-20.md)

## Change

Source View had Android SAF and local-file access decisions spread across its Riverpod controller. It previously initialized `File(config.filePath)` and attempted direct reads/writes as fallbacks without distinguishing a content-document URI from a native filesystem path. A direct `content://` file path with no separately passed `safUri` could be incorrectly routed to `dart:io File`.

Added a small, pure `SourceViewFileTarget.resolve(filePath, safUri)` boundary built on existing `StudioFileIdentity`. The source original locator remains byte-identical and persisted keys, Isar schemas and format metadata are unchanged.

- A direct Android `content://` locator now selects Android document read/write operations instead of pretending to be a local file.
- For a native cached file with its separate SAF grant, prefer the grant while retaining fallback to the actual local cache path if granted access fails.
- Remote, opaque and file-URI locators do not erroneously fall through to `File(stringUri)`; a dedicated platform adapter is future CP88 work.
- Reject an explicit SAF locator that is not a valid Android document.
- Reject a separately supplied grant pointing to a **different** Android document when the source `filePath` itself is already a document, preventing stale permission metadata redirecting the save.
- Preserve Source View's existing editing, encoding choices and Save As semantics for this narrow architecture change.
- New `source_view_file_target_test.dart` covers native POSIX/Windows/UNC, native cache + SAF, direct content locators, remote/opaque/file URIs and mismatched grants. Full existing tests provide wider regression context.

Implementation commits: [typed access boundary](https://github.com/anzilr/SubtitleStudio/commit/3431f8036d6c927259e44c58405e34055e6f05a3) and [mismatched-grant protection](https://github.com/anzilr/SubtitleStudio/commit/83d3910d1f2e04f4549fcf976f5faed87e700d88).

## Acceptance boundaries

- No Android native device build has been made in GitHub Actions (allowed CI: `flutter pub get`, `flutter analyze`, `flutter test`).
- This is **not the whole Phase 7 migration**. Source View still contains direct MethodChannel/SharedPreferences/file code and legacy UTF-8/Latin-1 detection. CP88 next parts should introduce an injected file-access service with permission/revocation handling and native integration tests.
- No claim of complete encoding/BOM retention; that is CP89.
- The progressive waveform experiment is frozen separately at CP86 R11; no waveform changes landed in this refactoring checkpoint.

## Android smoke testing to perform later

1. Edit an existing native SRT and reopen it to verify the original content.
2. Edit an app-cached SRT with a valid SAF permission and verify original destination.
3. Open an SRT using a direct `content://` source locator with active grant; verify the platform reader and writer, and that no literal `File(contentUri)` operation is attempted.
4. Revoke SAF access and confirm fail-closed behavior without unintended filesystem writes or data loss.
5. Reuse a stale mismatched SAF URI and verify the operation is rejected before writing.
6. Verify Edit Screen, checkpoints, MSone Back and Home taps remain unchanged.

## Verified Flutter-only quality gate

[GitHub Actions run 39479871054](https://github.com/anzilr/SubtitleStudio/actions/runs/39479871054) — **SUCCESS** (2026-10-20), **552 Flutter tests passed** with analyzer **zero errors and zero warnings**; one pre-existing informational `unnecessary_import` lint in `lib/screens/msone_input_diagnostics.dart`. The workflow uses `flutter analyze --no-fatal-infos --no-fatal-warnings`, so do not describe it as "no analyzer issues". No platform build was run in Actions.

The earlier run 39479380080 was superseded by the mismatched-SAF-grant safety fix and canceled; the result above is the final R1 gate. Android native Source View/SAF revocation checks remain outstanding.
