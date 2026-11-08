#!/usr/bin/env python3
"""Download the build seed for an app: the core pack of a site's manifest, verified, as a folder that looks like the site.

    fetch_seed.py [--site https://promptugal.news/] [--out Apps/PrompTugal/Seed/promptugal.news] [--pack core]

The folder holds `manifest.json` (only the seeded files) and each file at its manifest path. The app's PTSync
`ContentStore` installs it on first launch and keeps only files whose size and SHA-256 match. Standard library only.

The pack rules below mirror `PackRules.promptugalNews` in Packages/PTSync/Sources/PTSync/Manifest.swift; the test
checks they agree.
"""
import argparse
import hashlib
import json
import os
import re
import sys
import urllib.parse
import urllib.request

MAX_MANIFEST = 8 * 1024 * 1024
MAX_FILE = 64 * 1024 * 1024
MAX_FILES = 20_000

# Ordered, first match wins. None: never fetched.
RULES = [
    ("sw.js", None), ("api/v1/deploy-exclude.txt", None),
    ("api/v1/live/", "core"), ("api/v1/days", "core"), ("api/v1/events", "core"),
    ("api/v1/stories", "core"), ("api/v1/newsletter", "core"), ("api/v1/index.json", "core"),
    ("api/v1/ontology.json", "core"), ("api/v1/people.json", "core"),
    ("api/v1/organisations.json", "core"), ("api/v1/companies.json", "core"),
    ("api/v1/places.json", "core"), ("api/v1/topics.json", "core"),
]
FALLBACK = "full"


def pack_for(path):
    for prefix, pack in RULES:
        if path.startswith(prefix):
            return pack
    return FALLBACK


def is_safe_path(path):
    """The same rule as PTSync's `SyncPath.isSafe`."""
    if not path or len(path.encode()) > 512 or path.startswith("/") or "\\" in path:
        return False
    if any(c in path for c in "?#%") or any(ord(c) < 0x20 or ord(c) == 0x7F for c in path):
        return False
    parts = path.split("/")
    if any(p in ("", ".", "..") for p in parts):
        return False
    return ":" not in parts[0]


def well_formed(entry):
    return (isinstance(entry, dict) and isinstance(entry.get("path"), str) and is_safe_path(entry["path"])
            and isinstance(entry.get("bytes"), int) and not isinstance(entry["bytes"], bool)
            and 0 <= entry["bytes"] <= MAX_FILE
            and isinstance(entry.get("sha256"), str) and re.fullmatch(r"[0-9a-f]{64}", entry["sha256"]) is not None)


def read_url(url, limit, opener=urllib.request.urlopen):
    with opener(url, timeout=60) as response:
        data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError(f"{url} is larger than {limit} bytes")
    return data


def fetch_seed(site, out, packs=("core",), allow_http=False, opener=urllib.request.urlopen, log=print):
    """Returns the list of seeded entries. Raises on any file that does not verify."""
    base = site if site.endswith("/") else site + "/"
    parsed = urllib.parse.urlparse(base)
    if parsed.scheme != "https" and not (allow_http and parsed.scheme == "http"):
        raise ValueError("the site must be https")
    manifest_bytes = read_url(base + "api/v1/manifest.json", MAX_MANIFEST, opener)
    raw = json.loads(manifest_bytes)
    files = raw.get("files")
    if not isinstance(files, list) or len(files) > MAX_FILES:
        raise ValueError("the manifest has no usable file list")
    by_path = {}
    for entry in files:
        if well_formed(entry):
            by_path[entry["path"]] = entry
    chosen = [e for e in by_path.values() if pack_for(e["path"]) in packs]
    chosen.sort(key=lambda e: e["path"])
    os.makedirs(out, exist_ok=True)
    total = 0
    for entry in chosen:
        encoded = "/".join(urllib.parse.quote(part) for part in entry["path"].split("/"))
        data = None
        for _ in range(2):
            try:
                data = read_url(base + encoded, entry["bytes"], opener)
            except Exception as error:  # a network error: try once more
                log(f"retrying {entry['path']}: {error}")
                continue
            if len(data) == entry["bytes"] and hashlib.sha256(data).hexdigest() == entry["sha256"]:
                break
            data = None
        if data is None:
            raise SystemExit(f"{entry['path']} did not download or does not match the manifest")
        destination = os.path.join(out, *entry["path"].split("/"))
        os.makedirs(os.path.dirname(destination), exist_ok=True)
        with open(destination, "wb") as handle:
            handle.write(data)
        total += len(data)
    subset = {"version": raw.get("version", ""), "about": "Build seed: " + ", ".join(packs) + " pack", "count": len(chosen),
              "files": [{k: e[k] for k in ("path", "bytes", "sha256") if k in e} | ({"feature": e["feature"]} if e.get("feature") else {})
                        for e in chosen]}
    with open(os.path.join(out, "manifest.json"), "w", encoding="utf-8") as handle:
        json.dump(subset, handle, indent=1, sort_keys=True)
    log(f"seed: {len(chosen)} files, {total} bytes, manifest {subset['version']}")
    return chosen


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--site", default="https://promptugal.news/")
    parser.add_argument("--out", default="Apps/PrompTugal/Seed/promptugal.news")
    parser.add_argument("--pack", action="append", default=None, help="core (default), full or media; repeatable")
    args = parser.parse_args(argv[1:])
    fetch_seed(args.site, args.out, tuple(args.pack or ["core"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
