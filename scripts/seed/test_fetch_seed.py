"""Tests for fetch_seed.py: a local site, verification, safe paths, and agreement with the Swift pack rules."""
import hashlib
import http.server
import json
import os
import re
import sys
import tempfile
import threading
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fetch_seed  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def entry(path, content):
    data = content.encode()
    return {"path": path, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(), "schema": None, "feature": "api"}


class Site:
    """A site on localhost: files by path, a manifest built from them, and files that can be served wrong."""

    def __init__(self, files, corrupt=()):
        self.files = files
        self.corrupt = set(corrupt)
        self.requests = []
        site = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                path = self.path.lstrip("/")
                site.requests.append(path)
                if path == "api/v1/manifest.json":
                    body = json.dumps({"version": "v7", "files": site.manifest_entries}).encode()
                elif path in site.files:
                    body = site.files[path].encode()
                    if path in site.corrupt:
                        body = b"X" * len(body)
                else:
                    self.send_response(404)
                    self.end_headers()
                    return
                self.send_response(200)
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *args):
                pass

        self.manifest_entries = [entry(p, c) for p, c in files.items()]
        self.server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.url = f"http://127.0.0.1:{self.server.server_address[1]}/"

    def close(self):
        self.server.shutdown()
        self.server.server_close()


class FetchSeedTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.out = os.path.join(self.tmp.name, "seed")

    def tearDown(self):
        self.tmp.cleanup()

    def test_core_files_only_verified_with_their_own_manifest(self):
        site = Site({"api/v1/days.json": "days", "api/v1/live/agenda.json": "agenda", "api/v1/graph/whole.json": "graph",
                     "sw.js": "worker"})
        self.addCleanup(site.close)
        chosen = fetch_seed.fetch_seed(site.url, self.out, allow_http=True, log=lambda *_: None)
        self.assertEqual([e["path"] for e in chosen], ["api/v1/days.json", "api/v1/live/agenda.json"])
        with open(os.path.join(self.out, "api/v1/live/agenda.json")) as handle:
            self.assertEqual(handle.read(), "agenda")
        self.assertFalse(os.path.exists(os.path.join(self.out, "api/v1/graph/whole.json")))
        self.assertNotIn("api/v1/graph/whole.json", site.requests)
        self.assertNotIn("sw.js", site.requests)
        with open(os.path.join(self.out, "manifest.json")) as handle:
            seed_manifest = json.load(handle)
        self.assertEqual(seed_manifest["version"], "v7")
        self.assertEqual([f["path"] for f in seed_manifest["files"]], ["api/v1/days.json", "api/v1/live/agenda.json"])
        for f in seed_manifest["files"]:
            self.assertEqual(len(f["sha256"]), 64)

    def test_full_pack_on_request(self):
        site = Site({"api/v1/days.json": "days", "api/v1/graph/whole.json": "graph"})
        self.addCleanup(site.close)
        chosen = fetch_seed.fetch_seed(site.url, self.out, packs=("core", "full"), allow_http=True, log=lambda *_: None)
        self.assertEqual(len(chosen), 2)

    def test_a_file_that_does_not_match_fails_the_build(self):
        site = Site({"api/v1/days.json": "days"}, corrupt=["api/v1/days.json"])
        self.addCleanup(site.close)
        with self.assertRaises(SystemExit):
            fetch_seed.fetch_seed(site.url, self.out, allow_http=True, log=lambda *_: None)
        self.assertEqual(site.requests.count("api/v1/days.json"), 2, "tried twice")
        self.assertFalse(os.path.exists(os.path.join(self.out, "manifest.json")), "no manifest for a failed seed")

    def test_unsafe_and_malformed_entries_are_ignored(self):
        site = Site({"api/v1/days.json": "days"})
        self.addCleanup(site.close)
        good = site.manifest_entries[0]
        site.manifest_entries = [good,
                                 {"path": "../escape.json", "bytes": 1, "sha256": "a" * 64},
                                 {"path": "api/v1/live/x.json", "bytes": 1, "sha256": "A" * 64},
                                 {"path": "api/v1/live/y.json", "bytes": "1", "sha256": "a" * 64},
                                 {"path": "/abs.json", "bytes": 1, "sha256": "a" * 64}]
        chosen = fetch_seed.fetch_seed(site.url, self.out, allow_http=True, log=lambda *_: None)
        self.assertEqual([e["path"] for e in chosen], ["api/v1/days.json"])
        self.assertFalse(any("escape" in r or "abs" in r for r in site.requests))

    def test_http_is_refused_by_default(self):
        with self.assertRaises(ValueError):
            fetch_seed.fetch_seed("http://example.test/", self.out)

    def test_safe_path_table(self):
        for path in ["api/v1/days.json", "a.json", "dir/with space/x.json"]:
            self.assertTrue(fetch_seed.is_safe_path(path), path)
        for path in ["", "/abs", "../x", "a/../b", "a//b", "a/", "a\\b", "https://x/y", "a?b", "a#b", "a%2eb", "a\x00b", "x" * 600]:
            self.assertFalse(fetch_seed.is_safe_path(path), path)

    def test_pack_rules_agree_with_the_swift_rules(self):
        with open(os.path.join(ROOT, "Packages/PTSync/Sources/PTSync/Manifest.swift"), encoding="utf-8") as handle:
            source = handle.read()
        block = source[source.index("public static let promptugalNews = PackRules("):]
        block = block[:block.index("fallback:")]
        swift_rules = [(prefix, None if pack == "nil" else pack.lstrip("."))
                       for prefix, pack in re.findall(r'Rule\("([^"]+)",\s*(nil|\.core|\.full|\.media)\)', block)]
        self.assertEqual(swift_rules, fetch_seed.RULES)
        self.assertIn("fallback: .full", source)
        self.assertEqual(fetch_seed.FALLBACK, "full")


if __name__ == "__main__":
    unittest.main()
