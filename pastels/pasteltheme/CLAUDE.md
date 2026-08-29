# pasteltheme

The **shared theme + component kit** for the Qt apps (`pastelfm`, `pastelcal`). A plain‑QML module
consumed via `import pasteltheme`. See `../CLAUDE.md` for how it fits the family.

## Files

- `qmldir` — declares `module pasteltheme` and its types.
- `Theme.qml` — **singleton**. 6 palettes + `_customBase`/Custom, `order`, `current`, `dark`,
  auto‑mode `Timer`, tokens (`radius:16`, `radiusSm:10`, `animFast/animMed`), glass tokens
  (`glassOpacity`, `glassBg`, `glow`, `strokeGlass`), helpers `alpha()`, `panelColor()`, `swatchOf()`.
  State the apps drive are **plain writable** props: `name`, `mode`, `customPrimary`,
  `customSecondary`, `panelOpacity`, `fontSize` (no Quickshell dependency).
- `GlassPanel.qml`, `Pill.qml`, `GlassSlider.qml`, `IconGlyph.qml` — depend only on `Theme`.

## How it's used

Apps add `~/dotfiles/pastels` to the QML import path (`PASTEL_QML_IMPORT_PATH` at runtime; CMake
`QT_QML_IMPORT_PATH` at build) and `import pasteltheme`. It's **loaded from disk**, so edits here take
effect on the apps' next launch **without rebuilding them**. `pastelbar` does not use this module —
mirror any palette change into `../pastelbar/Theme.qml` too.

## Conventions & gotchas

- Components reference the `Theme` singleton by **same‑directory visibility** (no `import` line for
  `Theme`). Keep new components in this dir and listed in `qmldir`.
- The slider type is **`GlassSlider`**, deliberately *not* `Slider`, to avoid shadowing
  `QtQuick.Controls.Slider` in the consuming apps. Don't reintroduce a `Slider` type name.
- `IconGlyph` is the **union** of every glyph the family needs (shell + file‑manager + calendar). Add
  new glyphs here as `case "name":` in the Canvas `switch`.
- Colour keys are fixed (`bg surface panel sidebar accent accent2 text subtext border hover selection
  danger onAccent`); renaming one breaks call sites in both apps.

## Verify

`qmllint -I /home/tobi/dotfiles/pastels *.qml` (the `-I` lets it resolve the module/qmldir). A quick
visual is `qmlscene -I /home/tobi/dotfiles/pastels <scratch.qml>` that imports `pasteltheme`.
