# SubtitleStudio — CP93 R3: Empty-document Source View acceptance

Date: October 23, 2026  
Branch: `refactor/riverpod-architecture`  
Native Android/Windows acceptance: pending

## Confirmed file-access edge case

`SourceViewFileAccessImpl.read` previously treated a successful, zero-byte
Android SAF document read like a missing/failed read. A direct `content://`
document consequently failed to open. If the document had a separate native
cached copy, Source View could instead show *stale nonempty cached content*.
This matters when opening newly created or deliberately empty subtitle files.

Android's `readFileFromContentUri` method returns a successful byte array when
the provider stream opens, including an empty array for an empty file. It
returns an error when access fails. The former must not be mistaken for the
latter.

## Correction and regression coverage

- An Android SAF read now succeeds whenever the platform returns a non-null
  byte array, including zero bytes. `null`/exceptions continue to permit only
  an existing, independently valid native cache fallback.
- `source_view_file_access_test.dart` verifies both direct and cached-path
  empty-document reads, no unwanted cache access, and preserved strict
  fallback behavior for a *null* provider response.
- `source_view_encoding_controller_test.dart` verifies that a zero-byte source
  reaches Source View as initialized, with no artificial cues and raw text
  equal to the empty string.

No Android Kotlin implementation, native picker contract, Isar schema,
encoding format, video-player lifecycle, popup design or desktop layout is
changed. This gate does not change the preservation of empty **subtitle cues**
inside nonempty SRT files, which was already tested separately.

## Verification

- Local `git diff --check`: clean.
- [Linux Flutter quality gate 39954208733](https://github.com/anzilr/SubtitleStudio/actions/runs/39954208733):
  **790 tests passed, zero analyzer issues**. Dependency resolution,
  analysis and tests only; no platform builds in CI.
- Verified implementation commit: `f3c8fba1064cb467ba06550ccf9b5cba52fdc48e`.
- Real SAF grant/revocation and actual Android/Windows runtime smoke: pending.

## Next

Finish CP93 native-acceptance review using the R1 Android/Windows checklist,
including a direct **zero-byte SAF SRT** and an empty SAF SRT with an old
native cache. Check video navigation, MSone back gesture, Source View save,
project roundtrip and media lifecycle before declaring the production
desktop shared core accepted.
