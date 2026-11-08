#!/usr/bin/env python3
# miclevel — how loud a sound source is right now, 0..1: its peak over a third
# of a second. The pill asks this of a microphone an app holds open, so the mic
# ring shows only while sound actually comes in (an open, silent mic is not
# "in use" for the person sitting there).
#   python3 miclevel.py <source name>
import array
import subprocess
import sys

src = sys.argv[1] if len(sys.argv) > 1 else "@DEFAULT_SOURCE@"
cmd = ["parec", "-d", src, "--raw", "--format=s16le", "--channels=1",
       "--rate=16000", "--latency-msec=20", "--client-name=pleamar-miclevel"]
try:
    data = subprocess.run(cmd, capture_output=True, timeout=0.35).stdout
except subprocess.TimeoutExpired as e:
    data = e.stdout or b""
samples = array.array("h")
samples.frombytes(data[: len(data) // 2 * 2])
peak = max((abs(x) for x in samples), default=0) / 32768
print(f"{peak:.4f}")
