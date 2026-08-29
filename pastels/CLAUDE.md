# pastels

A family of **pastel + frosted‑glass** desktop apps for Hyprland/Wayland that all share one
look. Everything lives under `~/dotfiles/pastels/`.

| Project | What it is | Stack | CLAUDE.md |
|---|---|---|---|
| **pasteltheme** | The shared theme + component kit (the single source of the look for the Qt apps) | plain‑QML module | `pasteltheme/CLAUDE.md` |
| **pastelbar** | Quickshell desktop shell — floating bar pill + control center + launcher + power + polkit + settings | Quickshell (QML) | `pastelbar/CLAUDE.md` |
| **pastelfm** | File manager (SSH/Samba) | Qt 6 Quick (C++/CMake) | `pastelfm/CLAUDE.md` |
| **pastelcal** | Calendar (Google API + iCal feeds) | Qt 6 Quick (C++/CMake) | `pastelcal/CLAUDE.md` |
| **pastelimage** | Image viewer + light editor (blur / pen annotate) | Qt 6 Quick (C++/CMake) | `pastelimage/CLAUDE.md` |

## The shared theme

`pasteltheme/` is a **disk‑loaded QML module** (`import pasteltheme`). The two Qt apps add
`~/dotfiles/pastels` to their QML import path (runtime via `PASTEL_QML_IMPORT_PATH`, build‑time via
CMake `QT_QML_IMPORT_PATH`) and consume `Theme`, `GlassPanel`, `Pill`, `GlassSlider`, `IconGlyph`.
Because it's loaded from disk (not compiled in), **editing `pasteltheme/` updates both apps without
rebuilding them**.

- **pastelbar keeps its own `Theme.qml`** (Quickshell‑`Settings`‑backed, with bar‑only extras). It is
  the *value* source‑of‑truth that `pasteltheme` mirrors — it does **not** import the module.
- Design language: 6 pastel palettes (Lavender/Mint/Peach/Sky/Rosé/Sakura) + a **Custom** palette,
  **light/dark/auto** mode, glass/glow tokens (`glassBg`, `glow`, `strokeGlass`), `radius:16`.
  Dark variants are intentionally **near‑black** with a subtle palette hue.
- Same colour keys everywhere: `bg surface panel sidebar accent accent2 text subtext border hover
  selection danger onAccent`. Keep them identical across `pastelbar/Theme.qml` and
  `pasteltheme/Theme.qml` when changing palettes.

## Conventions

- All colour access goes through `Theme.current.<key>` / `Theme.alpha(c, a)`; shape/motion via
  `Theme.radius` / `radiusSm` / `animFast` / `animMed`.
- Icons are hand‑drawn Canvas line glyphs in `IconGlyph` (24×24 grid). pastelbar has its **own**
  `IconGlyph` (a subset); `pasteltheme/IconGlyph` is the **union** used by the Qt apps.
- Qt apps: transparent window + Material style recoloured by the theme; `SettingsStore` (QSettings)
  drives `Theme.name/mode/customPrimary/customSecondary/panelOpacity` from `Main.qml`.

## Paths & gotchas

- Everything is referenced by absolute path from a few places — keep them in sync if you move things:
  `hyprland.lua` (`~/.config/hypr`), the `desktop_files/*.desktop` `Exec`, the CMake/`main.cpp`
  import paths, and `pastelbar/bin/pastelbar`.
- Qt apps bake QML into the binary → **rebuild after editing their own `qml/`** (but not after
  editing `pasteltheme/`). A moved build dir has a stale CMake cache pinned to the old path — `rm -rf
  build` and reconfigure.
- Verify without a full desktop: `qmllint -I ~/dotfiles/pastels <file>`; Qt apps have a
  `PASTEL*_SCREENSHOT=/tmp/x.png` offscreen render aid; pastelbar hot‑reloads live and can be
  load‑checked with a throwaway `timeout 6 qs -p ~/dotfiles/pastels/pastelbar`.
