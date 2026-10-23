# SubtitleStudio — CP92 R6: Core workflow performance baselines

Date: October 23, 2026  
Branch: `refactor/riverpod-architecture`

## Scope

Measure the currently shared subtitle-processing service boundaries without
changing their implementation. Use a deterministic, entirely synthetic SRT
fixture with 1,000 cues, including deliberately empty cues, multiline text
and Malayalam characters. Run three repetitions against an isolated real Isar
database and a temporary native file, and report only stage names, cue count,
repetition count, median and maximum elapsed milliseconds.

| Stage | Timed production boundary | Excluded work |
| --- | --- | --- |
| Import | Context-free SRT parse/normalization and Isar collection/session storage | File picker, external filesystem reads and native SAF grants |
| Open | Read a stored subtitle collection and its embedded lines from Isar | Media player start, thumbnail generation and UI frames |
| Save | Editor's direct-save encoding validation and overwrite of an existing temporary native SRT | User Save As picker and network/cloud storage |
| Restore | V2 checkpoint snapshot reconstruction and guarded transactional restore into Isar | Branch selection UI, device-specific database startup |

## Method and safeguards

- New `test/core_workflow_performance_baseline_test.dart` exercises the real
  `processSubtitleContentWithoutContext`, `SubtitleImportRepository`, Isar
  collection read, `EditorDirectSaveService`, `CheckpointReconstructor` and
  `CheckpointStore.restoreCollectionAndActivateOnly` methods.
- The benchmark verifies actual state: 1,000 stored cues, saved SRT roundtrip,
  restored text, restored checkpoint HEAD. Setup, source generation, fixture
  hashing and result verification are outside each corresponding timer.
- Multiple repetitions are independent imports and checkpoint histories.
  The test's synthetic media identity is never printed in its result line.
- No strict timing threshold: shared CI CPU/IO, JIT warmup and host load vary.
  Medians and maxima are **reference measurements**, not target SLAs or
  evidence of native Android/Windows performance.
- Import/open/save/restore paths, format serialization, SAF permissions,
  checkpoint semantics, data migrations and UI behavior are not modified.

## Verification

- `git diff --check` locally: clean.
- The final Linux GitHub
  [Flutter quality gate 39947041945](https://github.com/anzilr/SubtitleStudio/actions/runs/39947041945)
  **passed: 783 tests, zero analyzer issues**. The first run
  [39946376552](https://github.com/anzilr/SubtitleStudio/actions/runs/39946376552)
  also passed 783 tests but reported one nonfatal unused-import warning, which
  was removed before the final verified run.
- Verified implementation and analyzer-fix commits:
  `00c97a192058b68c34a890de5279e2ac25dd7cad` and
  `54c7587e9e0081327bda52c51563c937fc84bfb9`.
- No Android/Windows/macOS/iOS application builds in GitHub Actions.

## Verified Linux CI baseline (1,000 synthetic cues, three samples)

| Stage | Median | Maximum |
| --- | ---: | ---: |
| Import, SRT → Isar | 36.77 ms | 98.70 ms |
| Open, Isar collection read | 0.56 ms | 6.80 ms |
| Save, encode and native overwrite | 3.92 ms | 13.18 ms |
| Restore, reconstruct V2 history and transact | 23.33 ms | 45.47 ms |

All values came from the final synthetic benchmark's single aggregate log
line. The first CI run had medians of **49.94 / 1.27 / 5.47 / 33.82 ms**
for import/open/save/restore. The difference between successful runs reinforces
that shared-runner load, caches and JIT warmup affect timings; these are
baseline observations rather than user-device wall times or release targets.

## Next

CP92 R7: usage-confirmed compatibility shim cleanup, carefully preserving
legacy `.msone` and older Isar project semantics. CP93: final automated and
native device acceptance. The CP86 progressive waveform branch stays frozen.
