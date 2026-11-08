#!/usr/bin/env python3
"""Plan a CI run for the apps in this repository (contracts section 4 and 5).

  apps.py plan          reads the event from the environment, writes outputs
  apps.py --self-test   checks the rules below without git or GitHub

What it decides:
  apps      apps to build and test: affected by the change, project exists
  upload    apps to sign and upload to TestFlight (release workflow only)
  packages  Swift packages to test: affected, and they have a Tests/ folder

Config is apps.json. If the file is missing (before the split lands), a built-in
config describes today's single app: the root project, bundle news.promptugal.reader.

Affected rules (contracts section 4): a changed file triggers an app when it is
under one of the app's `paths`, or under the `path` of a package in the app's
closure; a file under `all` triggers every app. If scripts/apps/affected.py
exists (platform writes it), it is used for the diff-based part and this file
only falls back to its own copy of the rules when that script fails.

Environment for `plan` (all optional except SHA):
  EVENT_NAME REF SHA BEFORE BASE_SHA        from the github context
  INPUT_APP INPUT_UPLOAD INPUT_DRY_RUN      workflow_dispatch inputs
  VARS_JSON                                 toJSON(vars): pause switches and build offsets
Outputs go to $GITHUB_OUTPUT and the table to $GITHUB_STEP_SUMMARY.
"""
import json
import os
import re
import subprocess
import sys

LEGACY_BUNDLE = "news.promptugal.reader"   # what `ios-v*` tags and the single app mean today
DEFAULT_OFFSET = 100                        # run number + 100, as before the split
ZERO = "0" * 40

DEFAULT_CONFIG = {
    "packages": {"SGitVault": {"path": "Packages/SGitVault", "deps": []}},
    "apps": {
        "team": {
            "project": "PrompTugal.xcodeproj", "scheme": "PrompTugal", "bundle": LEGACY_BUNDLE,
            "paths": ["."], "packages": ["SGitVault"], "testflight": True,
        }
    },
    "all": [".github/workflows/ios.yml", ".github/workflows/ios-release.yml",
            ".github/workflows/ios-changes.yml", ".github/scripts/", "apps.json", "scripts/release/"],
}


def sh(*args):
    try:
        return subprocess.run(args, capture_output=True, text=True)
    except FileNotFoundError:   # e.g. no gh on this machine
        return subprocess.CompletedProcess(args, 127, "", f"{args[0]}: not found")


def load_config(root="."):
    path = os.path.join(root, "apps.json")
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f), "apps.json"
    return DEFAULT_CONFIG, "built-in single-app config (no apps.json on this ref)"


def under(path, prefix):
    if prefix in (".", "./", ""):
        return True
    prefix = prefix.rstrip("/")
    return path == prefix or path.startswith(prefix + "/")


def closure(cfg, names):
    """Direct package names -> all names they depend on, themselves included."""
    seen, todo = set(), list(names)
    pk = cfg.get("packages", {})
    while todo:
        n = todo.pop()
        if n in seen or n not in pk:
            continue
        seen.add(n)
        todo.extend(pk[n].get("deps", []))
    return seen


def affected_by_files(cfg, files):
    """The rules of contracts section 4. files=None means everything changed."""
    apps = cfg.get("apps", {})
    if files is None:
        return set(apps)
    if any(under(f, a) for f in files for a in cfg.get("all", [])):
        return set(apps)
    out = set()
    for key, app in apps.items():
        dirs = list(app.get("paths", []))
        dirs += [cfg["packages"][p]["path"] for p in closure(cfg, app.get("packages", []))]
        if any(under(f, d) for f in files for d in dirs):
            out.add(key)
    return out


def affected_packages(cfg, files):
    pk = cfg.get("packages", {})
    if files is None or any(under(f, a) for f in files for a in cfg.get("all", [])):
        return set(pk)
    out = set()
    for name in pk:
        dirs = [pk[p]["path"] for p in closure(cfg, [name])]
        if any(under(f, d) for f in files for d in dirs):
            out.add(name)
    return out


def tag_app(cfg, ref):
    """refs/tags/team-v1.2 -> team. The old ios-v* tags mean the app with the legacy bundle."""
    m = re.match(r"refs/tags/([a-z0-9]+)-v", ref)
    if not m:
        return None
    word = m.group(1)
    if word == "ios":
        for key, app in cfg["apps"].items():
            if app.get("bundle") == LEGACY_BUNDLE:
                return key
        return None
    return word


