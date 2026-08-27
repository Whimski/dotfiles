# pastelbar

A pastel + futuristic **Quickshell** desktop shell for **Hyprland / Wayland** — a floating
glass **bar pill** plus a full set of overlays: a **control center**, an **OSD**, an **app
launcher**, a **power menu**, a **polkit auth dialog**, **notifications**, and a **settings**
panel. Styled to match the sibling project `~/qml/pastelfm` (soft pastel palettes, light/dark),
with a futuristic layer on top: frosted-glass panels, glow-accent borders, animated signal /
audio rings.

This file is the implementation plan / spec. The QML is written in later passes (see **Phased
build**).

---

## What this is

- A **real shell**: a Quickshell config (QML Wayland layer-shell) for **Hyprland**, not a
  standalone Qt app.
- **Aesthetic**: pastelfm's 6 pastel palettes (light/dark) + a futuristic glass/glow layer.
- **Surfaces**:
  1. **Bar** — a floating rounded glass pill, top-center (not a full-width strip), with three
     states:
     - **Idle** — compact: an MPRIS-reactive **audio-wave glyph** + the **clock**.
     - **Hover** — expands (animated width/opacity) to reveal **now-playing** on the left
       (album art + wave + track title + artist), **clock + date** in the center, and **WiFi +
       Bluetooth pills** on the right (BT shows a battery badge); collapses on mouse-leave.
     - **OSD** — the *same pill* morphs into an on-screen display (icon + progress bar + %) on
       volume / brightness / night-light changes, then auto-reverts to the clock.
  2. **Control Center** — opens from the WiFi/BT pill: quick-toggle tiles (Wi-Fi, Audio,
     Bluetooth, **Peace**/DND, **Night Light**), volume + brightness sliders, a full MPRIS media
     card (transport + seek), and a **notifications** list (per-app dismiss + Clear all).
  3. **App launcher / search** — keybind-triggered glass panel: search field + desktop-entry
     results (icon + name + description), keyboard-selectable, launches the app.
  4. **Power menu** — Lock / Suspend / Log Out / Reboot / Power Off / **BIOS**.
  5. **Polkit agent** — a native "Authentication Required" dialog for elevated actions.
  6. **Settings** — live **Bar height** + **Font size** sliders, a **Theme** picker, and a
     **Wallpaper** chooser.
  7. **Wallpaper** — pastelbar renders the desktop wallpaper itself (bottom layer-shell window).

Run it with:

```sh
qs -p /home/tobi/dotfiles/pastelbar
# or symlink into the default location:
ln -s /home/tobi/dotfiles/pastelbar ~/.config/quickshell/pastelbar && qs -c pastelbar
```

---

## Backends (native noctalia modules, not CLI parsing)

This box runs **noctalia-qs 0.0.12**, a Quickshell distribution that ships **native** modules
the stock v0.1.0 build lacked. So — unlike the original plan — we bind directly to them instead
of shelling out to `nmcli` / `bluetoothctl`:

| Concern            | Backend                                   |
|--------------------|-------------------------------------------|
| WiFi / networking  | `Quickshell.Networking` (native)          |
| Bluetooth          | `Quickshell.Bluetooth` (native)           |
| Audio (vol/device) | `Quickshell.Services.Pipewire` (native)   |
| Media / now-playing| `Quickshell.Services.Mpris` (native)      |
| Notifications      | `Quickshell.Services.Notifications` (native server) |
| Polkit agent       | `Quickshell.Services.Polkit` (native)     |
| Lock/PAM auth      | `Quickshell.Services.Pam` (native)        |
| Battery            | `Quickshell.Services.UPower` (native)     |
| App launcher index | `Quickshell.DesktopEntries` (native — no custom `Apps` service) |
| Compositor IPC     | `Quickshell.Hyprland` (native)            |

Only a few things have **no** native module and are driven via `Process`, following pastelfm's
`MountManager` "spawn a CLI tool, parse output, expose state, degrade gracefully" pattern:

