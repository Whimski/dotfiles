#!/usr/bin/env python3
"""Make a calico sheet from the catz pack's white and orange cats.

    python3 make-calico-catz.py WHITE.png ORANGE.png [catz.png] [--seed N]

The pack's colour sheets are the same drawings with different palettes, so a
calico is chosen pixel by pixel: white fur, with orange patches taken from the
orange sheet and black ones made by darkening the white sheet's fur shades.
Outlines, eyes, nose and inner ears stay as drawn.

The patches are placed relative to each frame's body (the middle of what is
above the legs), so they travel with the cat through an animation instead of
sliding over it. --seed picks another arrangement of patches.
"""
import sys

import numpy as np
from PIL import Image

args = [a for a in sys.argv[1:] if not a.startswith('--')]
seed = int(sys.argv[sys.argv.index('--seed') + 1]) if '--seed' in sys.argv else 7
if '--seed' in sys.argv:
    args.remove(str(seed))
white_path, orange_path = args[0], args[1]
out = args[2] if len(args) > 2 else 'catz.png'

W = np.asarray(Image.open(white_path).convert('RGBA')).copy()
O = np.asarray(Image.open(orange_path).convert('RGBA'))
F = 32                                   # frame size

# The white sheet's fur shades, and what each is in black.
FUR = {
    (225, 222, 231): (52, 47, 56),       # fur
    (189, 181, 200): (33, 29, 37),       # fur in shade
}

rng = np.random.default_rng(seed)
# Coarse fixed noise (in pixels from the body's middle), so edges are ragged.
noise_a = rng.uniform(-1, 1, (10, 10))
noise_b = rng.uniform(-1, 1, (10, 10))
split = rng.uniform(-2, 2)               # where orange gives way to black
flip = rng.integers(0, 2) * 2 - 1        # which side the orange is on

def smooth(n, dx, dy):
    """Bilinear look-up of a noise grid with 3 px cells."""
    gx, gy = dx / 3 + 5, dy / 3 + 5
    x0, y0 = int(np.floor(gx)) % 10, int(np.floor(gy)) % 10
    x1, y1 = (x0 + 1) % 10, (y0 + 1) % 10
    fx, fy = gx - np.floor(gx), gy - np.floor(gy)
    top = n[y0, x0] * (1 - fx) + n[y0, x1] * fx
    bot = n[y1, x0] * (1 - fx) + n[y1, x1] * fx
    return top * (1 - fy) + bot * fy

def field(dx, dy):
    """+1 orange, -1 black, 0 white, at (dx, dy) from the middle."""
    # coloured above the middle (the back and head), white below (chest, belly)
    if dy > 0.5 + 2.2 * smooth(noise_a, dx, dy):
        return 0
    # a white spot here and there inside the colour
    if smooth(noise_b, dx * 1.6, dy * 1.6) > 0.62:
        return 0
    side = flip * (dx - split) + 2.5 * smooth(noise_b, dx, dy)
    return 1 if side < 0 else -1

out_img = W.copy()
rows, cols = W.shape[0] // F, W.shape[1] // F
for r in range(rows):
    for c in range(cols):
        y0, x0 = r * F, c * F
        a = W[y0:y0 + F, x0:x0 + F, 3] > 0
        if not a.any():
            continue
        ys, xs = np.nonzero(a)
        body = ys < ys.max() - 4            # leave the legs out of where the middle is
        if body.sum() < 10:
            body = np.ones_like(ys, bool)
        cy, cx = ys[body].mean(), xs[body].mean()
        low = ys.max() - 3.5                # the legs and paws stay white
        for y, x in zip(ys, xs):
            px = tuple(int(v) for v in W[y0 + y, x0 + x, :3])
            if px not in FUR and tuple(O[y0 + y, x0 + x, :3]) == px:
                continue                    # outline, eyes, nose: as drawn
            if y > low:
                continue
            f = field(x - cx, y - cy)
            if f > 0:
                out_img[y0 + y, x0 + x] = O[y0 + y, x0 + x]
            elif f < 0 and px in FUR:
                out_img[y0 + y, x0 + x, :3] = FUR[px]

Image.fromarray(out_img, 'RGBA').save(out)
print(f'{out}: calico, seed {seed}')