def diff_range(env):
    """(base, head) revisions to compare, or None when the whole tree should count."""
    ev, sha, ref = env.get("EVENT_NAME", ""), env.get("SHA", "HEAD"), env.get("REF", "")

    def merge_base():
        sh("git", "fetch", "--quiet", "origin", "dev")
        r = sh("git", "merge-base", "origin/dev", sha)
        return r.stdout.strip() if r.returncode == 0 and r.stdout.strip() else None

    if ev == "push" and ref in ("refs/heads/dev", "refs/heads/main"):
        before = env.get("BEFORE", "")
        if before and before != ZERO and sh("git", "cat-file", "-e", before + "^{commit}").returncode == 0:
            return before, sha
        return None
    if ev in ("push", "pull_request"):
        base = merge_base()
        return (base, sha) if base else None
    return None


IGNORED_DIRS = ("briefs/", "website/")


def relevant(files):
    """Docs, the site and VERSION cannot change an app. (ios.yml's path filters say the same.)"""
    return [f for f in files if not f.startswith(IGNORED_DIRS) and f != "VERSION" and not ("/" not in f and f.endswith(".md"))]


def files_between(base, head):
    r = sh("git", "diff", "--name-only", base, head)
    return relevant(r.stdout.split()) if r.returncode == 0 else None


PLATFORM = {"packages": None}   # packages from scripts/apps/affected.py, when it gave them


def platform_affected(files):
    """Ask scripts/apps/affected.py. Returns a set of app keys, or None if unusable."""
    script = "scripts/apps/affected.py"
    if files is None or not os.path.exists(script):
        return None
    import tempfile
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f:
        f.write("\n".join(files) + "\n")
    try:
        r = sh(sys.executable, script, "--files-from", f.name)
    finally:
        os.unlink(f.name)
    if r.returncode != 0:
        print(f"{script} failed ({r.returncode}); using the fallback rules. {r.stderr.strip()[:300]}", file=sys.stderr)
        return None
    try:
        data = json.loads(r.stdout)
    except ValueError:
        return None
    if isinstance(data, dict):
        PLATFORM["packages"] = data.get("packages")
        data = data.get("apps", [k for k, v in data.items() if v])
    if isinstance(data, list):
        return {x if isinstance(x, str) else x.get("app") or x.get("key") for x in data}
    return None


def find_release(head_sha):
    """The release commit and tag that website.yml made for a push: a v* tag whose commit's
    parent is the pushed commit. Returns (tag, sha) or (None, None)."""
    r = sh("git", "tag", "--list", "v[0-9]*", "--sort=-version:refname")
    for tag in r.stdout.split()[:40]:
        c = sh("git", "rev-parse", tag + "^{commit}").stdout.strip()
        p = sh("git", "rev-parse", c + "^").stdout.strip()
        if c and p == head_sha:
            return tag, c
    return None, None


def last_built(key, legacy, limit=15):
    """The commit an app was last built from: the build-info of the newest ios-release run on dev
    that has one for it (written only when its unsigned package succeeded). None if there is none,
    or gh is not usable; then the app counts as changed."""
    import tempfile
    names = [f"build-info-{key}"] + (["build-info"] if legacy else [])
    r = sh("gh", "run", "list", "--workflow", "ios-release.yml", "--branch", "dev", "--limit", str(limit),
           "--json", "databaseId", "-q", ".[].databaseId")
    for run in r.stdout.split():
        for name in names:
            with tempfile.TemporaryDirectory() as d:
                if sh("gh", "run", "download", run, "-n", name, "-D", d).returncode == 0:
                    try:
                        commit = json.load(open(os.path.join(d, "build-info.json"))).get("commit", "")
                    except (OSError, ValueError):
                        continue
                    if commit and sh("git", "cat-file", "-e", commit + "^{commit}").returncode == 0:
                        return commit
    return None


def offset_for(key, variables):
    for name in (f"IOS_BUILD_OFFSET_{key.upper()}", "IOS_BUILD_OFFSET"):
        v = str(variables.get(name, "")).strip()
        if v.isdigit():
            return int(v)
    return DEFAULT_OFFSET


