# Cyberpunk reference sheets

The reference sheets pastel-bar's cyberpunk mode is based on, pulled on 2026‑10‑04 from the
preview images of Olga Ryzhychenko's "CyberPunk UI Set" on ArtStation
(<https://www.artstation.com/marketplace/p/Gyjb/cyberpunk-ui-set>). She also made the steampunk kit
in `../steampunk-refs/`. Use these for reference only. Don't ship them as assets.

The kit's language: near‑black violet ground (`#0b0018`‑ish), **neon cyan** (`#00ffd5`) and
**hot magenta‑red** (`#ff0050`) with an occasional orange alert. Thin 1px outlines, **chamfered
45° corners** everywhere (no rounding), solid corner wedges, hatched stripe blocks, dash/tick
rulers, data‑noise bars, and a slight RGB‑split (chromatic aberration) on text.

| File | Contents → used for |
|---|---|
| `windows-shapes.jpg` | 6 chamfered window frames: corner wedges, thick top bars, stripe tabs; blocky shapes → `CyberFrame`, `GlassPanel` cuts |
| `data-buttons-dividers.jpg` | data‑noise strips, 12 "ACTION" buttons, 10 dividers → `CyberDivider`, `ToggleTile`'s chamfered tile + `‖` marker |
| `circles-rulers-letters.jpg` | 12 segmented HUD rings/reticles, 10 rulers (tick, bead, dash), the angular display alphabet |
| `squares-triangles-grids.jpg` | X‑squares, corner brackets, stripe squares, chamfered square frames, triangles, 8 grids |
| `hud-mockup.jpg` | the kit assembled into a HUD: tabbed headers with notch, big glitch numerals, status triangles, node sliders |
| `title-rail.jpg` | node rail (box · dot · long box · dot) and dash rows → `CyberFrame` rails, `CyberDivider` `node` |
| `cover-dark.jpg` / `cover-light.jpg` | overview covers (dark and light variants, light one shows the RGB‑split text) |

Colours: pastel-bar uses the palette accent only, not the kit's cyan/magenta (by request).
