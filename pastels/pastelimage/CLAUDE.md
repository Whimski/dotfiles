# pastelimage

A **Qt 6 Quick** image **viewer + light editor** styled by the shared `pasteltheme` module.
View/browse a folder of images, pan/zoom/rotate, **blur** areas (redaction) and **pen**-annotate,
then export a PNG. See `../CLAUDE.md` for the family/theme wiring.

## Build & run

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
./build/pastelimage [/path/to/image]     # or a folder
```

QML compiled into the binary (URI `PastelImage`) → **rebuild after `qml/` edits**; `../pasteltheme/`
edits need no rebuild. Aids: `PASTELIMAGE_START` (open a path), `PASTELIMAGE_SCREENSHOT=/tmp/x.png`
(offscreen render). Desktop entry `desktop_files/pastelimage.desktop` → `~/.local/share/applications`.

## Structure

- `src/main.cpp` — Material + transparent window, context props `Settings` + `Img`, theme import
  path, `PASTELIMAGE_START` open, screenshot aid.
- `src/ImageController` (`Img`) — current image + the folder's image list; `openPath/openUrl`,
  `next/prev` (wrap), `rotateCW/CCW` (view-only), `source`/`fileName`/`index`/`count`/`hasImage`.
- `src/SettingsStore` (`Settings`) — theme keys (mirror the family) + `background`
  (`theme`/`dark`/`checker`) + window size.
- `qml/Main.qml` — hosts `TopBar` + `ToolRail` + `ImageCanvas`; owns editor state (`tool`,
  `brushColor`, `brushSize`); Open/Save `FileDialog`s; shortcuts.
- `qml/ImageCanvas.qml` — the core: image in **image-pixel space** (`imageItem`) with a **blurred
  copy revealed under a painted mask** (`MultiEffect` + a mask `Canvas`) and a **pen** stroke
  `Canvas`; zoom/pan/fit; a stroke model for **undo/clear**; `save()` via `grabToImage` at native
  resolution.
- `qml/TopBar.qml`, `qml/ToolRail.qml` (View/Pen/Blur + size + colour), `qml/components/SettingsDialog.qml`.

## Conventions & gotchas

- Edits live on layers that are **children of `imageItem`**, so strokes/blur pan/zoom/rotate *with*
  the image and export aligned. Coordinates from the drawing `MouseArea` are already image-pixel
  space (child-local, pre-scale/rotate).
- Blur = a full `MultiEffect` blur of the image **masked** to the painted regions (mask `Canvas`
  alpha). Pen = a separate stroke `Canvas`. Both re-rasterise from the `strokes` array (undo pops it).
- Rotation is **view-only** for now (not baked on save) — that's for the editor's next pass, along
  with crop and adjustments.
- `save()` strips `file://` before `saveToFile`. Wheel zooms in any tool; pan is the View tool.