def paused(key, variables):
    return (str(variables.get("TESTFLIGHT_ON_PUSH", "")).strip().lower() == "false"
            or str(variables.get(f"TESTFLIGHT_ON_PUSH_{key.upper()}", "")).strip().lower() == "false")


def plan(cfg, env, files, platform_set, exists, variables):
    """Pure decision. Returns (rows, packages, notes). rows have keys:
    app, build, upload, why (list of reasons shown in the summary)."""
    ev, ref = env.get("EVENT_NAME", ""), env.get("REF", "")
    want = (env.get("INPUT_APP") or "all").strip().lower()
    manual_upload = env.get("INPUT_UPLOAD") == "true" or env.get("INPUT_DRY_RUN") == "true"
    tag_key = tag_app(cfg, ref) if ref.startswith("refs/tags/") else None
    notes = []
    apps = cfg["apps"]

    if ref.startswith("refs/tags/"):
        if tag_key is None or tag_key not in apps:
            notes.append(f"tag `{ref.split('/', 2)[-1]}` names no app in apps.json; nothing to do")
        selected = {tag_key} if tag_key in apps else set()
        mode = "tag"
    elif ev == "workflow_dispatch":
        if want != "all" and want not in apps:
            notes.append(f"input app `{want}` is not in apps.json ({', '.join(apps)}); nothing to do")
        selected = set(apps) if want == "all" else ({want} & set(apps))
        mode = "manual"
    else:
        selected = platform_set if platform_set is not None else affected_by_files(cfg, files)
        mode = "diff"

    rows = []
    for key in apps:
        app = apps[key]
        row = {"app": key, "build": False, "upload": False, "why": []}
        rows.append(row)
        if key not in selected:
            row["why"].append("not affected by this change")
            continue
        if not exists(app["project"]):
            row["why"].append(f"skipped: `{app['project']}` does not exist yet")
            continue
        row["build"] = True
        row["why"].append({"tag": "tag", "manual": "manual run"}.get(mode, "affected by the change"))
        # TestFlight
        tf = app.get("testflight", False)
        if mode == "diff":
            if ev == "workflow_run" or (ev == "push" and ref == "refs/heads/dev"):
                if not tf:
                    row["why"].append("no upload: testflight is false in apps.json")
                elif paused(key, variables):
                    row["why"].append(f"no upload: paused (TESTFLIGHT_ON_PUSH or TESTFLIGHT_ON_PUSH_{key.upper()} is false)")
                else:
                    row["upload"] = True
            else:
                row["why"].append("no upload: only pushes to dev, tags and manual runs upload")
        elif mode == "tag":
            if tf:
                row["upload"] = True
            else:
                row["why"].append("no upload: testflight is false in apps.json")
        else:  # manual
            if manual_upload:
                if tf:
                    row["upload"] = True
                else:
                    row["why"].append("no upload: testflight is false in apps.json")
    # Packages: test the ones the change touches (only those that exist and have tests).
    pk = cfg.get("packages", {})
    pkgs = []
    chosen = set(pk) if mode != "diff" else affected_packages(cfg, files)
    if mode == "diff" and PLATFORM["packages"] is not None:
        chosen = set(PLATFORM["packages"]) & set(pk)
    for name in sorted(chosen):
        pkgs.append({"name": name, "path": pk[name]["path"]})
    return rows, pkgs, notes


def matrix_entry(key, app, variables, base=""):
    return {
        "base": base or "",   # the commit this app was last built from; release notes start there
        "app": key, "secret": key.upper(), "project": app["project"], "scheme": app["scheme"],
        "name": app["scheme"], "bundle": app["bundle"], "offset": offset_for(key, variables),
        # profile secrets: IOS_PROFILE_<KEY>_APP_BASE64 ...; the old IOS_PROFILE_APP_BASE64 names
        # belong to the app that owns the legacy bundle, and to nobody else.
        "legacy": app["bundle"] == LEGACY_BUNDLE,
    }