- **Brightness** → `brightnessctl` (internal) / `ddcutil` (external monitors)
- **Night Light** → `wlsunset` (managed process, on/off + temperature)
- **Power actions** → `systemctl` / `loginctl` (incl. BIOS: `systemctl reboot --firmware-setup`)

The service singletons wrap each backend behind a small, uniform surface (a `ListModel` and/or a
few properties + actions + an `available` flag) so the **UI layer stays backend-agnostic** — a
backend can be swapped without touching the components.

**Environment caveats (document + guard against):**

- Only one **notification daemon** may own `org.freedesktop.Notifications` — Hyprland must not
  also autostart mako/dunst.
- Only one **polkit agent** may run per session — do not also autostart
  hyprpolkitagent / polkit-gnome.
- No wallpaper tool (swww/hyprpaper) is installed by design: **pastelbar renders the wallpaper**.

---

## Structure

```
pastelbar/
  CLAUDE.md            # this plan
  shell.qml            # ShellRoot: per-screen Bar + Wallpaper; single ControlCenter, TunePanel,
                       #   Launcher, PowerMenu, PolkitDialog; IpcHandler surface (see Keybinds)
  qmldir               # exposes root singletons (Theme, Settings, Ui) + Wallpaper as a module
  Theme.qml            # singleton: 6 pastel palettes, light/dark + auto, futuristic tokens,
                       #   live barHeight/fontSize derived from Settings
  Settings.qml         # singleton: JSON-persisted — theme, mode(light/dark/auto), per-state pill
                       #   padding, fontSize, global + per-screen wallpaper paths
  Ui.qml               # singleton: transient (non-persisted) open flags for the overlays
                       #   (ccOpen/ccFocus, tuneOpen, launcherOpen, powerOpen)
  Wallpaper.qml        # bottom WlrLayershell window rendering the chosen (per-screen) image
  services/
    qmldir             # exposes the service singletons as a module
    Net.qml            # wraps Quickshell.Networking  (wifi list, enabled, active, connect)
    BT.qml             # wraps Quickshell.Bluetooth   (devices, powered, connect/pair, battery)
    Audio.qml          # wraps Services.Pipewire       (default sink/source, volume, mute, device)
    Media.qml          # wraps Services.Mpris          (active player, metadata, position, transport)
    Notifs.qml         # wraps Services.Notifications  (server + history model + DND/"Peace")
    Polkit.qml         # wraps Services.Polkit         (registers the agent; exposes flow/active)
    Brightness.qml     # brightnessctl / ddcutil via Process
    NightLight.qml     # wlsunset process manager (on/off, temperature)
    Power.qml          # systemctl/loginctl actions incl. `systemctl reboot --firmware-setup`
  components/
    GlassPanel.qml     # frosted panel background + glow border (the futuristic base)
    Pill.qml           # glassy rounded indicator / button
    IconGlyph.qml      # Canvas line-icons (extends pastelfm's Icon.qml set)
    SignalBars.qml     # animated wifi strength bars / signal ring
    AudioWave.qml      # MPRIS-reactive wave glyph (animates while a player is Playing)
    Slider.qml         # glassy slider (volume / brightness / settings)
    ToggleTile.qml     # control-center quick tile
    MediaCard.qml      # now-playing (mini in bar, full in control center)
  bar/
    Bar.qml            # floating top-center pill: idle <-> hover-expand <-> OSD states
  panels/
    ControlCenter.qml  # flyout: header + toggle tiles + sliders + MediaCard + notifications
    WifiSection.qml    # toggle + rescan + network ListView + inline connect
    BluetoothSection.qml  # toggle + scan + device ListView + connect / pair + battery
    AudioSection.qml   # output/input device picker + per-device volume
    NotificationList.qml  # history ListView, per-item dismiss, Clear all
    TunePanel.qml      # settings flyout: per-state pill padding + font sliders, palette + mode
                       #   picker, per-screen wallpaper chooser (was SettingsPanel in the plan)
  overlays/
    Launcher.qml       # search field + desktop-entry ListView + launch (native DesktopEntries)
    PowerMenu.qml      # Lock / Suspend / Log Out / Reboot / Power Off / BIOS tiles
    PolkitDialog.qml   # binds services/Polkit agent (action + password + Cancel/Authenticate)
  bin/
    pastelbar          # CLI wrapper: forwards `pastelbar <target> <fn> [args]` to `qs … ipc call`
```

