#!/usr/bin/env python3
"""Make screenshot PNGs display the same everywhere: drop orientation metadata.

    png-normalize.py [--landscape] FILE...

XCTest's iPad landscape screenshots store upright landscape pixels but carry an
EXIF Orientation tag (8). Browsers obey it and turn the picture on its side;
viewers that ignore EXIF don't. This rewrites each PNG without eXIf chunks and
without XMP text chunks, so the stored pixels are the picture. Pixel data is
not touched. Then it checks: no eXIf left, and with --landscape, width > height
(from IHDR, the real stored size). Exit 1 if any check fails.
"""
import struct, sys, zlib

SIG = b"\x89PNG\r\n\x1a\n"
DROP_TEXT_KEYS = (b"XML:com.adobe.xmp",)


def chunks(data):
    if data[:8] != SIG:
        raise ValueError("not a PNG")
    pos = 8
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        yield kind, body
        pos += 12 + length


def chunk(kind, body):
    return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)


def normalize(path):
    data = open(path, "rb").read()
    out, dropped, size = [SIG], [], None
    for kind, body in chunks(data):
        if kind == b"IHDR":
            size = struct.unpack(">II", body[:8])
        if kind == b"eXIf" or (kind in (b"iTXt", b"tEXt", b"zTXt") and body.split(b"\0", 1)[0] in DROP_TEXT_KEYS):
            dropped.append(kind.decode())
            continue
        out.append(chunk(kind, body))
    if dropped:
        open(path, "wb").write(b"".join(out))
    return size, dropped


def check(path):
    return [k for k, _ in chunks(open(path, "rb").read()) if k == b"eXIf"]


def main(argv):
    landscape = "--landscape" in argv
    files = [a for a in argv if not a.startswith("--")]
    bad = 0
    for f in files:
        (w, h), dropped = normalize(f)
        note = f" (removed {', '.join(dropped)})" if dropped else ""
        print(f"{f.rsplit('/', 1)[-1]} {w}x{h}{note}")
        if check(f):
            print(f"::error::{f} still has an eXIf chunk"); bad = 1
        if landscape and w <= h:
            print(f"::error::{f} is {w}x{h}, not landscape"); bad = 1
    return bad


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        import tempfile, os
        ihdr = struct.pack(">IIBBBBB", 4, 2, 8, 2, 0, 0, 0)
        raw = zlib.compress(b"".join(b"\0" + b"\0\0\0" * 4 for _ in range(2)))
        exif = b"MM\0*\0\0\0\x08\0\x01\x01\x12\0\x03\0\0\0\x01\0\x08\0\0\0\0\0\0"
        png = SIG + chunk(b"IHDR", ihdr) + chunk(b"eXIf", exif) + chunk(b"IDAT", raw) + chunk(b"IEND", b"")
        fd, p = tempfile.mkstemp(suffix=".png"); os.write(fd, png); os.close(fd)
        assert main([p, "--landscape"]) == 0 and not check(p)
        assert open(p, "rb").read().count(b"IDAT") == 1
        os.remove(p)
        print("ok")
        sys.exit(0)
    sys.exit(main(sys.argv[1:]))