def screens_entry(key, app, entry):
    """The screenshot job of an app, or None when the app has no shared screens scheme.
    Optional apps.json keys: screensScheme (default <scheme>Screens) and screensCount
    (how many PNGs one device must produce; 0 = just at least one)."""
    scheme = app.get("screensScheme") or app["scheme"] + "Screens"
    shared = os.path.join(app["project"], "xcshareddata", "xcschemes", scheme + ".xcscheme")
    if not os.path.exists(shared):
        return None
    count = app.get("screensCount", 13 if entry["legacy"] else 0)
    # The app that owns the old bundle keeps the old artifact name, screens-<sha>, which the
    # site reads; the others get screens-<sha>-<app>.
    return dict(entry, screens_scheme=scheme, screens_count=count, suffix="" if entry["legacy"] else "-" + key)


def write_output(name, value):
    path = os.environ.get("GITHUB_OUTPUT")
    line = f"{name}={value}"
    if path:
        with open(path, "a") as f:
            f.write(line + "\n")
    else:
        print(line)


def main_plan():
    env = {k: os.environ.get(k, "") for k in
           ("EVENT_NAME", "REF", "SHA", "BEFORE", "BASE_SHA", "INPUT_APP", "INPUT_UPLOAD", "INPUT_DRY_RUN", "RUN_HEAD_SHA")}
    try:
        variables = json.loads(os.environ.get("VARS_JSON") or "{}")
    except ValueError:
        variables = {}
    cfg, source = load_config()
    lines = [f"Config: {source}."]
    files, platform_set, how = None, None, "whole tree (no diff for this event)"
    release_tag, release_sha, bases = "", "", {}
    if env["EVENT_NAME"] == "workflow_run":
        # website.yml finished for a push to dev. Build the release commit it made, and for each
        # app compare with the commit that app was last built from, so a run that was skipped
        # or replaced never loses an app's changes.
        release_tag, release_sha = find_release(env["RUN_HEAD_SHA"])
        if not release_sha:
            lines.append(f"No release tag found for pushed commit `{env['RUN_HEAD_SHA'][:7]}`; nothing to build.")
            cfg = dict(cfg, apps={})
            how = "no release"
        else:
            selected, parts = set(), []
            for key, app in cfg["apps"].items():
                base = last_built(key, app["bundle"] == LEGACY_BUNDLE)
                bases[key] = base
                changed = files_between(base, release_sha) if base else None
                aff = platform_affected(changed) if changed is not None else None
                aff = aff if aff is not None else affected_by_files(cfg, changed)
                if key in aff:
                    selected.add(key)
                parts.append(f"`{key}` since " + (f"`{base[:7]}` ({len(changed)} files)" if base else "never built"))
            platform_set = selected
            files = []
            how = f"release `{release_tag}` (`{release_sha[:7]}`): " + "; ".join(parts)
    else:
        rng = diff_range(env)
        if rng:
            base, head = rng
            files = files_between(base, head)
            platform_set = platform_affected(files)
            how = f"`{base[:7]}..{head[:7]}`, {len(files) if files is not None else '?'} changed files" + \
                  (" (scripts/apps/affected.py)" if platform_set is not None else "")
    lines.append(f"Compared: {how}.")

    exists = os.path.exists
    rows, pkgs, notes = plan(cfg, env, files, platform_set, exists, variables)
    apps = cfg["apps"]
    build = [matrix_entry(r["app"], apps[r["app"]], variables, bases.get(r["app"])) for r in rows if r["build"]]
    upload = [matrix_entry(r["app"], apps[r["app"]], variables, bases.get(r["app"])) for r in rows if r["upload"]]
    screens, no_screens = [], []
    for e in build:
        se = screens_entry(e["app"], apps[e["app"]], e)
        (screens if se else no_screens).append(se or e["app"])
    # Only packages that exist here and have tests take a macOS runner.
    runnable, idle = [], []
    for p in pkgs:
        if not os.path.exists(os.path.join(p["path"], "Package.swift")):
            idle.append(f"`{p['name']}`: no Package.swift yet")
        elif not os.path.isdir(os.path.join(p["path"], "Tests")):
            idle.append(f"`{p['name']}`: no Tests/ folder")
        else:
            runnable.append(p)

    out = ["## Affected apps and packages", "", *lines, "",
           "| App | Project | Build and test | TestFlight | Why |", "| --- | --- | --- | --- | --- |"]
    for r in rows:
        a = apps[r["app"]]
        out.append(f"| `{r['app']}` | `{a['project']}` | {'yes' if r['build'] else 'no'} | "
                   f"{'yes' if r['upload'] else 'no'} | {'; '.join(r['why'])} |")
    out += ["", "Packages to test: " + (", ".join(f"`{p['name']}`" for p in runnable) or "none")]
    out += ["Screenshots for: " + (", ".join(f"`{e['app']}`" for e in screens) or "none")]
    out += [f"- ⏭️ `{a}`: no shared screens scheme in its project" for a in no_screens]
    out += [f"- ⏭️ {i}" for i in idle]
    out += [f"- ⚠️ {n}" for n in notes]
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    text = "\n".join(out) + "\n"
    if summary:
        with open(summary, "a") as f:
            f.write(text)
    print(text)

    write_output("ref", release_sha)          # commit to check out and build (empty: the default)
    write_output("tag", release_tag)
    write_output("apps", json.dumps(build, separators=(",", ":")))
    write_output("has_apps", "true" if build else "false")
    write_output("upload", json.dumps(upload, separators=(",", ":")))
    write_output("has_upload", "true" if upload else "false")
    write_output("screens", json.dumps(screens, separators=(",", ":")))
    write_output("has_screens", "true" if screens else "false")
    write_output("packages", json.dumps(runnable, separators=(",", ":")))
    write_output("has_packages", "true" if runnable else "false")


