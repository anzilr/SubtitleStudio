# CP87 R11 — Identify the Navigator barrier swallowing Editor and Home taps

**Log:** `cp87_r9_hit_test.log`, Oct 20, 2026 (17:47:10–17:47:49 Asia/Riyadh)
**Device:** OnePlus CPH2381, Android 14
**Working branch:** `refactor/riverpod-architecture`

## Reproducible findings (R9)

- 17:47:26.936: main menu popup reports barrier removed.
- 17:47:28.734: MSone choice sheet barrier removed; submission page opens.
- 17:47:33.743: Back pops MsoneSubmissionScreen.
- 17:47:34.304: submission widget disposed.
- 17:47:34.308: submission route overlay reports completed; editor mounted, staleLoader=false.
- 17:47:35.271–17:47:38.194: 12/12 hit-tests start with:
  `RenderMouseRegion[MouseRegion] > RenderSemanticsAnnotations[Semantics] > RenderPointerListener[Listener] > RenderSemanticsGestureHandler[_GestureSemantics] > RenderExcludeSemantics[ExcludeSemantics] > RenderBlockSemantics[BlockSemantics] > RenderIgnorePointer[IgnorePointer] > _RenderTheater[_Theater]`.
  This is consistent with a **Navigator modal barrier** intercepting the pointer hits, not Editor widgets.
- 17:47:35–17:47:40: root pointer-down and pointer-up pairs arrive; Editor event count remains **0**.
- 17:47:41.282: Android Back requests Editor exit, and Navigator successfully pops Editor.
- 17:47:42–17:47:43: further root down/up events arrive on Home, but Home count remains **0**.
- At probe completion: 24 root down events, 0 Editor, 0 Home.
- No new SIGSEGV or Flutter framework exception appears in this log.

## What is proven, and what is not

**Proven:** the Android input pipeline delivers complete gestures. A barrier-like render path intercepts hits while Editor and later Home remain mounted/operational. The known R8 popup/sheet/form routes log completion, but the owner of the remaining barrier is **not identified by R9**.

**Not proven:** that an MSone PopupRoute leaked. Flutter MaterialPageRoute can also have a modal barrier, so a render prefix alone does not identify the specific route. Do not forcibly pop arbitrary routes or clear unrelated OverlayEntries.

## R11 diagnostic-only changes

1. On the first three post-return hits, log the first render target's **widget ancestry** to locate `ModalBarrier`, `_ModalScope` and owning route subtree.
2. Track the root Navigator's active route stack and recently popped routes **even before** the post-MSone probe starts.
3. Include route `isCurrent`, `isActive`, total OverlayEntries, and mounted OverlayEntries at return and at the first three hits.
4. Extend the hit-test widget regression with a real DialogRoute blocker to ensure the owner trace can detect a known modal barrier. No production navigation behavior is modified.

## Next physical-device gate

```powershell
git pull --ff-only origin refactor/riverpod-architecture
.\tool\run_android_clean_debug.ps1 -Device CPH2381
```

In a separate PowerShell window first:

```powershell
.\tool\capture_android_back_log.ps1 -Device CPH2381 -Fresh -Output cp87_r11_barrier_owner.log
```

Editor -> Main menu -> Submit to MSone -> Existing Translator -> Android Back -> tap Editor -> Android Back -> tap Home. Upload the R11 log and look for:
- `MSone input: ROUTES at return`
- `MSone input: HITTEST owner #1`
- `MSone input: ROUTES #1`

The independent `media_kit` hot-restart native crash remains open. **Do not use hot restart** during this diagnostic.
