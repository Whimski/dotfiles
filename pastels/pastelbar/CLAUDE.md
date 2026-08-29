# pastelbar

A pastel + frosted‑glass **Quickshell** desktop shell for **Hyprland/Wayland**: a floating **bar
pill** (top‑center) plus overlays — control center, OSD, app launcher, power menu, polkit dialog,
notifications, settings, and the desktop wallpaper. See `../CLAUDE.md` for the family.

Not a compiled app — Quickshell runs the QML directly.

## Run / reload / verify

```sh
qs -p /home/tobi/dotfiles/pastels/pastelbar
```

- Autostarts from `~/.config/hypr/hyprland.lua` via `bin/keep_alive_bar.sh`; keybinds/IPC go through
  `bin/pastelbar` (`pastelbar <target> <fn>` → `qs … ipc call`).
- **Hot‑reloads** on file save (the live instance sends errors to `/dev/null`, so also do a throwaway
  `timeout 6 qs -p …/pastelbar 2>&1 | grep -i error` to load‑check, and `qmllint` files).
- Grab the live pill with `grim` for visual checks. QML errors that fail a reload leave the shell on
  its last‑good scene (looks like "nothing changed").

## Backends (native noctalia modules, wrapped in `services/`)

`Net`, `BT`, `Audio` (Pipewire), `Media` (Mpris), `Notifs`, `Polkit` are native
`Quickshell.*`/`Services.*`. `Brightness` (`brightnessctl`/`ddcutil`), `NightLight` (`wlsunset`),
`Power` (`systemctl`/`loginctl`) shell out via `Process`. Each service is a singleton exposing a small
UI‑facing surface so components stay backend‑agnostic.

## Structure

- `shell.qml` — per‑screen `Bar` + `Wallpaper`; single `ControlCenter`/`TunePanel`/`WeatherPanel`/
  `Launcher`/`PowerMenu`/`PolkitDialog`; the `IpcHandler` surface. IPC targets include `bar`
  (`expand`/`collapse`/`toggle` — keybind hold‑to‑expand the pill) and `menu` (`open`/`toggle <name>`
  — generic dispatch to `Ui.openPanel`/`togglePanel`, one entry point for every named panel).
- `Theme.qml` (singleton) — **pastelbar's own** theme (6 palettes + Custom, light/dark/auto, glass/glow,
  live bar metrics). Reads `Settings`. This is the value source‑of‑truth the `pasteltheme` module
  mirrors; pastelbar does **not** import that module.
- `Settings.qml` (singleton) — JSON via `FileView`+`JsonAdapter` at `Quickshell.statePath()`
  (theme/mode/custom accents/pill paddings/fontSize/opacity/wallpapers/`mediaBlacklist`/`weatherLoc`).
- `Ui.qml` — transient overlay open‑flags + `openPanel`/`togglePanel(name)` dispatch. `components/`,
  `bar/Bar.qml`, `panels/`, `overlays/`.
- `panels/TunePanel.qml` — the settings window: left‑sidebar nav (Network/Bluetooth/Audio/Display/
  Wallpaper&Style/Widgets/About) over a searchable content pane.
- `services/ActiveWindow.qml` — per‑monitor active window (class + title) from `Quickshell.Hyprland`.
  Gotchas learned the hard way: `Hyprland.refresh*()` is **async** (models populate next turn and emit
  `valuesChanged`) so recompute reactively on those signals, not synchronously after calling refresh;
  and `Hyprland` collections don't auto‑populate until you call refresh at least once. Used by `Bar`
  for the **`Settings.pillYieldApps`** list (case‑insensitive substrings vs class/title): when a listed
  app is the active window on a screen, that bar hides its **idle** pill so it doesn't cover the app.
- The **idle "main pill" is removed** — at rest the bar shows nothing (pill hidden + input mask
  dropped, so it's click-through). The pill appears only when **expanded** (hold **Left Alt** →
  `bar expand`, bound in `hyprland.lua`) or as a transient **OSD** (volume/brightness). Hover-to-expand
  is effectively off since there's no idle surface to enter. `Bar.pillHidden` is now just
  `mode === "idle"`.
- Bar **layer** behaviour: idle = `Top` (normal), expanded/OSD = `Overlay` so a temporary expand
  overrides everything — including true‑fullscreen windows, which Hyprland renders *above* the `Top`
  layer (so a Top pill is invisible over a fullscreen game; Overlay is above it). Runtime `Top↔Overlay`
  re‑commit reliably, but **`Bottom→Top` does not** (a layer surface can't be raised out of Bottom) —
  so we never lower to Bottom; we hide the idle pill (opacity + drop its input mask) instead.
- `panels/WeatherPanel.qml` + `services/Weather.qml` — weather flyout via **Open‑Meteo** (free, no
  API key). Location auto‑detected once from IP (ipwho.is) into `Settings.weatherLoc`, or set by city
  via Open‑Meteo geocoding. Refetches every 15 min and on open when stale. WMO codes map to the new
  weather `IconGlyph`s (sun/moon/cloud/cloudSun/rain/snow/storm/fog).

## Conventions & gotchas

- pastelbar has its **own** `IconGlyph` (a subset of the family's icons) — add glyphs here as needed;
  it's not the same file as `pasteltheme/IconGlyph`.
- **Media blacklist**: `services/Media.qml` ignores MPRIS players matching `Settings.mediaBlacklist`
  (case‑insensitive substring vs identity/dbusName/desktopEntry; default `["firefox"]`). Edit it in
  Settings → Widgets → *Ignored media players*, or in `settings.json`.
- Environment rules: only **one** notification daemon and **one** polkit agent per session (don't also
  run mako/dunst or hyprpolkitagent). **pastelbar renders the wallpaper** (no swww/hyprpaper).
- The settings window opens on the focused monitor. Reloading resets transient `Ui` flags (open panels
  close). `Slider`‑like inline containers need an explicit width binding (anchors‑fill on a
  property‑parented item doesn't establish width) — see `TunePanel` `GroupCard`.
- **`Settings` write/reload race**: `FileView` has `watchChanges:true`→`reload()`, so writing several
  scalar `JsonAdapter` properties in quick succession lets the reload from an earlier write clobber a
  later value (seen: `weatherLon` persisting as `0`). Persist related fields as **one object/array**
  written in a single assignment (see `weatherLoc`, `wallpapers`, `mediaBlacklist`), not N sequential
  scalar writes.
- Editing the **`Settings` singleton** may not fully hot‑reload live — restart the shell (kill the
  `qs -p …/pastelbar` pid; `keep_alive_bar.sh` respawns it) to pick up `Settings.qml` schema changes.
