import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import apps_lib  # noqa: E402
import affected  # noqa: E402
import check_apps  # noqa: E402

CFG = {
    "packages": {
        "A": {"path": "Packages/A", "deps": []},
        "B": {"path": "Packages/B", "deps": ["A"]},
        "C": {"path": "Packages/C", "deps": ["B"]},
    },
    "apps": {
        "one": {"paths": ["Apps/One/"], "packages": ["C"]},
        "two": {"paths": ["Apps/Two/"], "packages": ["A"]},
    },
    "all": ["apps.json", "scripts/release/"],
}


class Graph(unittest.TestCase):
    def test_closure(self):
        self.assertEqual(apps_lib.app_closure(CFG, "one"), {"A", "B", "C"})
        self.assertEqual(apps_lib.app_closure(CFG, "two"), {"A"})

    def test_cycle(self):
        self.assertIsNone(apps_lib.find_cycle(CFG))
        bad = {"packages": {"A": {"deps": ["B"]}, "B": {"deps": ["A"]}}}
        self.assertIsNotNone(apps_lib.find_cycle(bad))

    def test_parsers(self):
        self.assertEqual(apps_lib.package_swift_deps('.package(path: "../PTCore"),\n .package(path: "../X")'), ["PTCore", "X"])
        pbx = 'x = {\n isa = XCLocalSwiftPackageReference;\n relativePath = Packages/PTCore;\n };'
        self.assertEqual(apps_lib.project_package_refs(pbx), {"PTCore"})


class Affected(unittest.TestCase):
    def test_app_path(self):
        self.assertEqual(affected.affected(CFG, ["Apps/Two/x.swift"])["apps"], ["two"])

    def test_package_reaches_dependents(self):
        r = affected.affected(CFG, ["Packages/B/Sources/b.swift"])
        self.assertEqual(r["apps"], ["one"])
        self.assertEqual(r["packages"], ["B", "C"])

    def test_core_package_hits_both(self):
        self.assertEqual(affected.affected(CFG, ["Packages/A/a.swift"])["apps"], ["one", "two"])

    def test_all(self):
        self.assertEqual(affected.affected(CFG, ["apps.json"])["apps"], ["one", "two"])

    def test_unrelated(self):
        r = affected.affected(CFG, ["website/index.html"])
        self.assertEqual(r, {"apps": [], "packages": []})

    def test_prefix_is_not_substring(self):
        self.assertEqual(affected.affected(CFG, ["Packages/AB/x"])["apps"], [])


class RealRepo(unittest.TestCase):
    def test_repo_is_consistent(self):
        self.assertEqual(check_apps.check(apps_lib.ROOT), [])


if __name__ == "__main__":
    unittest.main()
