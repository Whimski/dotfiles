# pastelfm

A **Qt 6 Quick** file manager (local + SSH/SFTP + Samba) styled by the shared `pasteltheme`
module. See `../CLAUDE.md` for the family + theme wiring.

## Build & run

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
./build/pastelfm [/path/to/open]
```

QML is compiled into the binary via `qt_add_qml_module` (URI `PastelFM`) → **edits under `qml/`
require a rebuild**. Editing `../pasteltheme/` does **not** (loaded from the import path at runtime).

- Env: `PASTELFM_START` (start dir), `PASTELFM_SCREENSHOT=/tmp/x.png` (offscreen render aid → exits),
  `PASTEL_QML_IMPORT_PATH` (override the theme module dir, default `~/dotfiles/pastels`).
- Desktop entry: `desktop_files/pastelfm.desktop`, symlinked into `~/.local/share/applications`.

## Structure

- `src/main.cpp` — Material style, transparent surface, `engine.addImportPath(~/dotfiles/pastels)`,
  `loadFromModule("PastelFM","Main")`, screenshot aid.
- `src/` backends (context properties): `FileSystemModel` (registered type), `FileOperations` (`FileOps`),
  `MountManager` (`Mounts`, SSH/Samba via `Process`), `SettingsStore` (`Settings`, QSettings under
  `~/.config/PastelFM`: `theme`, `mode`, `customPrimary`, `customSecondary`, `windowOpacity`,
  bookmarks, connections, window size).
- `qml/` — `Main.qml` (ApplicationWindow, tabs; binds `Theme.*` from `Settings`), `Toolbar.qml`,
  `Sidebar.qml`, `FileView.qml`, `components/` (`FileDelegate`, `PastelButton`, dialogs,
  `SettingsDialog` = theme picker + light/dark/auto + custom + opacity). All `import pasteltheme`.

## Conventions & gotchas

- Icons: `pasteltheme` `IconGlyph` (the local `Icon.qml` was removed).
- Theme is driven from `Main.qml`: `syncTheme()` copies `Settings` → `Theme.name/mode/customPrimary/
  customSecondary/panelOpacity`; a `Connections` block keeps them live.
- Window is transparent; "glass" reads as translucent panels over `Theme.current.bg` (no compositor
  blur inside a normal window).
- A build dir configured at a different absolute path has a **stale CMake cache** — `rm -rf build` and
  reconfigure (e.g. after moving the repo).