No C++/CMake — Quickshell runs QML directly.

---

## Reference material (in `~/qml/pastelfm`)

- `qml/Theme.qml` — the singleton palette system to adapt (`palettes`, `order`, `current`,
  `alpha()`, `panelColor()`, `radius` / `animFast` / `animMed`). 6 palettes: `Lavender, Mint,
  Peach, Sky, Rosé, Sakura`, each with a light + dark variant.
- `qml/components/Icon.qml` — the Canvas line-icon pattern to extend (add `wifi`, `wifiOff`,
  `bluetooth`, `bluetoothOff`, `lock`, `check`, `scan`, `play`, `pause`, `next`, `prev`,
  `volume`, `brightness`, `moon`, `power`, `search`, …).
- `qml/components/PastelButton.qml` — soft-button styling (hover/down color `Behavior`) to echo.
- `src/MountManager.cpp` — the "spawn a CLI tool, parse output, expose state, degrade gracefully"
  backend pattern the `Process`-based services (Brightness / NightLight / Power) reproduce in QML.

---

## Component design

### `Theme.qml` (singleton)

Port pastelfm's palette map + `order` / `current` / `alpha()` / `panelColor()` and the `radius` /
`animFast` / `animMed` tokens. Add:

- **Mode** — `mode: "light" | "dark" | "auto"`. `auto` resolves to light/dark via a day/night
  schedule (or `gsettings get org.gnome.desktop.interface color-scheme` when present) — document
  the fallback. `current` picks the resolved variant.
- **Futuristic tokens** — `glassBg` (panel color at ~0.6–0.8 alpha), `glow` / `glowWidth`
  (accent glow), `strokeGlass` (hairline border).
- **Live metrics** — `fontSize` and the per-state pill paddings come from `Settings`; `barHeight`
  is **derived** (`max(20, fontSize + 6) + idleVPad*2`) so the Settings sliders resize the bar and
  text live. `panelWidth` is a fixed token.

Default palette **Mint**, default mode **dark**. Palette + mode + metrics persist via `Settings.qml`.

### `Settings.qml` (singleton)

A JSON state file — `FileView` + `JsonAdapter` at `Quickshell.statePath("settings.json")`
(materialised with defaults on first run) — holding: `theme` (palette name), `mode`
(light/dark/auto), per-state pill padding (`idleVPad`/`idlePad`/`expVPad`/`expPad`), `fontSize`,
a global `wallpaper` path, and a per-screen `wallpapers` map (`{ "DP-1": "file://…" }`) with
`wallpaperFor(name)` / `setWallpaperFor(name, path)` helpers. Read by `Theme` and `TunePanel`;
written by the sliders/pickers. (Transient overlay open-flags live in `Ui.qml`, not here.)

### Service singletons (`services/`)

Each exposes a uniform, UI-facing surface so components bind without knowing the backend:

- **`Net.qml`** (Quickshell.Networking) — `wifiEnabled`, `activeSsid`, a `networks` model
  (ssid/signal/security/active), actions `rescan()`, `setEnabled(b)`, `connect(ssid, pw)`,
  `disconnect()`; `available`.
- **`BT.qml`** (Quickshell.Bluetooth) — `powered`, a `devices` model
  (name/mac/connected/paired/icon/batteryPct), actions `setPowered(b)`, `startScan()`/`stopScan()`,
  `connect/disconnect/pair(mac)`; `available`.
