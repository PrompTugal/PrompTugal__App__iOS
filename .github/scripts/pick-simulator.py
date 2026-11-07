#!/usr/bin/env python3
"""Print the UDID of an available iPhone simulator on the newest iOS runtime.

Prefers a plain "iPhone NN" (not Pro / Plus / SE) so test runs are comparable.
Creates one if the runner has none.
"""
import json, re, subprocess, sys

def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout

def version(runtime_key):
    nums = re.findall(r"(\d+)", runtime_key.split("iOS-")[-1])
    return tuple(int(n) for n in nums)

devices = json.loads(run("xcrun", "simctl", "list", "devices", "available", "-j"))["devices"]
ios = sorted((k for k in devices if ".iOS-" in k), key=version, reverse=True)
for runtime in ios:
    phones = [d for d in devices[runtime] if d["name"].startswith("iPhone")]
    if not phones:
        continue
    plain = [d for d in phones if re.fullmatch(r"iPhone \d+", d["name"])]
    pick = (plain or phones)[-1]
    print(f"Using {pick['name']} on {runtime.split('.')[-1]} ({pick['udid']})", file=sys.stderr)
    print(pick["udid"])
    sys.exit(0)

runtimes = json.loads(run("xcrun", "simctl", "list", "runtimes", "available", "-j"))["runtimes"]
ios_rt = [r for r in runtimes if r.get("platform") == "iOS"]
if not ios_rt:
    sys.exit("No iOS simulator runtime on this runner")
rt = ios_rt[-1]
dtype = [d for d in rt.get("supportedDeviceTypes", []) if d["name"].startswith("iPhone")][-1]
udid = run("xcrun", "simctl", "create", "CI iPhone", dtype["identifier"], rt["identifier"]).strip()
print(f"Created {dtype['name']} on {rt['name']} ({udid})", file=sys.stderr)
print(udid)
