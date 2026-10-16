# SubtitleStudio — Unified Component Design Contract

Date: 2026-10-16
Status: **Approved requirement; shared component theme foundation implemented; full screen-by-screen migration pending**
Working branch: `refactor/riverpod-architecture`
Related: [Refactor Roadmap V4](REFACTOR_ROADMAP_V4.md), [UX Roadmap](SUBTITLESTUDIO_UX_ROADMAP_2026-10-16.md), [Three-Skin Plan](STUDIO_SKINS_IMPLEMENTATION_PLAN_2026-10-16.md), [SKIN-4 R2 Pilot](STUDIO_SKIN4_CUE_FIELD_PILOT_2026-10-16.md).

## Decision

The app must have **one coherent visual and interactive component system**, not separate per-feature styling. Apply consistently to:

- Modal bottom sheets, draggable sheets and full-height/scrollable sheets.
- Alert/confirmation/progress dialogs and popover/dialog content.
- Popup menus, context menus, Material dropdown menus and dropdown button menus.
- Sliders, ranges, segmented controls, switches and selection controls.
- Filled primary, outlined secondary, elevated/tonal, text, icon and destructive buttons.
- List rows, input fields, tooltips, toast/snackbar/inline validation and focus indicators.
- Mobile/tablet/desktop adaptations: consistent identity, accessible modality (modal sheet on narrow displays; appropriately sized dialog/popup on wide screens where useful).

**One component specification across all three skins and Light/Dark/Classic.** A community-created skin can change its **12 semantic colors** but must not define arbitrary layout, widgets, gestures, radii, fonts or executable styles; all imported skins use the same Flutter component themes and accessible controls.

## First audit findings (October 16, 2026)

Existing UI embeds local, unrelated styling, often bypassing Material themes:

| Existing implementation | Observed mismatch | Migration target |
|---|---|---|
| `lib/widgets/bottom_modal_sheet.dart` | Sheet radius 20, action chips with different decorative blue/green/orange/purple/red colors, ad-hoc muted opacity | Shared sheet radius and spacing; semantic action color, red only for delete |
| `lib/widgets/settings_sheet.dart` | Independent sheet background/radius and hard-coded indigo icon | Shared sheet surface and appropriate icon roles |
| `lib/widgets/delete_confirmation_sheet.dart` | Radius 20, separate background and button shapes, hard-coded red/orange | Shared sheet + `scheme.error` for destructive control, warning semantics |
| `lib/screens/edit/widgets/edit_selection_dialogs.dart` | Repeated manual sheet shape 20 and several bespoke confirmation panels | Shared confirmation/dialog/sheet primitives |
| `lib/widgets/formatting_menu.dart` | Popup radius 16, separate sheet shape and local orange/blue styles | Theme-level popup/menustyle and functional subtitle formatting roles |
| `lib/screens/edit_line/widgets/edit_line_menu.dart` | Popup radius 12, assorted hard-coded icon colors | Shared popup geometry and semantic primary/danger/status icons |
| `lib/widgets/unsaved_changes_sheet.dart` | Hard-coded teal confirm and red discard, custom button text/foreground | Theme-level buttons, keep destructive action role |
| Other screen-level button/slider/dropdown uses | Shape, dimensions and colors vary per caller | Remove bespoke `styleFrom` unless behavior and status require an exception |

This is a **targeted initial inventory**, not a claim that every UI file is already migrated. A final inventory of all call sites is required in DESIGN-2.

## Canonical tokens and styling

`StudioComponentThemes.apply(ThemeData)` is the single Material component theme layer used by both legacy `AppThemes` and the new `StudioThemeFactory`. It resolves semantic color roles from `StudioDesignTokens`; do not embed `#hex` or a skin name in UI component code.

