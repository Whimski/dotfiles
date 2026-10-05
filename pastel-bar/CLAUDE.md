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
- `panels/ControlCenter.qml` — two glass **drawers** in one fullscreen window: the control center
  slides in from the **right** edge, the music wing (`components/MediaWing.qml`: a steampunk phonograph —
  blurred‑art glass in a brass line‑art frame, a "Now Playing" name tab with a cog and a callout rail (the volume gauge was removed by request), cover
  "sleeve" with a vinyl that slides out and spins while playing, a tonearm that swings onto the record
  and creeps inward with progress, a brass seek rail with a slim fine‑toothed cog knob and counter plaques,
  a riveted play button in a translucent sunburst cog collar, flanked by small `MechWing`s as prev/next — pointing away from it, half‑spread at rest, flapping on hover, beating outward on click) from the **left**. Its "brass" is
  pure `Theme.accent` (`wing.brass`/`brassHi`/`brassLo`/`engraved`) — no gold tint, by request — and
  the panel sits under an always‑on dark scrim (heavier over album art). The wing always opens with the CC (idle "Nothing Playing" card without a player), or alone via
  `Ui.mediaOpen` (`menu toggle media` IPC). Keys: Space/←/→ = play‑pause/prev/next.
- **Motion convention**: panels animate ONE master progress (`ccReveal`, `mediaReveal`, `bloom`,
  `reveal`) with a linear `Behavior`, and derive slide/fade/tilt/stagger from it in bindings via
  `Theme.stagger(t, i, step, span)` / `Theme.easeOutBack` / `Theme.easeOutCubic` — so open and close
  stay in lockstep and cascades need no `SequentialAnimation`s. Continuous spins use `FrameAnimation`
  (a looping `NumberAnimation` with `paused:` warns and loses the angle). The pill's springy
  `OutBack` width overshoot is why `Bar.implicitWidth` has +48 slack.
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
- `components/ClockworkCluster.qml` + `components/Gear.qml` — the expanded pill's outer slots (left, plus
  an `xScale: -1` mirrored twin on the right — a mirror image still meshes; replaced
  the old now‑playing art/title). A meshing gear train with **one degree of freedom**: every wheel's
  angle is `gain*drive + off`, precomputed from tooth ratios and mesh phasing (Gear's tooth 0 sits at
  angle 0 — the phasing depends on it), so the teeth always interlock. `drive` = smooth spin scaled by
  CPU load (`/proc/stat` via `FileView`) + a once‑a‑second escapement tick (one tooth, `easeOutBack`)
  + a wind‑up offset bound to `bar._bloom(1)`. Click = decaying spin kick. `drive`/`ticks` wrap at the
  train's teeth‑LCM period so float precision never drifts the mesh.
- `components/Sprocket.qml` + `ChainDrive.qml` + `MechWing.qml` — more clockwork. `Sprocket` is sized by
  **arc** pitch (`pitchR = teeth*pitch/2π`), so `ChainDrive` (two equal sprockets, centres `links`
  pitches apart) holds exactly `teeth + 2*links` rollers and every roller on a half‑turn sits in a
  valley; one `drive` angle moves wheels and chain together. `MechWing` is a right‑pointing feathered wing
  (layered primaries/coverts/edge scales rooted on a quadratic arm curve, from a static `feathers`
  table; mirror with `Scale { xScale: -1 }`), `spread` 0..1 unfolds it, `size` scales it, `hingeX/hingeY` are where to
  attach it. Wings flank the expanded pill (behind it, outside the input mask — `Bar.implicitWidth`
  reserves their width). `ChainDrive` is currently unused.
