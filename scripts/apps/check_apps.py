#!/usr/bin/env python3
"""Check apps.json against the projects and the packages. Standard library only.

Fails when:
  - a project's local package references differ from its app's package closure;
  - a package's Package.swift dependencies differ from its `deps` in apps.json;
  - the package graph has a cycle.
Usage: check_apps.py [repo-root]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import apps_lib  # noqa: E402


def check(root):
    config = apps_lib.load(root)
    errors = []

    cycle = apps_lib.find_cycle(config)
    if cycle:
        errors.append("cycle in package graph: " + " -> ".join(cycle))

    for name, pkg in sorted(config["packages"].items()):
        manifest = os.path.join(root, pkg["path"], "Package.swift")
        if not os.path.isfile(manifest):
            errors.append(f"{name}: {pkg['path']}/Package.swift is missing")
            continue
        with open(manifest, encoding="utf-8") as f:
            actual = apps_lib.package_swift_deps(f.read())
        if actual != sorted(pkg["deps"]):
            errors.append(f"{name}: Package.swift depends on {actual}, apps.json says {sorted(pkg['deps'])}")
        for dep in pkg["deps"]:
            if dep not in config["packages"]:
                errors.append(f"{name}: dep {dep} is not in apps.json packages")

    for app, entry in sorted(config["apps"].items()):
        for pkg in entry.get("packages", []):
            if pkg not in config["packages"]:
                errors.append(f"app {app}: package {pkg} is not in apps.json packages")
        project = os.path.join(root, entry["project"], "project.pbxproj")
        if not os.path.isfile(project):
            errors.append(f"app {app}: {entry['project']} is missing")
            continue
        with open(project, encoding="utf-8") as f:
            actual = apps_lib.project_package_refs(f.read())
        expected = apps_lib.app_closure(config, app)
        if actual != expected:
            errors.append(
                f"app {app}: {entry['project']} references {sorted(actual)}; "
                f"closure in apps.json is {sorted(expected)} "
                f"(missing {sorted(expected - actual)}, extra {sorted(actual - expected)})"
            )
    return errors


def main(argv):
    root = os.path.abspath(argv[1]) if len(argv) > 1 else apps_lib.ROOT
    errors = check(root)
    for e in errors:
        print("ERROR:", e)
    if errors:
        return 1
    print("apps.json OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