- **`Audio.qml`** (Services.Pipewire) — default sink/source, `volume`, `muted`, device list;
  `setVolume()`, `toggleMute()`, `setDefaultSink()`. Emits change events that drive the OSD.
- **`Media.qml`** (Services.Mpris) — active player, `playbackState`, metadata (title/artist/art),
  `position`/`length`, `playPause()`, `next()`, `prev()`, `seek()`. `playbackState === Playing`
  drives `AudioWave`.
- **`Notifs.qml`** (Services.Notifications) — registers the server; `history` model, `dnd`
  ("Peace") flag suppressing popups, `dismiss(id)`, `clearAll()`.
- **`Brightness.qml`** (`brightnessctl`/`ddcutil` via Process) — `value`, `setValue()`; drives OSD.
- **`NightLight.qml`** (`wlsunset` process) — `enabled`, `temperature`, `toggle()`.
- **`Power.qml`** (`systemctl`/`loginctl`) — `lock()`, `suspend()`, `logout()`, `reboot()`,
  `poweroff()`, `bios()` (`systemctl reboot --firmware-setup`).
- **`Polkit.qml`** (Services.Polkit) — registers pastelbar as the session polkit agent; exposes
  `flow` + `active` (bound by `overlays/PolkitDialog`), `submit(response)` / `cancel()`.

The launcher does **not** use a custom `Apps` service — it filters `DesktopEntries.applications`
(native) directly in `overlays/Launcher.qml`. Transient overlay open/close state lives in the
`Ui` singleton (`Ui.qml`): `ccOpen`/`ccFocus`, `tuneOpen`, `launcherOpen`, `powerOpen`, with
`openCC(focus)` / `toggleCC()` helpers.

### `bar/Bar.qml` (PanelWindow — the floating pill)

- `PanelWindow` (WlrLayershell, top), window color **transparent**, **not full-width**: a
  centered `GlassPanel` **pill** with rounded corners; `exclusiveZone` reserves `Theme.barHeight`.
- **State machine** (priority **OSD > hover-expanded > idle**):
  - **idle** → `AudioWave` + clock.
  - **hover** → adds `MediaCard` (mini: art + title + artist), date under the clock, WiFi pill
    (`SignalBars` + SSID) and BT pill (`IconGlyph` + connected-count + battery badge).
  - **OSD** → morphs into icon + `Slider`-style bar + % for volume/brightness/night-light; a
    `Timer` auto-reverts. OSD wins even while hovered.
- Width/opacity `Behavior` animations; hover glow like pastelfm. Clicking the WiFi/BT pill opens
  the `ControlCenter` (focused to that section).

### `panels/ControlCenter.qml` (flyout)

- `PopupWindow` (or a second `PanelWindow`) under the bar's right edge; `GlassPanel` + glow
  border; open/close via scale + opacity `Behavior`.
- Layout: header (title + close) → **quick-toggle tiles** grid (`ToggleTile` for Wi-Fi, Audio,
  Bluetooth, Peace/DND, Night Light) → **volume** + **brightness** `Slider`s → full `MediaCard`
  (art bg, device label, title/artist, transport, seek) → `NotificationList`. A gear opens the
  `TunePanel` settings flyout. (The planned standalone `Toast` overlay was not built.)
- Sections (`WifiSection` / `BluetoothSection` / `AudioSection`) provide the expanded device
  lists with inline connect / password / device picking. Styled empty / unavailable states.

### `overlays/` (keybind-driven surfaces)

- **`Launcher.qml`** — `PanelWindow` overlay: search field filtering `DesktopEntries.applications`
  directly; `ListView` rows (icon + name + description) with keyboard selection; Enter launches,
  Esc closes.
- **`PowerMenu.qml`** — row of `Pill`/tile buttons: Lock, Suspend, Log Out, Reboot, Power Off,
  **BIOS**, wired to `Power`.
