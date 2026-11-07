#!/usr/bin/env python3
"""Print the affected apps and packages as JSON. Standard library only.

Usage: affected.py <base> <head> [--files-from FILE]
A changed file triggers an app when it is under one of the app's `paths`, or under the
`path` of any package in its closure. A file under `all` triggers every app.
"""
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import apps_lib  # noqa: E402


def under(path, prefix):
    return path == prefix.rstrip("/") or path.startswith(prefix if prefix.endswith("/") else prefix + "/")


def affected(config, files):
    everything = any(under(f, p) for f in files for p in config.get("all", []))
    pkgs = config["packages"]
    changed_pkgs = {n for n, p in pkgs.items() if any(under(f, p["path"]) for f in files)}
    apps = []
    for app, entry in config["apps"].items():
        if everything or any(under(f, p) for f in files for p in entry.get("paths", [])):
            apps.append(app)
        elif changed_pkgs & apps_lib.app_closure(config, app):
            apps.append(app)
    # Packages to test: the changed ones and everything that depends on them.
    test_pkgs = {n for n in pkgs if everything or n in changed_pkgs or apps_lib.closure(config, [n]) & changed_pkgs}
    return {"apps": sorted(apps), "packages": sorted(test_pkgs)}


def changed_files(base, head):
    out = subprocess.run(["git", "diff", "--name-only", f"{base}...{head}"], check=True,
                         capture_output=True, text=True).stdout
    return [l for l in out.splitlines() if l]


def main(argv):
    args = argv[1:]
    files = None
    if "--files-from" in args:
        i = args.index("--files-from")
        with open(args[i + 1], encoding="utf-8") as f:
            files = [l.strip() for l in f if l.strip()]
        del args[i:i + 2]
    if files is None:
        if len(args) != 2:
            print(__doc__, file=sys.stderr)
            return 2
        files = changed_files(*args)
    print(json.dumps(affected(apps_lib.load(), files)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
