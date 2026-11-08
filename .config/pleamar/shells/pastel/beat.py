#!/usr/bin/env python3
# beat — listens to what is playing (the default output's monitor) and prints,
# about 30 times a second, one line: "bass mid high beat"
#   bass, mid, high: 0..1, each against its own recent loudest (so quiet songs
#                    move as much as loud ones)
#   beat:            1 on a sudden bass hit, else 0
# The pill runs it only while the control center is open and music plays.
import subprocess
import sys

import numpy as np

RATE, HOP, N = 22050, 735, 2048          # 30 frames a second, ~93 ms window
cmd = ["parec", "-d", "@DEFAULT_MONITOR@", "--raw", "--format=s16le", "--channels=1",
       f"--rate={RATE}", "--latency-msec=20", "--client-name=pleamar-beat"]
p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)

buf = np.zeros(N, dtype=np.float32)
win = np.hanning(N).astype(np.float32)
freqs = np.fft.rfftfreq(N, 1 / RATE)
masks = [(freqs >= lo) & (freqs < hi) for lo, hi in ((30, 150), (150, 2000), (2000, 9000))]
loudest = [1e-3, 1e-3, 1e-3]
avg_bass = 0.0
since_beat = 99

try:
    while True:
        raw = p.stdout.read(HOP * 2)
        if len(raw) < HOP * 2:
            break
        x = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768
        buf = np.roll(buf, -HOP)
        buf[-HOP:] = x
        spec = np.abs(np.fft.rfft(buf * win))
        vals = []
        for i, m in enumerate(masks):
            e = float(np.sqrt(np.mean(spec[m] ** 2)))
            loudest[i] = max(e, loudest[i] * 0.996, 1e-3)   # slow automatic gain
            vals.append(min(1.0, e / loudest[i]))
        bass = vals[0]
        since_beat += 1
        beat = 0
        if bass > avg_bass * 1.3 + 0.08 and bass > 0.45 and since_beat > 7:
            beat, since_beat = 1, 0
        avg_bass = avg_bass * 0.88 + bass * 0.12
        sys.stdout.write(f"{vals[0]:.3f} {vals[1]:.3f} {vals[2]:.3f} {beat}\n")
        sys.stdout.flush()
except (BrokenPipeError, KeyboardInterrupt):
    pass
finally:
    p.terminate()
