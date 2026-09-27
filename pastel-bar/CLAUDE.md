# pastelbar

A pastel + frosted‑glass **Quickshell** desktop shell for **Hyprland/Wayland**: a floating **bar
pill** (top‑center) plus overlays — control center, OSD, app launcher, power menu, polkit dialog,
notifications, settings, and the desktop wallpaper. See `../CLAUDE.md` for the family.

Not a compiled app — Quickshell runs the QML directly.

## Run / reload / verify

```sh
qs -p /home/tobi/dotfiles/pastel-bar
```

- Autostarts from `~/.config/hypr/hyprland.lua` via `~/dotfiles/bin/keep_alive_bar.sh`; keybinds/IPC go
  through **`pastel-bar/bin/pastel-bar`** (`pastel-bar <target> <fn>` → `qs … ipc call`). Note the
  directory is `pastel-bar`, not `pastelbar` — and `~/dotfiles/bin/pastelbar` is a **dangling symlink**
  (→ `pastelbar/bin/pastelbar`), so use the real path.
- **Hot‑reloads** on file save. The live instance sends errors to `/dev/null`, so to see them read its
  **own log**: `qs log $(ls -t /run/user/1000/quickshell/by-id/*/log.qslog | head -1)`. A throwaway
  `timeout 6 qs -p …/pastel-bar` load‑check **silently does nothing while the shell is running** — it
  just prints "An instance of this configuration is already running", so a passing grep proves
  nothing. `qmllint` is still worth running, but it does **not** catch unqualified references to a
  property declared on a non‑root object (see the `discHovered` note under Conventions).
- Grab the live pill with `grim` for visual checks. QML errors that fail a reload leave the shell on
  its last‑good scene (looks like "nothing changed").

## Backends (native noctalia modules, wrapped in `services/`)

`Net`, `BT`, `Audio` (Pipewire), `Media` (Mpris), `Notifs`, `Polkit`, `Battery` (UPower) are native
`Quickshell.*`/`Services.*`. `Brightness` (`brightnessctl`/`ddcutil`), `NightLight` (`wlsunset`),
`Power` (`systemctl`/`loginctl`) shell out via `Process`. `BT` is mostly native but shells out to
`pactl` for audio card profiles, which the Pipewire module does not expose. Each service is a singleton exposing a small
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
  (theme/mode/custom accents/pill paddings/fontSize/opacity/wallpapers/`mediaBlacklist`/`weatherLoc`/
  `weatherUnit`/`pillYieldApps`/`launcherSearchFirst`). Import/export dumps the whole adapter to JSON.
- `Ui.qml` — transient overlay open‑flags + `openPanel`/`togglePanel(name)` dispatch. `components/`,
  `bar/Bar.qml`, `panels/`, `overlays/`.
- `panels/TunePanel.qml` — the settings window: left‑sidebar nav (Network/Bluetooth/Audio/Display/
  Wallpaper&Style/Widgets/About) over a searchable content pane. Display has *"Don't cover these
  apps"* (`pillYieldApps`); Widgets has *"Search before showing apps"* (`launcherSearchFirst`); About
  has **Backup** (Export/Import all settings via `Settings.exportSettings`/`importSettings`, written
  as one object so it round‑trips atomically). The Network and Bluetooth pages are both a
  `RadialConnect` (below).
