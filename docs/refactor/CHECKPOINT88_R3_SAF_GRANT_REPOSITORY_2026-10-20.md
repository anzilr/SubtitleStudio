# CP88 R3 — Source View SAF grant metadata ownership

**Date:** 2026-10-20
**Branch:** `refactor/riverpod-architecture`
**Scope:** shared-core file-access refactor (CP88), following [CP88 R2](CHECKPOINT88_R2_SOURCE_VIEW_STORAGE_SERVICE_2026-10-20.md).

## What changed

Source View no longer directly calls `SharedPreferences.getInstance()` in its Riverpod controller. A dedicated, injectable `SourceViewSafGrantRepository` owns the compatibility and validation of saved SAF *locator metadata*. A separate `SourceViewSafGrantStore` isolates the underlying persistence adapter, with `SharedPreferencesSafGrantStore` retaining the **exact legacy key** `saf_uri_<original filePath>` and original URI string values.

Resolution order:

1. Validate the original source locator with `SourceViewFileTarget`.
2. If the caller supplies an explicit, nonblank SAF locator, validate it against the source, then persist it under the same legacy key and use it. This makes current user selection take precedence over stale stored metadata.
3. Otherwise read the legacy key. A valid saved document URI is reused, including the existing native app-cache + separate SAF-document flow.
4. If a saved value is empty, malformed, not an Android `content://` document, or points to a different document from a directly opened `content://` source, remove the stale key without using it.
5. When opening a direct Android document without a separate valid saved grant, that source URI is itself the correct locator; no unrelated path is used.

**Permission distinction:** saved SAF locators are **not proof of live Android read/write access**. Real grants may be revoked by the provider; the injected `SourceViewFileAccess` still verifies access on each operation. The metadata repository never reads document bytes, stat checks, or silently falls back from a direct `content://` source to an unrelated local file.

**Privacy:** error logs omit raw SAF URIs, document IDs, absolute file paths, and preference key material. The existing path-based preference keys remain for compatibility and are not migrated or logged.

## Files changed

- `lib/screens/source_view/source_view_saf_grant_repository.dart`: new repository API, fake-able preference store, and existing SharedPreferences implementation.
- `lib/screens/source_view/source_view_controller.dart`: replaces direct preference read/write with `sourceViewSafGrantRepositoryProvider`, while leaving editing state, parser, encoding detection, native adapter and route management unchanged.
- `test/source_view_saf_grant_repository_test.dart`: native-file cached-grant reuse, explicit grant precedence, direct-document identity, mismatched/stale key cleanup, malformed values, invalid caller validation, per-source preference isolation, and a mocked real SharedPreferences adapter key round trip.

[Core implementation](https://github.com/anzilr/SubtitleStudio/commit/bddd442cd8cfe0af235e61bb9e3f36c233ed0119) · [SharedPreferences compatibility regression](https://github.com/anzilr/SubtitleStudio/commit/1cbbc826a72a9ad49f27ed729caa4981d0162342)

## What is not yet complete

- Android native SAF-grant and document-provider tests (valid persisted grant, revoked grant, stale saved URI, same-doc reload, Save As) must be run locally; GitHub Actions may run only Flutter dependency resolution, analysis and tests.
- For a native cached file plus saved SAF locator, a legacy string key alone cannot authenticate that the grant belongs to the current logical source. Do not assume perfect cross-document correlation without future source/document identity metadata and explicit device checks. A direct `content://` source is identity-checked and cannot be redirected.
- Source View still uses UTF-8 then Latin-1 decoding; extended reversible charset and BOM behavior remain **CP89**, not part of this refactor.
- CP88 still needs an audit of import/export/secondary subtitle/video access to converge file identities and platform routing, and a native acceptance sweep.
- No waveform experimental changes are merged; the mobile editor remains visually unchanged. Desktop UI follows CP93 core acceptance.

## Flutter-only verification

[Final CP88 R3 GitHub Actions run 39484474034](https://github.com/anzilr/SubtitleStudio/actions/runs/39484474034) — **SUCCESS** on October 20, 2026: **569 Flutter tests passed**, `flutter analyze`: **No issues found**. The test suite includes the actual SharedPreferences mock compatibility case and pure grant-policy regressions. No Android, Windows, Web, iOS, Linux or macOS build was performed in CI. Physical Android SAF grant behavior remains outstanding.