- **Gear styles** (after the user's steampunk reference sheets): `Gear` takes `tooth`
  (`trap`/`block`/`saw`/`round`/`fine`), `web` (`auto`/`holes`/`spokes`/`solid`/`rings`), `spokes`,
  `twist` (sweeps spokes into a pinwheel) and `engrave`. Every profile keeps tooth 0 at angle 0 and the
  same pitch/tip/root radii, so styles never break meshing. `web: "auto"` is the original look. A web
  that's too small for spokes/holes falls back to `solid`. `GearTrain`/`ClockworkCluster` spec entries
  carry the same keys per wheel.
- **Steampunk line-art kit** (restrained by request: thin brass outlines, a few corner fittings) —
  `Screw` (slot/cross head), `LinkPlate` (riveted pill plate), `BrassDivider` (rule + end fittings
  `dot`/`screw`/`knurl` + centre `cog`/`plate` + dim offset rail), `BrassFrame` (overlay outline for a
  panel: `corners: [tl,tr,br,bl]` of `screw`/`cross`/`cog`/`none`, optional edge `plate`, dim partial rails)
  and `BrassRing` (circle + offset arc + seated screws). All pure `Theme.accent`, like the music wing.
  Placed so far, deliberately **varied** per surface (the user asked for variety — don't make
  panels twins): the CC drawer frame (screw/cross/screw/cog corners, top plate, cog winds with
  `ccReveal`), the music wing frame (cross screws up top, cogs at the bottom turning with playback,
  bottom plate — inset 11 because the wing `clip`s), and every CC/wing divider in a different
  ends/centre combo. `ToggleTile` is a line‑art brass button (after the "Buttons" sheet): icon in a
  porthole that fills with brass when on, and `fitting` picks one of four bodies — `gears` (Wi‑Fi:
  spoked cogs behind the pill caps, near‑opaque backing so only teeth show), `rails` (BT: ticked
  double rail + shoulder cog), `plate` (Audio: outer half‑shell, link plate, cap screw), `screws`
  (DND: squared frame, corner screws, carry handle, side grip). Cogs/screw turn on toggle.
- **Machinery behind the music wing** — `ControlCenter`'s `machinery` item (declared *before* `MediaWing`
  so it renders behind it) holds two `components/GearTrain.qml`s: big translucent cogs peeking out of
  the wing's right edge and from under its bottom edge (off the screen edge). `GearTrain` is the
  behaviour‑free version of the pill cluster's mesh maths (`spec[i].ang`, optional `spec[i].on` to mesh
  with an earlier wheel; pin wheel 0 via `anchor0`). They ride the wing's slide (and show on a track‑change peek too), wind in with
  `mediaReveal`, and turn at 16°/s while playing, easing to a 2.5°/s idle crawl on pause.
  The CC drawer has its own `ccMachinery` (declared before `ccPanel`): a different train peeking out
  of its left edge and one under its bottom, riding the drawer's slide, winding in with `ccReveal`
  and crawling at 5°/s. Both sides are dressed with line‑art plumbing from the "Decor elements"
  sheet — `BrassArc` (arc rail hugging a wheel, optional `twin` inner rail, screw/dot ends) and
  `BrassPipe` (polyline with rounded elbows, two walls = wide brass stroke under a dark core,
  collars mid‑run, flange screws) — positioned off the trains via `cc.wheelAt(train, i)` /
  `cc.tipOf(train, i)`. Their lines are 0.62 alpha (above the 0.2 blur threshold, which is fine)
  so they stay legible over busy windows.
- **Charging = powered clockwork.** `Bar.power` eases 0↔1 on `Battery.charging` and feeds `power` on
  both `ClockworkCluster`s (overdriven spin, brighter escapement flash) and both `MechWing`s (faster,
  wider flap). `components/LightningArcs.qml` (a `Canvas` over pill + wings, outside the input mask)
  strikes flickering zig‑zag bolts between anchors re‑read per strike via its `links()` function —
  `ClockworkCluster.wheelCenter(i)`, `MechWing.armPoint(t)`/`tipPoint(k)`, mapped with `mapToItem` (so
  the mirrored twins just work). Each strike fires `struck`, which kicks `Bar.zap` into the pill's
  `glow`. No battery on this desktop: to preview, temporarily force `power` to 1.