- `panels/RadialConnect.qml` + `panels/RadialPlanet.qml` — the Network/Bluetooth view. `RadialConnect`
  is a shell that grids one or more **planets** and owns the shared `spin` animation, the search
  `filter`, and `hintEntries(prefix)` (which walks every planet's chips/moons/disc for `TunePanel`'s
  hint mode). `RadialPlanet` is one planet: a glowing centre disc with info/action chips orbiting it on
  wavy accent "tendril" connectors, plus scan‑result "moons" on elliptical rings. Driven live off
  `Net`/`BT`.
  - Wi‑Fi/Ethernet get one planet; **Bluetooth gets one planet per controller** (`BT.adapters`), each
    scoped to its own adapter's devices (filtered by the `BluetoothDevice.adapter` back‑pointer) and
    captioned with its `adapterId` when more than one is present.
  - **The planet is the power button** — clicking its disc toggles that radio (`adapter.enabled` via
    `BT.setAdapterPowered`); hovering fades the disc contents for a power glyph.
  - The **bottom bar** (segmented mode toggle + round power button) exists **only for Wi‑Fi/Ethernet**.
    Bluetooth collapses it to zero height — its planets are their own power buttons and the sidebar is
    the page switcher — so the orbit gets the full cell.
  - Scanning is per‑controller: the single results view drives every adapter via `BT.scanAll`.
  - **`Net` is single‑device by design** — `wifiDevice` returns the first device exposing a `networks`
    model, and `refreshEthernet`'s nmcli pipeline `exit`s on the first ethernet NIC. So Network is
    always exactly one planet, and a second Wi‑Fi or ethernet card is invisible (including to
    `connectEthernet`, which targets `ethernetIface`). Multi‑planet is Bluetooth‑only until `Net` grows
    a real device list.
