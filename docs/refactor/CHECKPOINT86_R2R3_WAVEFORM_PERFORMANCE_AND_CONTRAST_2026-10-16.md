# SubtitleStudio CP86 R2/R3 — Android waveform speed and reproduced UI regressions

**Date:** October 16, 2026  
**Branch:** `refactor/riverpod-architecture`  
**Code under test:** `061bae99` (R2 performance `85c8f910`, R3 colors/search `7aaf7c38`, import contrast follow-up `061bae99`).  
**Baseline CI:** [R2 38944366683](https://github.com/anzilr/SubtitleStudio/actions/runs/38944366683) — 478 passing Flutter tests, zero analyzer issues.  
**Combined UI CI:** [38945025518](https://github.com/anzilr/SubtitleStudio/actions/runs/38945025518) — **SUCCESS**, 491 Flutter tests passed, 0 analyzer issues at code `061bae99`.  
**Native approval:** PENDING Android 14 and Windows; no Kotlin/FFmpegKit binary build or physical device run in Linux Flutter CI. No appearance redesign; only reproduced accessibility/functional color regressions.

## Diagnostic evidence from Android debug log

The attached user log opens a long MKV through `content://com.android.externalstorage.documents/...` on the OnePlus CPH2381. Media Kit obtained an Android file descriptor. Waveform extraction used FFmpegKit `saf:1.mkv` and the old 44,100-Hz mono PCM extraction path. The final timing was:

| Stage | Measured debug log |
|---|---:|
| Source acquisition, including FFmpeg decode and compact peak reduction | 183,294 ms |
| Downsampling after the reduced buffer | 0 ms |
| Zoom metadata generation | 31 ms |
| Total waveform processing | 183,327 ms |
| Reduced waveform samples | 20,637,381 |
| Materialized zoom pixels | 0 |

This log proves the delay is overwhelmingly **source acquisition**, not Flutter's 25 zoom descriptors. It does not separately time FFmpeg decode versus peak reduction. The earlier R6 historical raw cache on the same movie had 330,198,104 mono samples (~660 MB) before compact reduction. The UI log also repeatedly reports Flutter's `ListTile background color or ink splashes may be invisible` warning (colored DecoratedBox between ListTile and its nearest Material); no authoritative Android OOM/native crash stack is present in the provided snippet.

## R2 — faster cold-generation I/O and safer repeat loads

- New compact FFmpeg extraction requests **2,756-Hz s16le mono** instead of creating another full 44,100-Hz raw PCM file. This reduces intermediate PCM sample/byte count by approximately 16× for the same duration. Audio must still be decoded; it is **not** yet proven that cold-generation wall-clock time improves by 16×.
- `WaveformPeakCache` retains **V1**, with 16-sample mean/min/max records, and adds **V2**, with 2-byte direct reduced PCM records under a distinct header version and checksum. Old V1 files remain readable; the same `.pk1` naming convention is retained because the header controls interpretation. New V2 cache size is ~2 bytes per reduced sample instead of 6 bytes for V1.
- Android `MainActivity` now exposes `getDocumentRevision` over the existing SAF channel. `WaveformSourceRevision` accepts a positive provider-reported document size and last-modified timestamp, and `WaveformCacheIdentity` uses both in the key. Unversioned/metadata-limited providers stay uncached. Files that share size and reported modified time cannot be distinguished by this metadata alone; treat provider metadata as a best-effort freshness indicator.
- Existing native URI read-grant validation, cancellation, stale request guards, source-scoped cache lock, staged cache writes and checksum validation remain in place.
- Added tests for V1/V2 readback and tampering, FFmpeg low-rate command selection, SAF cache key revision invalidation and metadata acceptance.

**Expected improvement:** much less raw PCM temporary I/O and more repeat-load cache hits on version-reporting document providers. **Not yet measured:** real FFmpegKit decoder time, first-load/second-load milliseconds, fidelity/PTS alignment and Kotlin-native metadata availability on CPH2381. Do not claim physical speedups before retest.

## R3 — user-reported appearance/interaction bugs (narrow exception only)

- Restore original functional wave-control identities: orange zoom/overlap, red magnet/cancel/playhead, teal add subtitle, green confirm and blue auto-scroll. A feature-local `WaveformControlColors` keeps these functional meanings distinct, without changing the global four-skin theme system or subtitle-authored color tags.
- Olam and Urban dictionary Search buttons now share `DictionarySearchAction`, using the actual `primary/onPrimary` pair with inherited label/icon colors instead of hardcoded white. Regression tests cover every built-in skin × Light/Dark/Classic.
- Both dictionary search/filter headers now use an internal `Material` surface rather than a decorated-only header. Their `CheckboxListTile` ink/splash and background are no longer painted behind an intermediate decorated surface. Actual log assertion removal needs Android verification.
- Corrected an independently located Import Subtitle primary button that forced a white download icon instead of `colorScheme.onPrimary`.
- No other appearance work, desktop screen redesign or community-skin work has resumed.

## Android retest — OnePlus CPH2381 (debug first)

```powershell
git fetch origin
git switch refactor/riverpod-architecture
git pull --ff-only origin refactor/riverpod-architecture
flutter pub get
flutter run --debug -d CPH2381 --dart-define=MS_ONE_WAVEFORM_TRACK_SYNC=true
```

Use the original Ballerina MKV. First toggle waveform, then close and reopen the same session twice; compare time-to-ready and look for `-ar 2756` in the debug FFmpeg command. On the second open, a genuine compact cache hit should avoid the FFmpeg extraction message. If document revision metadata is unavailable, a new extraction is expected for SAF rather than silently reusing stale audio. Do **not** clear old subtitle projects/Isar to force the test; use another disposable media file or audio track for cold-run comparisons.

Also test two different audio streams (Auto and explicit), rapid switching, hide/close/reopen during extraction, playback/seek/zoom/auto-scroll and correct sounding versus visible waveform including shifted PTS. Open Olam and Urban dictionaries on Carbon Zero Dark and Classic; check black text/icons on their light primary Search buttons, checkbox taps, and no `ListTile background color or ink splashes may be invisible` assertion. Inspect Import Subtitle icon and colored waveform controls at approximately 360dp.

Measure native memory/frames in profile mode:

```powershell
flutter run --profile -d CPH2381 --dart-define=MS_ONE_WAVEFORM_TRACK_SYNC=true
adb -s CPH2381 shell dumpsys meminfo org.malayalamsubtitles.studio > cp86_r3_meminfo.txt
adb -s CPH2381 logcat -b crash -d -v time > cp86_r3_crash.txt
adb -s CPH2381 logcat -b main -b system -d -v time > cp86_r3_system.txt
```

Capture debug timings for first cold run and cache reopen; peak cache size, memory/CPU and any native Exceptions. Redact private file names/document IDs in shared logs. Manual Android acceptance has **not** been performed by this CI checkpoint. For Windows, use the CP82 synthetic multitrack MKV and compare explicit tiled mode versus existing eager mode, keeping the editor architecture and appearance frozen.

## Acceptance state / next technical step

Flutter CI validates only Dart/analyzer/widget/service regressions on its Linux runner. CP86 is not complete until actual Android/Windows builds and native timing, URI revision behavior, cache reload, track correctness, cancellation and UI assertions are checked. If a **cold** decoding run remains excessively slow after low-rate extraction, investigate bounded progressive/visible-range waveform decoding in a later isolated CP86 patch rather than allocating full legacy PCM or reducing cache safety. Then return to typed file identity/persistence ownership and other technical roadmap work.

## Verified CP86 R3/R4 Flutter quality gate

On 2026-10-16, [GitHub Actions 38945025518](https://github.com/anzilr/SubtitleStudio/actions/runs/38945025518) completed **success** against code `061bae99`. The runner reported `No issues found!` for Flutter analysis and `491 tests passed.` New coverage includes the reduced peak V2 cache/SAF revision logic and twelve theme combinations for the dictionary primary action. This confirms code-level correctness only: the Android Kotlin document-revision method, performance, actual render contrast, and absence of real-device ListTile assertions still require physical acceptance.