def self_test():
    cfg = {
        "packages": {
            "PTCore": {"path": "Packages/PTCore", "deps": []},
            "PTWeb": {"path": "Packages/PTWeb", "deps": ["PTCore"]},
            "PTAgenda": {"path": "Packages/PTAgenda", "deps": ["PTCore", "PTWeb"]},
            "PTLanes": {"path": "Packages/PTLanes", "deps": ["PTCore"]},
        },
        "apps": {
            "team": {"project": "Apps/Team/Team.xcodeproj", "scheme": "Team", "bundle": "news.promptugal.team",
                     "paths": ["Apps/Team/"], "packages": ["PTLanes", "PTAgenda"], "testflight": True},
            "promptugal": {"project": "Apps/PrompTugal/PrompTugal.xcodeproj", "scheme": "PrompTugal",
                           "bundle": LEGACY_BUNDLE, "paths": ["Apps/PrompTugal/"], "packages": ["PTAgenda"], "testflight": True},
            "riskmandate": {"project": "Apps/RiskMandate/RiskMandate.xcodeproj", "scheme": "RiskMandate",
                            "bundle": "ai.riskmandate.app", "paths": ["Apps/RiskMandate/"], "packages": ["PTCore"], "testflight": False},
        },
        "all": ["apps.json", "scripts/release/"],
    }
    ok = True

    def check(name, got, want):
        nonlocal ok
        if got != want:
            ok = False
            print(f"FAIL {name}: got {got!r}, want {want!r}")

    check("riskmandate only", affected_by_files(cfg, ["Apps/RiskMandate/App.swift"]), {"riskmandate"})
    check("lanes: team only", affected_by_files(cfg, ["Packages/PTLanes/x.swift"]), {"team"})
    check("agenda: team + promptugal", affected_by_files(cfg, ["Packages/PTAgenda/x.swift"]), {"team", "promptugal"})
    check("core: everyone", affected_by_files(cfg, ["Packages/PTCore/x.swift"]), {"team", "promptugal", "riskmandate"})
    check("web (via agenda)", affected_by_files(cfg, ["Packages/PTWeb/x.swift"]), {"team", "promptugal"})
    check("all-list file", affected_by_files(cfg, ["scripts/release/lib.sh"]), {"team", "promptugal", "riskmandate"})
    check("nothing", affected_by_files(cfg, ["README.txt"]), set())
    check("unknown diff = all", affected_by_files(cfg, None), {"team", "promptugal", "riskmandate"})
    check("pkg: lanes", affected_packages(cfg, ["Packages/PTLanes/a"]), {"PTLanes"})
    check("pkg: web hits agenda", affected_packages(cfg, ["Packages/PTWeb/a"]), {"PTWeb", "PTAgenda"})
    check("tag team", tag_app(cfg, "refs/tags/team-v1.0.0"), "team")
    check("tag legacy ios-v", tag_app(cfg, "refs/tags/ios-v0.3.1"), "promptugal")
    check("tag not a tag", tag_app(cfg, "refs/heads/dev"), None)
    check("default config legacy tag", tag_app(DEFAULT_CONFIG, "refs/tags/ios-v1"), "team")
    check("offset default", offset_for("team", {}), 100)
    check("offset global", offset_for("team", {"IOS_BUILD_OFFSET": "200"}), 200)
    check("offset per app", offset_for("team", {"IOS_BUILD_OFFSET": "200", "IOS_BUILD_OFFSET_TEAM": "300"}), 300)
    check("paused global", paused("team", {"TESTFLIGHT_ON_PUSH": "false"}), True)
    check("paused app", paused("team", {"TESTFLIGHT_ON_PUSH_TEAM": "false"}), True)
    check("not paused other app", paused("promptugal", {"TESTFLIGHT_ON_PUSH_TEAM": "false"}), False)

    exists = lambda p: p != "Apps/RiskMandate/RiskMandate.xcodeproj"
    push_dev = {"EVENT_NAME": "push", "REF": "refs/heads/dev"}
    rows, _, _ = plan(cfg, push_dev, ["Packages/PTCore/x"], None, exists, {"TESTFLIGHT_ON_PUSH_TEAM": "false"})
    got = {r["app"]: (r["build"], r["upload"]) for r in rows}
    check("dev push: team paused, promptugal uploads, riskmandate missing",
          got, {"team": (True, False), "promptugal": (True, True), "riskmandate": (False, False)})
    rows, _, _ = plan(cfg, {"EVENT_NAME": "push", "REF": "refs/heads/split/x"}, ["Packages/PTCore/x"], None, exists, {})
    check("branch push never uploads", [r["upload"] for r in rows], [False, False, False])
    rows, _, _ = plan(cfg, {"EVENT_NAME": "workflow_dispatch", "REF": "refs/heads/x", "INPUT_APP": "promptugal", "INPUT_UPLOAD": "true"},
                      None, None, exists, {"TESTFLIGHT_ON_PUSH": "false"})
    check("manual: one app, upload despite push pause", {r["app"]: (r["build"], r["upload"]) for r in rows},
          {"team": (False, False), "promptugal": (True, True), "riskmandate": (False, False)})
    rows, _, _ = plan(cfg, {"EVENT_NAME": "push", "REF": "refs/tags/riskmandate-v0.0.1"}, None, None, lambda p: True, {})
    check("tag riskmandate: builds, no upload (testflight false)", {r["app"]: (r["build"], r["upload"]) for r in rows},
          {"team": (False, False), "promptugal": (False, False), "riskmandate": (True, False)})
    rows, pk, _ = plan(DEFAULT_CONFIG, push_dev, ["PrompTugal/Foo.swift"], None, os.path.exists if False else (lambda p: True), {})
    check("single app config builds on any change", [(r["app"], r["build"], r["upload"]) for r in rows], [("team", True, True)])
    entry = matrix_entry("promptugal", cfg["apps"]["promptugal"], {})
    check("legacy profile names go to the reader app", entry["legacy"], True)
    check("team is not legacy", matrix_entry("team", cfg["apps"]["team"], {})["legacy"], False)
    check("docs and site are not app changes", relevant(["briefs/a.md", "website/x.py", "VERSION", "README.md", "PrompTugal/A.swift", "docs/x.md"]),
          ["PrompTugal/A.swift", "docs/x.md"])
    rows, _, _ = plan(cfg, {"EVENT_NAME": "workflow_run", "REF": "refs/heads/main"}, [], {"promptugal"}, exists, {"TESTFLIGHT_ON_PUSH_PROMPTUGAL": "false"})
    check("release run: affected + paused -> builds, no upload", {r["app"]: (r["build"], r["upload"]) for r in rows},
          {"team": (False, False), "promptugal": (True, False), "riskmandate": (False, False)})
    rows, _, _ = plan(cfg, {"EVENT_NAME": "workflow_run", "REF": "refs/heads/main"}, [], {"team", "riskmandate"}, exists, {})
    check("release run uploads like a dev push", {r["app"]: (r["build"], r["upload"]) for r in rows},
          {"team": (True, True), "promptugal": (False, False), "riskmandate": (False, False)})
    print("self-test:", "ok" if ok else "FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        sys.exit(self_test())
    if len(sys.argv) > 1 and sys.argv[1] == "plan":
        main_plan()
        sys.exit(0)
    print(__doc__)
    sys.exit(2)