- `components/HintOverlay.qml` — Vimium‑style keyboard "hint mode" shared by `ControlCenter` and
  `TunePanel`: **F** calls `start(list)` with a `{key, item, activate}` list from the panel's
  `_kbList()`, and it drops a lettered badge (prefix‑free labels, generated with Vimium's own
  BFS‑over‑`chars`‑then‑keep‑leaves algorithm) on every hintable entry; typing a label's letters
  fires `activate()` immediately — no Enter needed. Escape/Backspace edit the typed prefix. Entries
  need both an `item` (for position) and an `activate` — sliders with only incr/decr aren't hinted,
  same as Vimium skips scrollbars. `reposition()` re‑maps badge positions without resetting the typed
  prefix, for targets that move (e.g. the orbiting chips/moons of `RadialConnect`'s planets).
- `overlays/Launcher.qml` — app launcher; when `Settings.launcherSearchFirst` is on it shows nothing
  until a query is typed. **Tab** enters a *run-command* mode: the typed text runs as a detached
  background shell command (`Quickshell.execDetached(["sh","-c", cmd + " </dev/null >/dev/null 2>&1"])`),
  so no output leaks. In command mode **Tab** does zsh-like completion — command names for the first
  token (`compgen -c` via a `Process`), filesystem paths for later tokens (a `FolderListModel` kept
  pointed at the token's directory, read synchronously); it fills the longest common prefix and, when
  ambiguous, opens a chip menu that repeated **Tab** cycles (or click a chip). **Shift+Tab** returns
  to app search. `_setInput`/`_applying` guard against the programmatic edit clearing the menu.
- `services/ActiveWindow.qml` — per‑monitor active window (class + title) from `Quickshell.Hyprland`.
  Gotchas learned the hard way: `Hyprland.refresh*()` is **async** (models populate next turn and emit
  `valuesChanged`) so recompute reactively on those signals, not synchronously after calling refresh;
  and `Hyprland` collections don't auto‑populate until you call refresh at least once. Used by `Bar`
  for the **`Settings.pillYieldApps`** list (case‑insensitive substrings vs `cls + " " + title`): when a
  listed app is the active window on a screen, that bar suppresses its **expanded** pill (and the
  notification list that hangs off it) so nothing can be raised over the app — not even a
  hold‑to‑expand, which otherwise overrides fullscreen. The **OSD stays**: it only appears in direct
  response to a volume/brightness keypress, so it isn't covering anything unasked, and the idle
  notification toast keeps its own separate `!yieldToApp` gate.
  - `matches()` is a plain function, so a binding calling it only re‑evaluates when a *property* it
    reads changes. `byMonitor` is reassigned wholesale for exactly that reason, and `Bar`'s
    `!!ActiveWindow.byMonitor &&` prefix exists **only** to establish that dependency — don't
    "simplify" it away.
- `services/Battery.qml` — thin wrapper over `Quickshell.Services.UPower`'s `displayDevice`
  (`present`/`percent`/`charging`). The expanded pill's top row shows a single battery pill (icon +
  `%`, accent‑tinted while charging) instead of the old separate wifi/bt pills; `present` gates it off
  entirely on desktops with no laptop battery. Clicking it opens the control center.
- The **idle "main pill" is removed** — at rest the bar shows nothing (pill hidden + input mask
  dropped, so it's click-through). The pill appears only when **expanded** (hold **Left Alt** →
  `bar expand`, bound in `hyprland.lua`) or as a transient **OSD** (volume/brightness). Hover-to-expand
  is effectively off since there's no idle surface to enter. `Bar.pillHidden` is
  `mode === "idle" || (mode === "expanded" && yieldToApp)`.
- **Hold‑to‑expand collapse is finicky** — Hyprland's modifier‑release bind is unreliable after an
  `Alt+<key>` combo. Mitigations, all needed: the Hyprland binds are **`non_consuming`** (so Alt still
  reaches games/apps) and the collapse is bound **both** `ALT_L` and `ALT + ALT_L` on release; menu
  opens clear `Ui.barExpanded` (see `Ui.qml` `on*OpenChanged`); and a **6 s safety `Timer` in
  `Ui.qml`** force‑collapses so it can never stay stuck. (Tying collapse to Hyprland focus events was
  tried and failed — the `qs ipc` client that delivers `bar expand` itself fires window events that
  collapse it instantly.)
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
- **Audio profile sub‑planet.** The `Hi-Fi · <codec>` chip on a connected BT planet is an action chip:
  clicking it sets `RadialPlanet.codecSplit` and the planet *becomes* the profile picker — the centre
  disc shrinks (`centerR` 58→38) and relabels to **Hi-Fi**/**Headset** with the active codec under it,
  the device's own chips are dropped from `chipsRepeater`'s model, and `BT.codecProfiles` orbit the
  smaller planet as evenly spaced moons on the normal tendrils (`optAngle` mirrors `baseAngle`, so they
  revolve with the same `spin`). Clicking the disc closes it; clicking a moon applies that profile.
  Profiles are parsed from `pactl --format=json list cards`, keyed on the connected device's
  `bluez_card.<addr>`, and applied via `BT.setCodecProfile` → `pactl set-card-profile`. **Switching
  profile is what changes the codec** — A2DP variants are Hi-Fi, HSP/HFP are Headset (mono, mic on).
  Quickshell's Pipewire module is node‑centric and exposes no card profiles, hence the `pactl`
  shell‑out; it replaced a `pw-dump | grep -m1` that took the first codec in the dump regardless of
  which device owned it.
- **Connecting competes with scanning.** `BT.connect`/`BT.pair` stop discovery on that device's
  adapter and set `BT.connecting`; `startScanOn` refuses to scan while it's set (and skips redundant
  `StartDiscovery` on an already‑discovering adapter, which appeared to wedge a BCM20702A1 dongle into
  `Discovering: yes` while finding nothing). `BT.pair` also forces `adapter.pairable = true` — BlueZ
  persists `Pairable` per adapter and a stored `false` makes every pair attempt fail silently.
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
  `qs -p …/pastel-bar` pid; `keep_alive_bar.sh` respawns it) to pick up `Settings.qml` schema changes.
- **Unqualified property lookup only sees the document root**, not arbitrary ancestors. A binding in a
  nested child that reads a property declared on some *middle* object (e.g. `opacity: discHovered ? …`
  where `discHovered` lives on `centerDisc`) fails at runtime with `ReferenceError: … is not defined`
  and the binding silently keeps its default — `qmllint` passes. Qualify it: `centerDisc.discHovered`.
- **`Theme.current.onAccent` is a poor choice for a thin focus/selection ring on a solid‑accent‑filled
  element** — it's tuned for large text/glyph contrast, but on some palettes (e.g. Mint) it's a
  near‑black *tinted the same hue* as the accent fill, so a 1–2px ring in that colour is nearly
  invisible even though it reads fine as text. Use **`Theme.text`** instead for that case (matches
  the existing palette‑swatch‑selection ring convention in `TunePanel`'s Style page) — confirmed via
  screenshot A/B testing while adding keyboard-nav focus rings to `ToggleTile`/`NavItem`/audio tabs.