| Component | Shape/spacing | Semantic role |
|---|---|---|
| Modal sheet | Top corners `StudioRadius.sheet` (16); standard handle/safe-area behavior; standard horizontal padding `StudioSpacing.md` (16) | `surface` + `onSurface`, `mutedText` and `outline` |
| Dialog | All corners `StudioRadius.sheet` (16), app-standard outer inset | `surface`/`onSurface`; destructive confirmations use error/contrast text |
| Popup/context/menu | All corners `StudioRadius.card` (12) | `raisedSurface`, `onSurface`, outlined; selected/disabled states semantic |
| Dropdown | `StudioRadius.input` (8) input, `card` menu; shared field padding | `fieldSurface`, `fieldBorder`, `focusBorder` |
| Slider | Track height 4; shared thumb/value indicator | `primaryAction`, `outline`, `disabledText` |
| Filled primary action | `StudioRadius.input` (8), min hit size 48 dp | `primaryAction`/`onPrimaryAction` |
| Elevated and outlined secondary | Same 8 radius / 48 dp target | `raisedSurface`/`onSurface`, `fieldBorder` |
| Text, icon, segmented controls | Same 48 dp minimum hit size and visual rhythm | semantic foreground; selected/disabled distinct |
| Destructive actions | Same geometry, not decorative red chips everywhere | actual `ColorScheme.error`/`onError` on explicit dangerous action |
| Source/edited/time inputs | `StudioCueFieldSurface`/`StudioTimeField` use 8 radius and shared input tokens | `fieldSurface`, `onSurface`, `mutedText`, focus and validation roles |

The styling contract preserves **interaction behavior**: keyboard shortcuts, focus traversal, Navigator results, clipboard actions, async confirmation, IME, undo/selection, sliders' min/max/divisions/onChanged values, dropdown selected state and popup choice callbacks.

## Migration gates

| Milestone | Description | Status |
|---|---|---|
| **DESIGN-0 — inventory/contract** | Approve component types, sizing, semantics, platform adaptations and a concrete UI-debt ledger | **Started** |
| **DESIGN-1 — shared styling** | `StudioComponentThemes.apply` shared by old + new theme factories; tests for all 9 new palettes + 3 legacy modes | **Implemented; verify CI** |
| **DESIGN-2 — migrate callers** | Replace one-off layout/styling in sheets, dialogs, popups, dropdowns, sliders, buttons. Begin with subtitle action sheet pilot, then Settings/Edit Line/Editor confirmations, formatting and session tools | **Pilot in progress; bulk migration pending** |
| **DESIGN-3 — visual/a11y acceptance** | Goldens/visual snapshots, 320dp + tablet + Windows width, RTL/Malayalam, 200% scaling, focus/hover/pressed/disabled, modal keyboard scroll, no sheet overflow | **Pending** |

**SKIN-4 R3 is blocked on the contrast-critical DESIGN-2 sites**, notably Editor and Edit Line menus, formatting popups, toolbar and destructive actions. Remaining low-risk surfaces can finish in SKIN-5; full DESIGN-3 belongs with SKIN-6 Android/Windows native acceptance.

### Implementation rules for contributors

1. Prefer `Theme.of(context).bottomSheetTheme`, `dialogTheme`, `popupMenuTheme`, `menuTheme`, `dropdownMenuTheme`, `sliderTheme`, `filledButtonTheme`, `outlinedButtonTheme`, etc. A new feature should not pick its own corner radius or accent for these components.
2. Prefer existing `StudioSurface`, `StudioSectionHeader`, `StudioPrimaryAction`, `StudioCueFieldSurface`, `StudioTimeField`. Add focused reusable wrappers only when Material theme cannot express the intended structure, never a new isolated style system.
3. Distinguish **action role** from decoration: warn = caution and icon + text, delete = error and explicit action label, normal = primary/neutral. Subtitle font colors are project content, not Material UI decoration.
4. Keep mobile-first interaction and sheet presentation, but adapt width and modality on desktop without inventing another design language. Preserve mouse/keyboard semantics.
5. A component-level override is allowed for a genuine feature need only if it is explicit, documented and accompanied by theme contrast/accessibility coverage.
6. Do not rebuild or replace Editor/Edit Line controllers, routes or underlying Riverpod state when changing appearance.
7. Check for multiple nested drag handles, stacked shapes, duplicate safe-area padding and input labels when migrating older custom sheets.
8. Re-test under **all nine skins** (including Classic near-black), three legacy modes while still supported, and future community palette definitions.
9. Do not touch CP86 native waveform behavior to change component styles.
10. Keep work in `refactor/riverpod-architecture`, use grouped Flutter analyze/tests gates and device test before declaring the rollout release-ready.

## CI/test expectations

- Unit/widget tests assert same modal/dialog/menu/button shapes and sizes under every built-in skin and legacy theme, and retained semantics of bottom sheet/dialog navigation.
- Device visual gate includes sheet keyboard dismissal, long translated labels, dropdown overflow, screen-reader announcements, high-contrast disabled/selected/focused states, mouse hover and large text.
- Report code implementation, CI verification and physical Android/Windows verification separately.