- **`PolkitDialog.qml`** — binds `services/Polkit`: shows the action message + command + the
  policykit action id, a password field, Cancel / Authenticate.

### Keybind integration

`shell.qml` exposes an `IpcHandler` per target — toggles (`cc`, `launcher`, `power`, `settings`)
plus action targets (`volume`, `brightness`, `media`, `nightlight`, `session`). Drive them with
`qs -p /home/tobi/dotfiles/pastelbar ipc call <target> <fn> [args]`, or the `bin/pastelbar`
wrapper (`pastelbar <target> <fn>`; no args → `ipc show` lists targets). Wire in `hyprland.conf`:

```
bind = SUPER, Space,  exec, pastelbar launcher toggle
bind = SUPER, Escape, exec, pastelbar power toggle
bind = SUPER, C,      exec, pastelbar cc toggle
bind = , XF86AudioRaiseVolume, exec, pastelbar volume increase
bind = , XF86AudioLowerVolume, exec, pastelbar volume decrease
bind = , XF86AudioMute,        exec, pastelbar volume mute
bind = , XF86MonBrightnessUp,   exec, pastelbar brightness increase
bind = , XF86MonBrightnessDown, exec, pastelbar brightness decrease
```

### Shared visual language (the "futuristic" layer)

Frosted glass over the desktop (layer-shell transparency + compositor blur), 1px glow-accent
borders, soft outer glow on active elements, an animated concentric "signal ring" while scanning,
the MPRIS-reactive `AudioWave`, a subtle hairline grid behind panels, pastel accent per palette.
Reuse pastelfm's `radius`, `animFast` / `animMed`, and `Behavior on color` conventions.

---

## Phased build

All three phases are now built; each phase is independently runnable.

- **Phase 1 — Foundations + Bar + OSD:** `Theme`, `Settings`, `GlassPanel` / `Pill` /
  `IconGlyph` / `SignalBars` / `AudioWave`; `Net` / `BT` / `Audio` / `Media` / `Brightness`
  services; `Bar.qml` with idle ↔ hover-expand ↔ OSD.
- **Phase 2 — Control Center + Notifications:** `ControlCenter` (tiles + sliders + full
  `MediaCard` + `NotificationList`); `Notifs` + `NightLight` services; Wifi / Bluetooth / Audio
  sections.
- **Phase 3 — Launcher + Power + Polkit + Settings/Wallpaper:** `Launcher`, `PowerMenu` (+BIOS),
  `PolkitDialog` (`Services.Polkit`), `SettingsPanel` (live sliders, theme picker, wallpaper
  chooser), `Wallpaper.qml`; the `IpcHandler` keybind wiring.

---

## Verification

- **On this sandbox (limited):** no Wayland session to render into. Do what's possible:
  `qmllint` each QML file, and dry-check the `Process` command strings (`brightnessctl`,
  `wlsunset`, `systemctl reboot --firmware-setup`). Native modules and degrade paths let much of
  the UI logic be reasoned about without hardware.
- **On the real Hyprland box (authoritative):** `qs -p /home/tobi/dotfiles/pastelbar`. Confirm the
  floating pill docks top-center and reserves space; hover expands to now-playing + WiFi/BT;
  changing volume/brightness morphs the pill into the OSD and reverts; clicking a pill opens the
  Control Center (toggles, sliders, media, notifications); keybinds open the launcher + power
  menu; trigger a `pkexec` action to see the polkit dialog; Settings sliders live-resize the
  bar/font; the wallpaper chooser repaints the background layer; toggle palettes + light/dark/auto;
  check glass/glow render with the compositor's blur.

---

## Out of scope (future work)

Per-monitor bar variants beyond the shared config, a full workspace/window switcher, mic
controls, and lock-screen (`Services.Pam`) are deferred. The architecture (service singletons +
sections + overlays + `GlassPanel`) leaves room to add each as a sibling surface later.
