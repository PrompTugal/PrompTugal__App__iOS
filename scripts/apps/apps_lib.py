"""Shared helpers for check_apps.py and affected.py. Standard library only."""
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def load(root=ROOT):
    with open(os.path.join(root, "apps.json"), encoding="utf-8") as f:
        return json.load(f)


def closure(config, direct):
    """Direct package names plus everything they depend on, through `deps`."""
    seen = set()
    todo = list(direct)
    while todo:
        name = todo.pop()
        if name in seen:
            continue
        seen.add(name)
        todo.extend(config["packages"].get(name, {}).get("deps", []))
    return seen


def app_closure(config, app):
    return closure(config, config["apps"][app].get("packages", []))


def find_cycle(config):
    """Return a list of package names forming a cycle, or None."""
    state = {}
    stack = []

    def visit(name):
        state[name] = 1
        stack.append(name)
        for dep in config["packages"].get(name, {}).get("deps", []):
            if state.get(dep) == 1:
                return stack[stack.index(dep):] + [dep]
            if state.get(dep) is None:
                found = visit(dep)
                if found:
                    return found
        stack.pop()
        state[name] = 2
        return None

    for name in config["packages"]:
        if state.get(name) is None:
            found = visit(name)
            if found:
                return found
    return None


def package_swift_deps(text):
    """Names of local package dependencies: .package(path: "../Name")."""
    return sorted(set(re.findall(r'\.package\(\s*path:\s*"(?:\.\./)+([^"/]+)"', text)))


def project_package_refs(pbxproj_text):
    """Directory names of every XCLocalSwiftPackageReference in a project file."""
    refs = set()
    for block in re.finditer(r"isa = XCLocalSwiftPackageReference;(.*?)\};", pbxproj_text, re.S):
        m = re.search(r"relativePath = ([^;]+);", block.group(1))
        if m:
            refs.add(os.path.basename(m.group(1).strip().strip('"').rstrip("/")))
    return refs
