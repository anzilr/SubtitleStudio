# SubtitleStudio community skins — portable v1 contract and open-source roadmap

Date: 2026-10-16
Status: **SKIN-EXT-1 FOUNDATION VERIFIED** — [CI run 38868963345](https://github.com/anzilr/SubtitleStudio/actions/runs/38868963345), **400 tests passed and zero analyzer issues** against code commit `26a2ece34ee8ca627e8dea9943d09662fa00ea74`. App-side file import and website are **NOT implemented**.
Branch: `refactor/riverpod-architecture`
Related: [SKIN implementation plan](STUDIO_SKINS_IMPLEMENTATION_PLAN_2026-10-16.md), [palette matrix](STUDIO_PALETTE_DECISION_2026-10-16.md).

## Goal

SubtitleStudio is open source. Anyone should be able to make a skin without modifying Flutter or rebuilding the app. Community authors can eventually design a skin using a public website, export an ordinary portable file, import it locally on Android/desktop, select it in the Appearance picker, and share it.

**A skin is data; it is never a plugin executing Dart/JavaScript/native code.** This is intentionally narrower than customizing an entire app layout. The same source/edited cue, timeline, controls, type scale, safety states, and semantics remain consistent.

## Architecture: separate identity, definition, resolver and storage

```text
  Built-in definitions          Community JSON .sskin.json
  (3 families × 3 modes)          (future website exports)
          │                              │
          │                      validate + preview
          │                              │
          └─────────> StudioSkinCatalog <┘
                             │
               skinId + appearance mode
                             │
              StudioSkinDefinition.paletteFor(mode)
                             │
                    StudioPalette
                             │
              StudioThemeFactory.fromPalette
                             │
            Material ThemeData + StudioDesignTokens
                             │
              Reusable Flutter editor widgets
```

Implemented foundation:
- `StudioSkinId`: namespaced value object, not a fixed enum. `builtin.carbonJade`, `builtin.copperCinema`, `builtin.asterViolet`, and future `community.<opaque-id>` values. Old saved `carbonJade` etc. remain parseable. **Do not use filesystem paths, domains or display names as IDs.**
- `StudioSkinDefinition`: immutable ID, name, optional author/description, and exact Light/Dark/Classic palettes. Every mode must exist and agree with its appearance.
- `StudioSkinCatalog`: immutable built-in + community registry, no plugin/script execution, duplicate IDs and built-in overrides rejected. Invalid or missing selected ID can be explicitly resolved to the built-in default with a user-facing notice at the future UI boundary.
- `StudioThemeFactory.fromPalette` and `fromDefinition`: identical Material/theme renderer for all sources; `resolve(StudioSkin, StudioAppearance)` remains as a convenience for current built-ins.
- `StudioSkinCodec`: pure data-only JSON v1 encoding/decoding and `StudioSkinValidator`: format, supported version, all 3 variants/12 roles, opaque colors, contrast threshold and size checks. **No picker, network fetch, database installation or theme activation is implemented yet.**
- Public [JSON Schema v1](../../schemas/subtitlestudio-skin-v1.schema.json) for website editor, documentation and external tooling.

## File format

**Proposed extension:** `.sskin.json`, MIME `application/json`, UTF-8 JSON. Any file may be previewed by a future import UI only after size and content checks.

Top-level fields:

| Field | Meaning |
| --- | --- |
| `format` | Exact discriminator `subtitlestudio.skin` |
| `schemaVersion` | Integer `1`; future incompatible versions must be rejected, not silently reinterpreted |
| `id` | Stable community namespaced ID, e.g. `community.9d14ba4b-291e-48bc-a16e-550b75895c31`; built-in IDs reserved |
| `name` | 1–80 character display name |
| `author` | Optional human-readable attribution (≤100 chars) |
| `description` | Optional plain-text description (≤500 chars) |
| `palettes` | Exactly `light`, `dark`, `classic`; each contains the same 12 semantic color roles |

Each palette has these required `#RRGGBB` (opaque) color roles:
`canvas`, `surface`, `raisedSurface`, `fieldSurface`, `onSurface`, `mutedText`, `outline`, `fieldBorder`, `accent`, `onAccent`, `appBar`, `onAppBar`.

Colors are **semantic**. No script, CSS, image, arbitrary icon, external font, remote URL, tracking pixel, layout override, or native asset is accepted in v1.

**Full example (identical design family to Carbon & Jade, but a separate community skin ID):**

```json
{
  "format": "subtitlestudio.skin",
  "schemaVersion": 1,
  "id": "community.example-jade-001",
  "name": "Jade Workshop",
  "author": "Community contributor",
  "description": "A dark-first editor palette with matching light and classic styles.",
  "palettes": {
    "light": {
      "canvas": "#FFFFFF",
      "surface": "#F7FBF9",
      "raisedSurface": "#FFFFFF",
      "fieldSurface": "#F0F8F4",
      "onSurface": "#192B25",
      "mutedText": "#526960",
      "outline": "#B8D0C6",
      "fieldBorder": "#698A7D",
      "accent": "#0A7860",
      "onAccent": "#FFFFFF",
      "appBar": "#153D35",
      "onAppBar": "#FFFFFF"
    },
    "dark": {
      "canvas": "#0E1517",
      "surface": "#182427",
      "raisedSurface": "#263639",
      "fieldSurface": "#213135",
      "onSurface": "#F2F8F5",
      "mutedText": "#B4C8C2",
      "outline": "#42575A",
      "fieldBorder": "#7A8E8B",
      "accent": "#55E0BC",
      "onAccent": "#07281E",
      "appBar": "#182427",
      "onAppBar": "#F2F8F5"
    },
    "classic": {
      "canvas": "#050909",
      "surface": "#131B1A",
      "raisedSurface": "#25332F",
      "fieldSurface": "#1B2926",
      "onSurface": "#F5F8F3",
      "mutedText": "#B6C8C1",
      "outline": "#455751",
      "fieldBorder": "#798E85",
      "accent": "#56DEB6",
      "onAccent": "#07281E",
      "appBar": "#131B1A",
      "onAppBar": "#F5F8F3"
    }
  }
}
```

## Validation and safe failure requirements

- File size ≤64 KiB UTF-8; reject unknown format/version, unknown properties, missing roles/modes, invalid syntax and transparent colors before preview.
- Contrast: normal on-surface, muted-on-field, on-accent and app bar foreground at least 4.5:1; meaningful input boundary at least 3:1. Functional warning/error text must remain readable.
- No skin may override a built-in ID or silently overwrite a previously imported community skin; future UI may offer **replace existing skin** as a separate confirmed and version-aware action.
- Imported metadata must be displayed as plain text (never interpreted as markup).
- Validation must run again on the **Android/desktop app**, even if the website validated an exported file. A website is not a trust boundary.
- Parse/preview in memory before writing to local storage; on error never mutate the current skin/mode or edit-controller state.
- Current selection remains stable if an imported skin is deleted, unavailable or corrupted: fall back to a known built-in theme, explain what happened, and preserve the original ID for potential relinking. Do not delete user data.
- A skin is **not** part of the `.msone` project document and must never inject changes to checkpoint history or media processing.
- Future local storage should use an app-owned directory and atomic writes; avoid using skin IDs directly as arbitrary filesystem paths.
- Accessibility is a release gate, not simply a warning banner.

## Future roadmap additions (separate from SKIN-1 and SKIN-2)

**SKIN-EXT-1 (foundation — code and CI verified):** stable community IDs, definition/catalog, generic factory, colors-only v1 contract/validator, machine-readable schema and regression tests (400 tests passed). No user-facing installer.

**SKIN-EXT-2 (future app importer/exporter):**
1. Native file picker for `.sskin.json` on Android/Windows/Linux/macOS/iOS; SAF/desktop file identity handled by the file-access roadmap.
2. Parse/validate; show readable preview and metadata; import only on user confirmation.
3. Install to local app-owned skin directory, integrate with injected `StudioSkinCatalog`, apply via independent persisted `skinId` and `appearance` mode (SKIN-2).
4. Rename/delete/reimport safety; prevent override of built-ins; clear warning for unsupported versions; export shareable JSON.
5. Tests for corrupted/truncated/oversized packages, bad contrast, duplicates, native platform restarts and lost-skin fallback.

**SKIN-EXT-3 (future website):**
1. Open-source client-side `SubtitleStudio Skin Creator` with 3 synchronized variants, 12 color-role pickers, live Edit Line/Home/dialog preview, WCAG guidance and accessible controls.
2. Import an existing v1 file, edit it, validate with the published schema and semantic contrast rules, and export portable `.sskin.json`.
3. The initial builder needs **no account, backend, upload, theme store or analytics**. Rendering and downloading can be client-side, respecting privacy.
4. Document credits/licensing for shared community palettes. A public gallery/store is a distinct optional future feature requiring moderation/hosting/privacy decisions.
5. Keep published schema/version migrations compatible; website and app must share fixtures and export/import round-trip tests.

**SKIN-EXT-4 (optional advanced skins):** only after community usage, consider extra semantic statuses or editable typography (bounded to safe, local choices). Executable plugins, remote stylesheets and arbitrary layout code are **explicitly out of scope** of the v1 skin format.

## Independence from other milestones

- SKIN-1 R2 established the nine built-in themes and preview gallery.
- SKIN-EXT-1 evolves the *theme data boundary* ahead of SKIN-2 so persistence can store any namespaced skin ID rather than an enum ordinal.
- SKIN-2 adds separate `skinId` and appearance persistence/Flutter controller migration; SKIN-3 adds Appearance UI; SKIN-4 repairs Edit Line neutral text inputs before switching production palettes globally.
- **Checkpoint 86 native waveform qualification remains independent**. Avoid introducing skin imports/web networking during this native media milestone.
