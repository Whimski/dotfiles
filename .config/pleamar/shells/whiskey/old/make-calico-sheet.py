#!/usr/bin/env python3
"""Turn the calico reference sheet into calico.png for neko.plm.

    python3 make-calico-sheet.py SOURCE.png [calico.png]

The source is pixel art drawn 5x on white: 4 columns x 6 rows (walk down,
right, up, left; stand; sit and groom). The output is the same grid at the
art's own size —one screen pixel per art pixel—, with the background clear,
the ground shadows a translucent black, and a pixel of nothing round each
frame. neko.plm draws it with `pixels` at a whole number of times that size.
"""
import sys
from collections import deque

import numpy as np
from PIL import Image

SCALE, OFF_X, OFF_Y = 5, 3, 4          # the art's pixel size and where its grid starts
COLS, ROWS = 4, 6
SHADOW_ALPHA = 0.32

src = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else 'calico.png'

a = np.asarray(Image.open(src).convert('RGB')).astype(float)
nx, ny = (a.shape[1] - OFF_X) // SCALE, (a.shape[0] - OFF_Y) // SCALE

# One art pixel = the median of the middle of its block (away from JPEG fringes).
art = np.zeros((ny, nx, 3))
for j in range(ny):
    for i in range(nx):
        y0, x0 = OFF_Y + j * SCALE, OFF_X + i * SCALE
        art[j, i] = np.median(a[y0 + 1:y0 + 4, x0 + 1:x0 + 4].reshape(-1, 3), 0)

# Snap to the palette: colours used often enough are the palette, the rest
# (compression noise) go to their nearest.
q = (np.round(art / 16) * 16).reshape(-1, 3)
uniq, counts = np.unique(q, axis=0, return_counts=True)
seeds = uniq[counts >= 12]
pal = []
for c in seeds[np.argsort(-counts[counts >= 12])]:
    if all(np.abs(c - p).sum() > 40 for p in pal):
        pal.append(c)
pal = np.array(pal)
members = [[] for _ in pal]
flat = art.reshape(-1, 3)
near = np.argmin(((flat[:, None, :] - pal[None]) ** 2).sum(-1), 1)
pal = np.array([flat[near == k].mean(0) if (near == k).any() else pal[k] for k in range(len(pal))])
near = np.argmin(((flat[:, None, :] - pal[None]) ** 2).sum(-1), 1)
art = pal[near].reshape(ny, nx, 3)

def is_white(c): return c.min() > 225
def is_grey(c): return 110 < c.mean() < 200 and c.max() - c.min() < 14

# Background: the white reachable from the edge without crossing an outline.
bg = np.zeros((ny, nx), bool)
q = deque((j, i) for j in range(ny) for i in range(nx)
          if (j in (0, ny - 1) or i in (0, nx - 1)) and is_white(art[j, i]))
for j, i in q: bg[j, i] = True
while q:
    j, i = q.popleft()
    for dj, di in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        y, x = j + dj, i + di
        if 0 <= y < ny and 0 <= x < nx and not bg[y, x] and is_white(art[y, x]):
            bg[y, x] = True; q.append((y, x))

rgba = np.zeros((ny, nx, 4), np.uint8)
rgba[..., :3] = np.clip(art, 0, 255).astype(np.uint8)
rgba[..., 3] = np.where(bg, 0, 255)
# The ground shadows: grey next to the clear background becomes a translucent black.
for j in range(ny):
    for i in range(nx):
        if not bg[j, i] and is_grey(art[j, i]):
            rgba[j, i] = (0, 0, 0, int(255 * SHADOW_ALPHA))

# Cut the grid into frames of one shared size (cells are ~32 art pixels).
cw, ch = nx / COLS, ny / ROWS
boxes = []
for r in range(ROWS):
    for c in range(COLS):
        y0, x0 = int(round(r * ch)), int(round(c * cw))
        cell = rgba[y0:int(round((r + 1) * ch)), x0:int(round((c + 1) * cw)), 3] > 0
        ys, xs = np.nonzero(cell)
        boxes.append((y0, x0, ys.min(), ys.max(), xs.min(), xs.max()))
top = min(b[2] for b in boxes); bottom = max(b[3] for b in boxes)
left = min(b[4] for b in boxes); right = max(b[5] for b in boxes)
fw, fh = right - left + 1, bottom - top + 1
FW, FH = fw + 2, fh + 2
sheet = np.zeros((FH * ROWS, FW * COLS, 4), np.uint8)
for k, (y0, x0, *_ ) in enumerate(boxes):
    r, c = divmod(k, COLS)
    sheet[r * FH + 1:r * FH + 1 + fh, c * FW + 1:c * FW + 1 + fw] = \
        rgba[y0 + top:y0 + top + fh, x0 + left:x0 + left + fw]
Image.fromarray(sheet, 'RGBA').save(out)

# Where the feet are in a frame: the middle of the stand pose's shadow.
r, c = 4, 1
f = sheet[r * FH:(r + 1) * FH, c * FW:(c + 1) * FW]
sh = np.argwhere((f[..., 3] > 0) & (f[..., 3] < 255))
print(f'{out}: {sheet.shape[1]}x{sheet.shape[0]}, {COLS}x{ROWS} frames of {FW}x{FH}, '
      f'{len(pal)} colours, feet at {sh[:, 1].mean():.1f}, {sh[:, 0].mean():.1f} in a frame')
