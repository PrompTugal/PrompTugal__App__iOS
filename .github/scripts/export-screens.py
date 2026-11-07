#!/usr/bin/env python3
"""Export the screenshots in an .xcresult as <device>-<destination id>.png.

    export-screens.py <Tests.xcresult> <out dir> <device label>

Uses `xcrun xcresulttool export attachments` (Xcode 16+), which writes the
files plus a manifest.json naming each one after its XCTAttachment.
"""
import json, pathlib, re, shutil, subprocess, sys, tempfile

result, out, device = sys.argv[1], pathlib.Path(sys.argv[2]), sys.argv[3]
out.mkdir(parents=True, exist_ok=True)
raw = pathlib.Path(tempfile.mkdtemp())
subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", result, "--output-path", str(raw)],
               check=True)
manifest = json.loads((raw / "manifest.json").read_text())
count = 0
for test in manifest:
    for att in test.get("attachments", []):
        name = att.get("suggestedHumanReadableName") or att["exportedFileName"]
        # "news.graph_0_<UUID>.png" -> "news.graph"
        base = re.sub(r"_\d+_[0-9A-F-]{36}$", "", pathlib.Path(name).stem, flags=re.I)
        target = out / f"{device}-{base}.png"
        shutil.copy(raw / att["exportedFileName"], target)
        count += 1
        print(target.name)
print(f"{count} screenshots", file=sys.stderr)
if count == 0:
    sys.exit("No screenshots found in the result bundle")
