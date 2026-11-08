#!/usr/bin/env python3
"""Check App Store screenshot sizes.

    store-check.py <kind> <file>...        kind: iphone-6.9 | iphone-6.5 | ipad-13
    store-check.py --self-test

Reads the pixel size from the PNG or JPEG header. Portrait or landscape, in either order, must be one
of the sizes App Store Connect accepts for that display size. Prints one line per file; exits 1 if any
file has another size.
"""
import struct, sys

ACCEPTED = {
    "iphone-6.9": {(1320, 2868), (1290, 2796), (1260, 2736)},
    "iphone-6.5": {(1284, 2778), (1242, 2688)},
    "ipad-13": {(2064, 2752), (2048, 2732)},
}

def size(path):
    with open(path, "rb") as f:
        head = f.read(32)
        if head[:8] == b"\x89PNG\r\n\x1a\n":
            return struct.unpack(">II", head[16:24])
        if head[:2] == b"\xff\xd8":  # JPEG: scan for a start-of-frame marker
            f.seek(2)
            while True:
                b = f.read(1)
                while b and b != b"\xff":
                    b = f.read(1)
                m = f.read(1)
                while m == b"\xff":
                    m = f.read(1)
                if not m:
                    break
                if m[0] in (0xC0, 0xC1, 0xC2):
                    f.read(3)
                    h, w = struct.unpack(">HH", f.read(4))
                    return (w, h)
                seg = struct.unpack(">H", f.read(2))[0]
                f.seek(seg - 2, 1)
    raise ValueError(f"{path}: not a PNG or JPEG")

def ok(kind, w, h):
    return (min(w, h), max(w, h)) in {(min(a, b), max(a, b)) for a, b in ACCEPTED[kind]}

if sys.argv[1:] == ["--self-test"]:
    assert ok("iphone-6.9", 1320, 2868) and ok("iphone-6.9", 2868, 1320)
    assert ok("iphone-6.5", 1284, 2778) and not ok("iphone-6.5", 1320, 2868)
    assert ok("ipad-13", 2752, 2064) and not ok("ipad-13", 1600, 1200)
    print("ok")
    sys.exit(0)

kind, files = sys.argv[1], sys.argv[2:]
if kind not in ACCEPTED:
    sys.exit(__doc__)
files = [f for f in files if not f.endswith("*.jpg") and not f.endswith("*.png")]  # an unmatched glob
if not files:
    sys.exit("store-check.py: no files to check")
bad = 0
for p in files:
    w, h = size(p)
    good = ok(kind, w, h)
    bad += not good
    print(f"{'ok ' if good else 'BAD'} {p}: {w}x{h}")
sys.exit(1 if bad else 0)
