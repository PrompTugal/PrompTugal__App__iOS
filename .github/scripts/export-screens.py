#!/usr/bin/env python3
"""Export the screenshots in an .xcresult as <device>-<destination id>.png.

    export-screens.py <Tests.xcresult> <out dir> <device label>

Uses `xcrun xcresulttool export attachments` (Xcode 16+), which writes the
files plus a manifest.json naming each one after its XCTAttachment.
"""
import json, pathlib, re, shutil, subprocess, sys, tempfile

def attachment_id(name: str) -> str:
    """The XCTAttachment name back from xcresulttool's suggested file name.

    xcresulttool puts "_<n>_<UUID>" before what it takes to be the extension,
    and a dotted id's last part looks like one:
        "today_0_<UUID>.png"              -> "today"
        "news_0_<UUID>.newsroom"          -> "news.newsroom"
        "team_0_<UUID>.people"            -> "team.people"
    """
    m = re.fullmatch(r"(.*?)_\d+_[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}(\..*)?", name, re.I)
    if not m:
        return pathlib.Path(name).stem
    head, tail = m.group(1), m.group(2) or ""
    if tail.lower() == ".png":
        tail = ""
    return head + tail


if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
    u = "70EE4FB8-EA45-427B-A980-DF8C0874723C"
    cases = {f"today_0_{u}.png": "today", f"news_0_{u}.newsroom": "news.newsroom",
             f"team_0_{u}.people": "team.people", f"reader_0_{u}.agenda": "reader.agenda",
             f"wall_0_{u}.png": "wall", f"news_1_{u}.home": "news.home"}
    for given, want in cases.items():
        got = attachment_id(given)
        assert got == want, (given, got, want)
    print("ok")
    sys.exit(0)

result, out, device = sys.argv[1], pathlib.Path(sys.argv[2]), sys.argv[3]
out.mkdir(parents=True, exist_ok=True)
raw = pathlib.Path(tempfile.mkdtemp())
subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", result, "--output-path", str(raw)],
               check=True)
manifest = json.loads((raw / "manifest.json").read_text())
count = 0
for test in manifest:
    for att in test.get("attachments", []):
        # Only our screenshots: skip failure debug descriptions (.txt) and screen recordings (.mp4).
        if not att["exportedFileName"].lower().endswith(".png"):
            continue
        name = att.get("suggestedHumanReadableName") or att["exportedFileName"]
        base = attachment_id(name)
        target = out / f"{device}-{base}.png"
        if target.exists():
            sys.exit(f"Two screenshots map to {target.name} (from {name!r})")
        shutil.copy(raw / att["exportedFileName"], target)
        count += 1
        print(target.name)
print(f"{count} screenshots", file=sys.stderr)
if count == 0:
    sys.exit("No screenshots found in the result bundle")