- **Low battery = worn‑down clockwork.** `Bar.weak` (≤20 %, not charging; 0.6→1 as it drains, eased)
  feeds `droop` on the `MechWing`s (arm sags, feathers hang via `_sag(t)` — tip most — flap slows and
  weakens) and `strain` on the `ClockworkCluster`s (spin slowed ~90 %, a shudder on `drive`, laboured
  ticks with no overshoot, and ~half the ticks *fail*: `_failTick` heaves forward and slips back
  without advancing `ticks`). To preview, temporarily force `weak` to 1.
- **Steampunk pill dressing** — `components/PillFrame.qml`, laid over the expanded pill, builds itself
  from `bar.bloom` and unbuilds in exact reverse: rails draw outward from the centre (sparks riding
  their tips), the end caps sweep round to meet, a screw drops into each cap tip and screws itself in
  (where the wings hinge), the bottom vents open and puff steam, a link plate slides out, tick
  groups click on. `BrassPost`s (inline in `Bar.qml`) extend between the clockwork and the clock.
  The vents breathe a wisp on each escapement tick (`pulse` ← `clockworkLeft.tickP`). The opening
  takes 1000 ms and the close 560 ms.
  - **Visible close**: `Bar.winding` (`mode === "idle" && bloom > 0.02`) keeps the *expanded* layout
    and pill on screen while bloom unwinds (`expLayout`, `shownHidden`); the input mask still drops
    at once (it follows `pillHidden`). The retired idle view stays at opacity 0 so its clock can't
    ghost through the wind‑down.
  - To capture it, grab frames (`grim` in a tight loop) on a monitor where the pill actually shows —
    if it's missing on the focused one, that monitor's active app is likely in `pillYieldApps`.
- `services/Battery.qml` — thin wrapper over `Quickshell.Services.UPower`'s `displayDevice`
  (`present`/`percent`/`charging`). The expanded pill's top row shows a single battery pill (icon +
  `%`, no charging styling — the powered clockwork shows charging) instead of the old separate wifi/bt pills; `present` gates it off
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
  API key). Location auto‑detected once from IP (ipwho.is) into `Settings.weatherLoc` (no UI to set a
  city — the old unused `Weather.setLocation` geocoding helper was removed). Refetches every 15 min and on open when stale. WMO codes map to the new
  weather `IconGlyph`s (sun/moon/cloud/cloudSun/rain/snow/storm/fog).

- **Steampunk references**: the reference sheets the look is based on are in `docs/steampunk-refs/`
  (see its README for which sheet fed which component). Look there before adding new brass pieces.
- **Decor styles** — `Settings.decor` is one string: `"none"`, `"steampunk"` or `"cyberpunk"`
  (one write per switch, mutually exclusive; `""` = unset, falls back to the legacy
  `Settings.steampunk` bool). Read it as `Theme.decor` / `Theme.steampunk` / `Theme.cyberpunk`; never
  write `Settings.steampunk`.
