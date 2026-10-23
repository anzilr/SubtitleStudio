# CP87 R12 — Page-route barrier origin diagnostic (October 20, 2026)

## R11 physical-device evidence

The R11 file `cp87_r11_barrier_owner.log` (OnePlus CPH2381, Android 14) proves:
- The main menu barrier removed at **18:10:11.477** and the choice sheet barrier removed at **18:10:12.651**.
- MSone submission popped at **18:10:17.119**, disposed at **18:10:17.614**, and its overlay completed at **18:10:17.617**.
- The observed Navigator at **18:10:17.619** had exactly two active `MaterialPageRoute`s: Home (not current; one of two entries mounted) and Editor (current; both entries mounted). No recently popped route remained mounted.
- The first 12 hit-tests returned `ModalBarrier` with `_ModalBarrierGestureDetector` and `_RenderTheater`; root DOWN+UP events continued, but neither Editor nor Home registered a tap.
- Android Back popped Editor at **18:10:23.902**, and it disposed at **18:10:24.405**. Home loaded three sessions correctly, yet still did not receive touches.
- The R11 probe stopped hit-testing at touch #12 *before* testing Home, and therefore cannot identify which page's barrier consumed the Home touches.
- No current `SIGSEGV` in the capture; the independent media_kit hot-restart crash remains unresolved.

A Flutter `ModalRoute` has two entries, normally barrier first and route content second. A plain `MaterialPageRoute` barrier can appear in hit-test results whenever content above it doesn't accept the hit. Seeing `ModalBarrier` alone **does not prove a stale popup route**.

## R12 implementation (debug-only diagnostics)

- Record per-route animation and secondary-animation statuses, offstage state, and the mounted/opaque/maintainState attributes of *both* overlay entries.
- Label the barrier hit-test listeners of **Editor** and **MSone submission** separately with `MSone barrier OWNER=...`. The debug wrapper uses `HitTestBehavior.deferToChild`, retaining original `MaterialPageRoute` transitions and gestures. Release returns the original barrier.
- Preserve hit-test traces for the first three root taps on Home **after Editor Back**, not only the first twelve in Editor.
- Add a unit contract that the annotated route keeps default opaque/maintainState semantics.
- Do not remove routes, force-dismiss Navigator entries, change user data, Isar schema, or media_kit dependencies.

## Next device procedure

Update `refactor/riverpod-architecture` then, in the log window:

```powershell
.\tool\capture_android_back_log.ps1 -Device CPH2381 -Fresh -Output cp87_r12_barrier_route.log
```

In another terminal:

```powershell
.\tool\run_android_clean_debug.ps1 -Device CPH2381
```

Repeat Editor → Main menu → Submit to MSone → Existing Translator → Android Back → Editor taps → Android Back → Home taps. Look for `MSone barrier OWNER=`, `MSone input: ROUTES`, `MSone input: HITTEST owner`, and post-Editor Home hit-tests. **Do not hot restart or clear app data.**

Only accept an actual fix after a physical device confirms taps work on both pages.
