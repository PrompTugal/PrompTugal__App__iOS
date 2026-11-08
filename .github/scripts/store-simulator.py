#!/usr/bin/env python3
"""Create a fresh simulator of the first available device type from a list, on the newest iOS runtime.

    store-simulator.py "iPhone 17 Pro Max" "iPhone 16 Pro Max"      -> prints the UDID

For App Store screenshots, where the device decides the pixel size. Tries the names in order and
exits with an error naming what the runner offers if none exists. The job deletes the device at
the end (xcrun simctl delete <udid>).
"""
import json, os, re, subprocess, sys

names = sys.argv[1:]
if not names:
    sys.exit("usage: store-simulator.py <device type name>...")

def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout

runtimes = [r for r in json.loads(run("xcrun", "simctl", "list", "runtimes", "available", "-j"))["runtimes"]
            if r.get("platform") == "iOS"]
if not runtimes:
    sys.exit("No iOS simulator runtime on this runner")
runtimes.sort(key=lambda r: tuple(int(n) for n in re.findall(r"\d+", r.get("version", "0"))), reverse=True)
rt = runtimes[0]
offered = {d["name"]: d["identifier"] for d in rt.get("supportedDeviceTypes", [])}
for name in names:
    if name in offered:
        tag = "-".join(os.environ.get(k, "") for k in ("GITHUB_RUN_ID", "GITHUB_JOB", "RUNNER_NAME"))
        udid = run("xcrun", "simctl", "create", f"CI-store {name} {tag}", offered[name], rt["identifier"]).strip()
        print(f"Created {name} on {rt['name']} ({udid})", file=sys.stderr)
        print(udid)
        sys.exit(0)
sys.exit(f"None of {names} on {rt['name']}. The runtime offers: {sorted(offered)}")