- **Cyberpunk mode** (`Theme.cyberpunk`, toggle in Settings → Wallpaper & Style). Checkpoint before
  it: git tag `pastel-bar-pre-cyberpunk`. Refs in `docs/cyberpunk-refs/`. Colours are the palette's
  **`Theme.accent`** only (by request — not the kit's cyan/magenta). Gate new HUD pieces on
  `Theme.cyberpunk`; `Theme.decorated` (= either mode) gates the overlays' reveal‑driven
  scale/opacity.
  - **Kit**: `Chamfer` (filled chamfered rect — the stand‑in for a rounded `Rectangle`; `cuts`
    `[tl,tr,br,bl]`, `cut`, optional `gradient`), `CyberFrame` (overlay frame: traced outline,
    `corners` `wedge`/`bracket`/`slash`/`none`, `bar`, striped‑notch `tab`, node `rail`; `build` 0..1),
    `CyberDivider` (`node`/`step`/`ticks`/`bar`/`dash`; scan‑in `build`). `BrassDivider` renders a
    `CyberDivider` itself in cyberpunk mode (pick it with `cyber:`), so call sites need no twin.
  - `GlassPanel` turns chamfered (`cuts`/`cut`, default `Theme.cyberCut` 14) — its fill moves into a
    z:-1 `Shape`. A panel's `cuts` and its `CyberFrame`'s must match.
  - **Covered so far**: every panel frame (CC, music wing, settings, launcher, power, polkit,
    weather — each a different corner/bar/tab mix, keep them varied), all dividers, `ToggleTile`
    (chamfered "ACTION" tile + `‖` marker), `Slider`, the music wing's cover/seek/buttons.
    Plus everything inside the panels via `CyberRect` (below), the planets (a turning `HudRing`
    round each disc), notifications (cards, the list under the pill and the toast get
    `CyberFrame`s), and `PanelHud` behind every panel.
  - **`CyberRect`** is a drop‑in for a plain filled `Rectangle` (`color`, `radius`, `border.width`/
    `border.color`, children on top) that draws chamfered in cyberpunk mode and as the original
    rounded rect otherwise. Settings rows/switches/cards/nav/chips/buttons/inputs, CC
    Wi‑Fi/BT/audio rows, audio settings, wallpaper picker, launcher rows, power/polkit buttons and
    weather stats all use it. It can't take `gradient`, `Behavior on border.*` or other
    Rectangle‑only API — keep those as `Rectangle` (+ a `Chamfer` if needed). Colour swatches and
    the planet discs stay round on purpose.
  - **`PanelHud`** — same interface as `PanelMachinery` (`rx/ry/rw/rh`, `reveal`, `variant` 0..3;
    odd variants mirror): big turning segmented rings half behind the side edges, a grid fragment
    past a top corner, a `DataNoise` block under the bottom, a node rail off a side, blinking
    triangle markers. Declared beside every `PanelMachinery`, and for the CC drawer/music wing in
    `ControlCenter`.
  - **Pill** (in `Bar.qml`, all gated on `Theme.cyberpunk`, building off `bloom` like steampunk):
    `HudRing` gauges (segmented turning ring + 270° value arc + counter‑rotating dashes + pulsing
    reticle) and `CyberReadout`s (label, % with blinking block cursor, history bars) for CPU (left)
    and memory (right) from the `SysLoad` service (samples `/proc/stat` + `/proc/meminfo` at 1 Hz,
    only while cyberpunk is on); `CyberPost`s (inline) in the `BrassPost` slots; the clock is a
    `GlitchText` (RGB‑split ghosts in accent/accent2 + a sheared slice, every 3–9 s — plain text in
    other modes); uppercase date over a 30‑tick seconds ruler (`bar.secs`); `CyberFin`s in the wings'
    slot (chase lights); a `CyberFrame` over the pill and a scanline sweep (kept inside the
    chamfered ends) off `bar.cyPhase`. OSD: chamfered icon box + a 20‑cell segmented meter;
    `osdReveal`/`osdWinding` now run for either decor mode.
  - **Idle effects**: `CyberFrame` (once built, while `idle`) runs a comet round its outline every
    `lap` s and blinks its rails' node lights. Every idle animation is a `FrameAnimation`/`Timer`
    gated on visibility + the pill/panel being open.
  - Qt 6.11's `Item` has a FINAL `top` — don't declare a property named `top` (load fails).
- **Steampunk mode** (`Theme.steampunk`, default **off**; toggle in Settings → Wallpaper & Style). Off = plain glass everywhere: no gears, wings, lightning, `PillFrame`,
  machinery/plumbing or brass frames; `BrassDivider` falls back to a 1px `strokeGlass` hairline,
  `ToggleTile` to its solid tile, and `MediaWing` (`wing.sp`) to a clean card — centred cover, no
  vinyl/tonearm, plain label, round seek knob, round prev/play/next. The pill's bloom timing drops
  back to the quick `animDrawer`/`animMed`. Anything new and clockwork‑flavoured must gate on
  `Theme.steampunk` too.
  - **Coverage**: pill (+OSD), CC, music wing, settings, launcher, power menu, polkit, weather,
    notifications (CC cards, the list under the pill, the toast), sliders, the settings planets.
  - **Self‑building frames**: `BrassFrame.build` and `BrassDivider.build` (0..1) assemble them —
    edges draw from their middles, corner arcs sweep in to meet, screws drop and screw home, cogs
    spin in, plate slides out — bound to each surface's master reveal so closing replays it
    backwards. Overlays (`TunePanel`, `Launcher`, `PowerMenu`, `PolkitDialog`, `WeatherPanel`) gained
    a linear `reveal`/`spReveal`; in steampunk mode their panel's scale/opacity **follow it** (their
    `Behavior`s are disabled) so the teardown is visible before the fade. Each gets its own
    `components/PanelMachinery.qml` (`variant` 0..3 = a different wheel/pipe set) declared before
    the panel, and its own corner mix — keep them varied.
  - OSD has `Bar.osdReveal` + `osdWinding` (mirrors `winding`) so `PillFrame` builds/unbuilds round
    it too. Settings pages fade/slide in and draw a `BrassDivider` under the title on every switch.
  - Music wing: no record player any more — the cover sits centred in a grand border (double
    `BrassFrame`, cogs on every corner, a big half‑cog behind the top, side cogs, tooth rack,
    rivets) built off `stage.build`.
  - The pill's `MechWing`s take `tilt: 14` (new `MechWing.tilt`, added into `armSwing`) — the pill
    hugs the top edge, and untilted the upstroke clipped off‑screen.

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
- **Glass blur is Hyprland's**, not QML: every overlay/bar `PanelWindow` sets
  `WlrLayershell.namespace: "pastel-bar"` and `hyprland.lua` has a `pastel-bar-blur` layer rule
  (`blur = true, ignore_alpha = 0.2`). Anything that should stay *un*‑frosted on those fullscreen
  surfaces must stay under 20% alpha (e.g. the CC edge vignettes); the dim backdrops of the
  power menu/polkit are deliberately above it, so they frost the whole screen; the **launcher's**
  backdrop is 0.15 so it only dims, never frosts (by request). Glass below ~24%
  panel opacity drops under the threshold and loses its blur. The wallpaper uses `pastel-wallpaper`.
  Namespace is fixed at surface creation — restart the shell after changing it.
