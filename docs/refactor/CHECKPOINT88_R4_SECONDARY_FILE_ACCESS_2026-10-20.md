# CP88 R4 — Secondary subtitle document access convergence

Date: 2026-10-20
Branch: `refactor/riverpod-architecture`

## Scope and implementation

The main Editor's `VideoRepository` previously read secondary subtitles by choosing `SafFileHandler.readFileFromUri` only on Android and otherwise calling `File(path).readAsString()`. A persisted `content://` locator could therefore be treated as a filesystem path on another platform. It also embedded direct filesystem/SAF operations into the preference repository, used raw paths in some logs and rejected provider document IDs that did not contain a recognizable filename suffix.

CP88 R4 introduces **`SecondarySubtitleDocumentReader`**, backed by an injectable `SecondarySubtitleByteSource`:

- Uses existing `StudioFileIdentity` classification to route **native paths** to a native file reader and **Android document URIs** to the SAF reader, requiring the Android environment.
- Properly converts `file://` URIs through `Uri.toFilePath` before native read, rather than calling `File('file://...')`.
- Fails closed for remote and opaque schemes. Never treats a `content://` URI as a local file; revoked Android grants do not trigger an unsafe native fallback.
- Parses SRT, WebVTT, ASS and SSA through existing `SubtitleParser`; document IDs without extensions are allowed when the content has a recognized subtitle signature.
- Preserves strict UTF-8 decoding from the old secondary-subtitle path; broader encoding/BOM behavior stays scheduled for CP89.
- Removes raw file paths and exception messages from key VideoRepository save/secondary-access log statements.
- `VideoRepository` now receives an optional reader in its existing constructor. Existing call sites and `EditorPreferencesRepository` remain source-compatible; no Isar schema or preference key change is required.
- The optional secondary recovery path retains user-selected references when the document becomes inaccessible, allowing users to reconnect. Existing ephemeral legacy extraction cleanup remains intact.

## Automated coverage

`test/secondary_subtitle_document_reader_test.dart` verifies typed native/SRT, Android SAF routing, opaque WebVTT provider ID, converted file URI, revoked grant, non-Android document rejection, remote/opaque URL refusal, unsupported extension and invalid UTF-8 handling.

`test/video_secondary_recovery_integration_test.dart` now verifies through **Isar-backed VideoRepository** that a direct SAF subtitle loads without native fallback, and a revoked document does not block primary subtitles or delete the reconnectable URI. A restored fake provider grant reads the original stored document again.

Only Flutter analyzer/tests are run in GitHub Actions. **No Android, Windows, Linux, macOS, iOS or Web builds belong in CI.**

## Qualification boundaries

This is code-level validation of *secondary subtitle reads*, not general Phase 7/native SAF completion. Physical Android content resolver, permission persistence/revocation and desktop file-URI smoke checks are pending. `VideoRepository` still owns video-path persistence and macOS bookmark resolution; the broader project/import/video file I/O audit continues in CP88 R5. The project's source view, desktop preview and frozen waveform experiment are not changed here. No user files are modified by this checkpoint.

## Latest CI

The exact Flutter-only quality gate and pass count will be added after verification.
