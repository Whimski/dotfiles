#!/usr/bin/env python3
"""Cut the cat poses out of the pink reference sheet into cat.png for neko.plm.

    python3 make-cat-sheet.py SOURCE.png [cat.png]

The source is a 5x5 grid of poses on pink (about 100 px a cell). The output is
one row per facing (as drawn = left, mirrored = right), one frame per pose in
FRAMES' order, each with a pixel of nothing round it. neko.plm counts frames
in that order, so keep the two in step.
"""
import sys
from collections import deque

import numpy as np
from PIL import Image

FRAMES = [('walk1', 0, 0), ('walk2', 0, 1), ('walk3', 0, 2), ('walk4', 0, 3),
          ('sit', 1, 2), ('groom', 3, 1), ('stretch', 4, 4), ('sleep', 2, 2), ('jump', 3, 2)]
CELL_W, CELL_H = 100, 99.6
GROUND = 77                     # where the drawn shadows sit, from the top of a cell
PINK = np.array([255, 211, 250.])

src = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else 'cat.png'

a = np.asarray(Image.open(src).convert('RGB')).astype(float)
R, G, B = a[..., 0], a[..., 1], a[..., 2]

# Background: light, with red and blue above green. White fur has neither,
# blue shading has blue above red, and a tongue or an outline is not light.
pinkness = np.minimum(R, B) - G
alpha = 1 - np.clip((pinkness - 8) / 26, 0, 1) * np.clip((G - 170) / 25, 0, 1)
# The drawn ground shadows (magenta), which the scene draws itself.
alpha[(R > 120) & (R < 235) & (B > 120) & (B < 240) & (np.abs(R - B) < 28) & (R - G > 38) & (G < 185)] = 0
# The screenshot's white frame.
alpha[:9] = 0; alpha[-9:] = 0; alpha[:, :9] = 0; alpha[:, -9:] = 0
A = alpha[..., None]
rgb = np.clip(np.where(A > 0.02, (a - (1 - A) * PINK) / np.maximum(A, 0.02), 0), 0, 255)
cut = np.dstack([rgb, alpha * 255]).astype(np.uint8)
H, W = alpha.shape

# Connected shapes, so a cell takes only its own cat.
solid = alpha >= 60 / 255
lab = np.zeros((H, W), int)
comps = []
for y in range(H):
    for x in range(W):
        if solid[y, x] and not lab[y, x]:
            k = len(comps) + 1
            q = deque([(y, x)]); lab[y, x] = k; pts = []
            while q:
                cy, cx = q.popleft(); pts.append((cy, cx))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < H and 0 <= nx < W and solid[ny, nx] and not lab[ny, nx]:
                            lab[ny, nx] = k; q.append((ny, nx))
            comps.append(np.array(pts))

keep = {}
for name, r, c in FRAMES:
    x0, y0 = c * CELL_W, r * CELL_H
    ks = []
    for i, p in enumerate(comps):
        h, w = np.ptp(p[:, 0]) + 1, np.ptp(p[:, 1]) + 1
        if len(p) < 30 or min(h, w) <= 3:          # specks and slivers
            continue
        cy, cx = p.mean(0)
        if x0 <= cx < x0 + CELL_W and y0 <= cy < y0 + CELL_H:
            ks.append(i + 1)
    keep[name] = (ks, x0, y0)

# One window for every frame, relative to its cell, so the poses keep their
# place on the ground as drawn and the walk does not jitter.
lo, hi = np.array([1e9, 1e9]), np.array([-1e9, -1e9])
for ks, x0, y0 in keep.values():
    ys, xs = np.nonzero(np.isin(lab, ks))
    lo = np.minimum(lo, [ys.min() - y0, xs.min() - x0])
    hi = np.maximum(hi, [ys.max() - y0, xs.max() - x0])
oy, ox = int(np.floor(lo[0])) - 1, int(np.floor(lo[1])) - 1
fh, fw = int(np.ceil(hi[0])) + 2 - oy, int(np.ceil(hi[1])) + 2 - ox
fw += fw % 2
FW, FH = fw + 2, fh + 2

sheet = Image.new('RGBA', (FW * len(FRAMES), FH * 2), (0, 0, 0, 0))
for i, (name, r, c) in enumerate(FRAMES):
    ks, x0, y0 = keep[name]
    m = np.isin(lab, ks)
    grow = m.copy()                                 # and the soft edge round it
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            grow |= np.roll(np.roll(m, dy, 0), dx, 1)
    img = cut.copy()
    img[..., 3] = np.where(grow, img[..., 3], 0)
    X0, Y0 = int(round(x0)) + ox, int(round(y0)) + oy
    frame = Image.fromarray(img, 'RGBA').crop((X0, Y0, X0 + fw, Y0 + fh))
    sheet.paste(frame, (i * FW + 1, 1))
    sheet.paste(frame.transpose(Image.FLIP_LEFT_RIGHT), (i * FW + 1, FH + 1))
sheet.save(out)
print(f'{out}: {sheet.width}x{sheet.height}, {len(FRAMES)} frames of {FW}x{FH}, '
      f'feet at {FW / 2:g}, {GROUND - oy + 1} in a frame')
