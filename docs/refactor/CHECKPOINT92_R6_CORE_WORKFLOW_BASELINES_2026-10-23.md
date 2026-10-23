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
- Initial Linux GitHub quality gate
  [39946376552](https://github.com/anzilr/SubtitleStudio/actions/runs/39946376552)
  completed **783 passing tests** and recorded the measurements below. It
  reported one nonfatal unused-import analyzer warning in this new test. That
  import was removed; the final clean analyzer gate is pending.
- No Android/Windows/macOS/iOS application builds in GitHub Actions.

## First Linux CI baseline (1,000 synthetic cues, three samples)

| Stage | Median | Maximum |
| --- | ---: | ---: |
| Import, SRT → Isar | 49.94 ms | 149.82 ms |
| Open, Isar collection read | 1.27 ms | 13.45 ms |
| Save, encode and native overwrite | 5.47 ms | 16.86 ms |
| Restore, reconstruct V2 history and transact | 33.82 ms | 57.53 ms |

All values came from the synthetic benchmark's single aggregate log line.
They describe a shared Linux Actions runner, not user-device wall time.
The widest spread occurs in initial import/open iterations where host cache
and JIT warmup affect timings. These are baseline observations only.

## Next

CP92 R7: usage-confirmed compatibility shim cleanup, carefully preserving
legacy `.msone` and older Isar project semantics. CP93: final automated and
native device acceptance. The CP86 progressive waveform branch stays frozen.
