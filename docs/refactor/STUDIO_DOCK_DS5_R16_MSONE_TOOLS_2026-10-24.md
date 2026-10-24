# SubtitleStudio — DS5 R16 MSone Desktop Tools

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Scope
Reintroduce the two **existing** MSone-specific mobile tools to Studio Dock
without duplicating their parsing, normalization rules, banner positioning,
overlap warnings, enabled-banner toggles, or checkpoint history behavior.

- Insert Banners uses `showEditorBannerSheet` and the mobile
  `BannerConfigurationSheet` + `SubtitleBannerOperations.insertBanners`.
  The sheet edits beginning/middle/end content and timing, including position
  recommendations and overlap warnings.
- Malayalam Normalize uses `showEditorNormalizationSheet`, the mobile
  `MalayalamNormalizationSheet`, the existing `MalayalamNormalizer` and
  its selected-change preview/checkpoint save.
- Both actions appear in the native Tools menu and Tools panel only if the
  persisted MSone features flag is enabled for an editable live project.
- The departing popup route must fully close before the modal sheet is
  shown; both use the existing inspector/Source View dirty-draft gate.
- Success callbacks trigger full project snapshot/history reconciliation and
  restore surviving subtitle selection without remounting the native video
  player. Cancel leaves the project unchanged.
- The *Submit to MSone* workflow remains separate and unchanged. No live
  submission is performed by this checkpoint.

## Implementation boundaries
No new MSone API service, banner rules or normalization parser are created.
The mobile UI and service code remain unchanged. The underlying mobile
banner operation currently uses collection replacement with history, not
the same optimistic expected-row guard as normalization; concurrent edits
during an open banner sheet remain an item to verify during native QA.
The desktop bridge reopens the current project data when launching tools.

## Test and acceptance
- Widget tests: setting-off capability gating, popup cleanup/return,
  cancellation with dirty inspector, Tools panel entry and double invocation.
- Existing banner integration/checkbox and MSone feature preference tests
  remain part of the full Flutter regression suite.
- GitHub Actions: Flutter dependency resolution, analyzer, focused Studio
  Dock and full Flutter tests only. No platform builds.

Windows-native acceptance: banner positions, defaults and overlap warnings,
long subtitle lists, Malayalam text preview and selected changes, Undo/Redo,
return focus, toggling MSone features and unaffected submission flow.
