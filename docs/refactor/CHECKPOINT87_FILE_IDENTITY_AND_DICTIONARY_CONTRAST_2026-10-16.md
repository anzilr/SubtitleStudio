# SubtitleStudio — CP87 R1 typed file identity and dictionary-tab contrast

**Date:** 2026-10-16  
**Branch:** `refactor/riverpod-architecture`  
**User-supplied Android device:** CPH2381 / Android 14 / 360dp  
**CP87 R0 dictionary fix:** [`999f4a1`](https://github.com/anzilr/SubtitleStudio/commit/999f4a167903a008db1a5aa427b05cb768e1b702)  
**CP87 R1 technical implementation:** [`50bd1c0`](https://github.com/anzilr/SubtitleStudio/commit/50bd1c041ef0ada113937826d9975073cddc7020)  
**Flutter CI:** [Dictionary gate 38961699279](https://github.com/anzilr/SubtitleStudio/actions/runs/38961699279); [CP87 gate 38961927133](https://github.com/anzilr/SubtitleStudio/actions/runs/38961927133). Check their completion and test counts.  
**CP86:** Android/Windows full native qualification, cold extraction speed and the prior unsymbolicated `libmpv.so` hot-restart SIGSEGV remain open. CP87 does not waive this safety gate.

## Reproduced Olam dictionary issue: language tabs

The old Olam language selector used `primaryColor` for the selected
background and always used `Colors.white` for the selected label. This is
unreadable in Carbon Zero Dark (`#E3E3E3` primary) and Carbon Zero Classic
(`#FFFFFF` primary). The existing primary/onPrimary fix for the separate
Search button had not reached the three language tabs.

`DictionaryLanguageTabColors` now uses a dark, neutral
`colorScheme.surfaceContainerHigh` with `onSurface` text for achromatic
dark themes, plus a visible outline to indicate selection; colorful skins and
all light modes retain their previous primary-background treatment and now
use the paired `onPrimary` text role. The interaction and selected-tab
animation remain unchanged. Regression tests check selected-state
contrast >=4.5 across all 4 built-in skins × 3 appearance modes.

No skin factory, global button theme, subtitle formatting or appearance
features were reopened.

## CP87 R1 scope: value type first, migrations later

`StudioFileIdentity` is an immutable, equality-comparable value class in
`lib/core/file_access/`. `fromLocator` recognizes:

| Kind | Example | Local filesystem stat allowed? |
|---|---|---|
| `nativePath` | POSIX path, Windows drive/UNC path | Yes |
| `androidDocument` | Android `content://` provider document | No |
| `fileUri` | `file:///tmp/subtitle.srt` | No, until explicitly resolved |
| `remoteUri` | HTTPS or RTSP media | No |
| `opaqueUri` | Decoder-specific protocol such as `saf:1.mkv` | No |

The underlying string is deliberately preserved for compatibility with
existing persisted video/source paths and stable cache identities. A path or
URI is a **locator, not permission**: neither parsing nor equality grants
SAF read access, obtains a macOS sandbox bookmark or validates source content.
Invalid/empty SAF URIs are rejected; the value's `toString` includes only
the kind and deliberately suppresses sensitive path or URI components.

This small typed boundary is adopted without changing persistent data schemas:

- Waveform cache identity only performs a local file stat on native paths.
  Existing cache hash inputs and audio-track/revision scoping remain unchanged.
- The waveform processor distinguishes Android SAF documents with the same
  identity model, still uses explicit FFmpegKit SAF read handles.
- The Android document revision probe only targets valid SAF documents.
- VideoRepository adds `getSavedVideoIdentity(collectionId)` alongside
  `getSavedVideoPath`; bookmark resolution and Isar values are untouched.
- Android secondary subtitle parsing uses the typed SAF classification before
  dispatching to the existing `SafFileHandler`.

## New Android log review (October 16, 23:14–23:17 local)

An Android debug APK was assembled and installed successfully from the prior
`1b77824` branch. The existing long MKV's waveform was loaded from cache:

```text
AudioProcessor: Processing complete:
  source=3731ms downsample=0ms zoom=23ms total=3755ms
  decoded=20635510 display=20635510 zoomPixels=0
```

There is no FFmpeg extraction step in this run, consistent with a cache hit.
The log contains a PlayCore `ERROR_APP_NOT_OWNED (-10)`, which is expected
for a debug-sideloaded APK. It ends with `Lost connection to device` after
other device/input activity and a PowerShell prompt to terminate the batch.
There is **no native SIGSEGV backtrace in this particular submitted log**.
This alone neither proves nor resolves the **earlier** observed
`libmpv.so` teardown crash.

## Next staged work

1. Physical verification of the Olam EN–ML / ML–EN / ML–ML states in Carbon
   Zero Dark and Classic on CPH2381, including narrow 360dp sizing.
2. Continue CP87 incrementally: typed file access results and grant
   metadata, then Source View read/write boundaries; do not silently migrate
   legacy paths or expose raw document URIs in error logs.
3. Keep saved video and secondary-subtitle behavior intact and add integration
   tests before changing persistence.
4. Return to CP86 for Android hot-restart native lifetime isolation, cold
   waveform extraction profiling and Windows native file/SAF alternates.
5. Do not begin new skin UI, desktop design, platform upgrades, or bulk
   unrelated refactors during these technical gates.