- Single‑instance overlays open on the **focused monitor** via `Ui.focusedScreen` (from
  `Hyprland.focusedMonitor`); each window only re‑targets while hidden.
- Environment rules: only **one** notification daemon and **one** polkit agent per session (don't also
  run mako/dunst or hyprpolkitagent). **pastelbar renders the wallpaper** (no swww/hyprpaper).
- Reloading resets transient `Ui` flags (open panels
  close). `Slider`‑like inline containers need an explicit width binding (anchors‑fill on a
  property‑parented item doesn't establish width) — see `TunePanel` `GroupCard`.
- **`Settings` write/reload race**: `FileView` has `watchChanges:true`→`reload()`, so writing several
  scalar `JsonAdapter` properties in quick succession lets the reload from an earlier write clobber a
  later value (seen: `weatherLon` persisting as `0`). Persist related fields as **one object/array**
  written in a single assignment (see `weatherLoc`, `wallpapers`, `mediaBlacklist`), not N sequential
  scalar writes.
- Editing the **`Settings` singleton** may not fully hot‑reload live — restart the shell (kill the
  `qs` pid with `pkill -x qs`; `keep_alive_bar.sh` respawns it. **Not** `pkill -f "qs -p …"`: that
  also matches the keep‑alive loop's own command line and kills it, so nothing respawns) to pick up `Settings.qml` schema changes.
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
