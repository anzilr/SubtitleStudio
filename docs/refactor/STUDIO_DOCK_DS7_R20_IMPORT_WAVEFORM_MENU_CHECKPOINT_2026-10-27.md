# SubtitleStudio — DS7 R20 SRT-only import and Studio Dock interaction checkpoint

Date: 2026-10-27  
Branch: `feature/studio-dock-integration`

## Requested changes

1. **SRT-only external imports, for now.** Desktop File picker and the
   non-UI import service accept `.srt` or `.msone` projects, but reject
   direct `.vtt`, `.ass` and `.ssa` subtitle imports before creating a
   session. Mobile SRT picker uses only `.srt`, and its import confirmation
   rejects unsupported Android intents instead of relabeling the filename.
   External secondary subtitle pickers in Project Settings and the secondary
   sheet are also limited to SRT. The internal VTT/ASS parsers remain for
   future format support and embedded video subtitle tracks.
2. **SRT source protection.** Imported `.msone` archives may still contain
   links to older VTT/ASS/SSA files. The shared direct-save service refuses
   such sources even if the saved display filename says SRT. On macOS the
   resolved bookmark must also point to an SRT. Normal Save can then offer
   Save As; the non-SRT source must remain untouched.
3. **Backup wording.** `Full Backup` strategy description now reads “Full
   Backup: faster restore, more storage”, consistent with “Full Backup Only”
   in the chooser. `Smart Backup` remains the user-facing name of the
   internally persisted `hybrid` value; no settings data migration.
4. **Waveform pointer behavior.** The wheel listener now wraps the entire
   waveform stack, including painted subtitle overlays and time readout.
   Trackpad two-finger `PointerPanZoomUpdateEvent`s scroll/seek the waveform;
   they are excluded from the GestureDetector that drags subtitle handles or
   overlays. A primary click-and-drag still moves/adds/edits overlay bounds,
   preserving mobile touch-drag interaction.
5. **Secondary subtitle access.** Added a top-toolbar button, visible when
   the live host provides `onLoadSecondarySubtitles`, which calls the same
   existing loader as the Media menu.

## Revised Studio Dock menu map

| Menu | Actions |
| --- | --- |
| **File** | New project; Open SRT / Import project; Save subtitle; Save As; Export SRT; Save project/Save Project As; Project Settings; Application Settings |
| **Edit** | Undo/Redo; Find & Replace; select/range/go-to/copy; Paste Original (Translation Mode); Bold/Italic/Text color |
| **Subtitle** | Add, delete, split, combine, selected delete; Subtitle tools; Remove Hearing Impaired |
| **Timing** | Start/end, sync, shift all/selected |
| **Review** | Review notes, quality check, marked lines, import `.msone` comments |
| **Tools** | MSone/Olam/Urban dictionaries, MSone banners, Malayalam Normalize, MSone submission |
| **View** | Explorer/inspector/video/waveform panels, original-text display, formatted view, Source View, edit history |
| **Media** | Attach/change/unload video, load/show/hide secondary subtitles, fullscreen, repeat current/range, floating playback button |
| **Help** | Direct documentation action |

All actions retain the same callbacks and history services. Menu-triggered
New/Import/Attach actions await the departing popup route before launching
new picker/dialog routes.

## Source tests and acceptance

- `studio_dock_project_actions_test.dart` rejects VTT/ASS/SSA and proves no
  session was created or source content changed.
- `editor_direct_save_service_test.dart` refuses non-SRT native source paths
  and misleading SRT display filenames while allowing normal SRT/SAF paths.
- `studio_dock_secondary_subtitles_widget_test.dart` checks top toolbar
  dispatch and hides the button without a valid callback.
- Studio Dock menu/widget test files have been updated for the relocated
  commands and the File new/import popup lifecycle.
- **Native acceptance still required:** mouse wheel and two-finger trackpad
  over add-line and edit-line overlays; primary drag of center and handles;
  Windows popup/focus; SRT import, `.msone` import, Save and Save As; Mac/iOS
  bookmark/SAF paths; 820–1366px desktop widths.

Policy: GitHub Actions Flutter `pub get`/analysis/tests only. No platform
builds in Actions. This document is implementation evidence, not native QA.
