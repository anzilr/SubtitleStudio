# SubtitleStudio CP88 R6 — Picker source identity separation

Date: October 21, 2026
Branch: `refactor/riverpod-architecture`

## Why

The existing Android `PlatformFileHandler.readFile` exposes both a SAF URI and a path normalized from a provider document ID. This converted path may **look** like an accessible Android filesystem path while remaining only a display hint. Callers could mistakenly pass `displayPath` into `File(...)`, Isar file identity, or an update operation. Pickers also logged raw document URIs and full paths.

## Change

- Add pure typed `StudioPickedFileReference`, backed by the existing `StudioFileIdentity`. It carries two intentionally different values: **`accessLocator`** (authoritative, exact `content://` source or native path) and **`displayPath`** (legacy presentation hint, never proof of access).
- Validate SAF selections as Android document identities; reject missing/malformed SAF URIs and reject remote/content/opaque sources pretending to be native files.
- Expose `PlatformFileInfo.pickedReference` as an explicit migration path for all new callers. Its privacy-safe `toString` does not reveal raw source paths or document IDs.
- Preserve existing `pickFileWithInfo` fields `displayPath`, `safUri`, and `bytes`, while adding **`accessLocator`** for Android and desktop. A typed mapper handles both paths. The video selection map also adds `accessLocator`; its existing `uri`, `displayPath` and `displayName` are preserved.
- Redact raw SAF URIs and local file paths from debug logs in `PlatformFileHandler`, subtitle/video pickers and path-bearing snackbar errors. Do not log original URI, query tokens, document ID, or the cached translated path.
- **Compatibility boundary:** The legacy `pickFile` single-string Android API currently returns a converted display path. It is deliberately **not** silently changed to return a URI in this checkpoint, because callers may assume a path. The follow-up migration must first identify/update those consumers; new code should use the typed selection / `accessLocator`.

## Unit verification

`test/studio_picked_file_reference_test.dart` covers real SAF identity vs synthetic display paths, legacy map compatibility, native Windows locators, malformed/missing grants, remote URL rejection and log-safe `toString`.

This checkpoint is a compatibility-preserving foundation, not a completed source import migration. Actual SAF provider permissions, Android file picker display, video launch and desktop dialog behavior need later native smoke checks.

## Future work

CP88 R7: migrate the remaining path-only picker/import callers to the authoritative locator, then review video source locators and `PlatformFileHandler` read/write routing. Preserve .msone keys, Isar schema, current video/SubtitleStudio mobile behavior; no waveform or desktop UI changes.

Continue CP89 encoding once the remaining critical CP88 paths are converged. GitHub Actions: **Flutter pub get, analyze, tests only, never any native platform builds**.

## CI

Final R6 Flutter quality gate to be recorded after completion.
