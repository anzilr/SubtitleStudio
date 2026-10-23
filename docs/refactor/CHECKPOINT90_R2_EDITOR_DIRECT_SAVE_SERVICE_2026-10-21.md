# SubtitleStudio — CP90 R2: Editor direct-file Save service

Date: October 21, 2026
Branch: `refactor/riverpod-architecture`
Verification: Linux/Windows/macOS Flutter CI passed; no platform builds

## Change

The main Editor's Save action previously compiled a plain SRT string and wrote
it directly via platform-specific branches. These paths silently assumed UTF-8
even if Project Settings had selected another encoding; macOS bookmark-based
saves also bypassed the shared byte writer.

R2 extracts a small, injectable `EditorDirectSaveService` with:

1. Validated SRT bytes prepared **before** obtaining file permissions or
   touching any destination. Empty edited cue text remains an empty cue.
2. The original Android SAF document URI as the sole authoritative destination
   when one is stored. Revoked grants never redirect to a display/cache path.
3. An explicit macOS bookmark adapter: resolve the saved security-scoped
   bookmark, write to its resulting native path, and release in `finally`.
   Without a usable bookmark, direct Save is unavailable and the existing
   Save As UI is retained; an outdated stored path does not confer access.
4. A typed outcome for saved/unsaved and successful legacy-path migration.
   Repository metadata changes remain the Editor controller's responsibility.

The service reuses the extracted CP90 R1 `EditLineFileSaveService` encoded-byte
compiler and `SourceViewFileAccess` writer; neither the Editor widget nor its
action handler now perform platform file writes. No Isar schema, `.msone`
serialization, checkpoint logic, or mobile visual structure changed.

## Regression coverage

`test/editor_direct_save_service_test.dart` covers:

- UTF-16BE BOM exact bytes with deliberately empty edited text.
- Original Android SAF URI versus a tempting legacy display path, including
  denied document writes without a second destination.
- Existing legacy native-path save and the subsequent metadata-migration hint.
- Unrepresentable Windows-1252 characters aborting before a bookmark or write.
- macOS bookmark decoding, byte save and unconditional release after both
  successful and unsuccessful native writes; absent, malformed and revoked
  bookmarks never silently write to the old native path.
- Real host save through a percent-escaped `file://` URI and UTF-8 BOM.

This regression file was added to the opt-in Windows/macOS file-sensitive
workflow. Linux full Flutter tests and analyzer, plus Windows/macOS targeted
Flutter tests and analyzers, are requested through separate checkpoint markers.
CI performs **no Android/iOS/desktop app builds**.

## Accepted automated gates

- [Linux full Flutter suite](https://github.com/anzilr/SubtitleStudio/actions/runs/39651652550):
  **650 tests passed**, analyzer clean.
- [Windows/macOS targeted host Flutter suites](https://github.com/anzilr/SubtitleStudio/actions/runs/39651652728):
  **119 tests passed on Windows and 119 on macOS**, both analyzers clean,
  including all eight new Editor direct-save regression tests.
- Native Android/iOS/desktop file-provider behavior is **not** counted as
  accepted by these automated tests.

## Remaining acceptance

- Observe Android on-device Save to an authorized SAF document and revoked
  grant leading to Save As, without modifying a cache/display file.
- Verify macOS sandbox bookmark resolution/renewal and access release in a
  native application, and exercise Windows/Linux existing-path permissions.
- iOS file-provider behavior is covered only by simulated adapters here; an
  iOS device/simulator export smoke test is still required.
- End-to-end Source View raw newline fidelity through structured Editor Save
  needs further testing/compatibility work. Import/Open blank cue preservation
  was separately addressed in CP89 R3; this checkpoint does not alter it.
- Continue CP90 extraction of mixed media, state and persistence handling,
  then CP91 history/mobile UX, CP92 audit and CP93 acceptance before connecting
  the production desktop workspace.
