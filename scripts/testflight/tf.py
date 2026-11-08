#!/usr/bin/env python3
"""TestFlight operations through the App Store Connect API (standard library + system openssl).

    tf.py status                                    builds, processing, beta review, groups, expiry
    tf.py add-to-group      --build 6 --group "PrompTugal External Users"   [--yes]
    tf.py remove-from-group --build 4 --group "PrompTugal External Users"   [--yes]
    tf.py set-test-info     --build 151 [--whats-new FILE] [--review-file FILE] [--yes]
    tf.py submit-beta-review --build 151 [--yes]
    tf.py expire            --build 4 [--yes]

Every action that changes App Store Connect only prints its plan unless --yes is given.
Environment: ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8_BASE64 (or ASC_KEY_PATH); BUNDLE_ID
(default news.promptugal.reader). Never prints the key, the token or the review credentials.

--build is the build number (CFBundleVersion), as in TestFlight. The request-building functions
(plan_*) return (method, path, body) tuples and do no network; tests/test_tf.py checks them.
"""
import argparse, base64, json, os, re, subprocess, sys, tempfile, time, urllib.error, urllib.request

API = "https://api.appstoreconnect.apple.com"
DEFAULT_BUNDLE = "news.promptugal.reader"
HERE = os.path.dirname(os.path.abspath(__file__))
PLACEHOLDER = re.compile(r"<([A-Z][A-Z0-9_]+)>")
REVIEW_FIELDS = ("contactFirstName", "contactLastName", "contactEmail", "contactPhone")


def say(msg=""):
    print(msg, flush=True)
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a") as f:
            f.write(msg + "\n")


def die(msg):
    print(f"::error::{msg}", flush=True)
    sys.exit(1)


# ---------------------------------------------------------------- request building (no network)

def ref(kind, ident):
    return {"type": kind, "id": ident}


def plan_add_to_group(group_id, build_id):
    return ("POST", f"/v1/betaGroups/{group_id}/relationships/builds", {"data": [ref("builds", build_id)]})


def plan_remove_from_group(group_id, build_id):
    return ("DELETE", f"/v1/betaGroups/{group_id}/relationships/builds", {"data": [ref("builds", build_id)]})


def plan_expire(build_id):
    return ("PATCH", f"/v1/builds/{build_id}",
            {"data": {"type": "builds", "id": build_id, "attributes": {"expired": True}}})


def plan_submit_beta_review(build_id):
    return ("POST", "/v1/betaAppReviewSubmissions",
            {"data": {"type": "betaAppReviewSubmissions",
                      "relationships": {"build": {"data": ref("builds", build_id)}}}})


def plan_whats_new(build_id, existing_loc_id, locale, text):
    text = text[:4000]
    if existing_loc_id:
        return ("PATCH", f"/v1/betaBuildLocalizations/{existing_loc_id}",
                {"data": {"type": "betaBuildLocalizations", "id": existing_loc_id, "attributes": {"whatsNew": text}}})
    return ("POST", "/v1/betaBuildLocalizations",
            {"data": {"type": "betaBuildLocalizations", "attributes": {"locale": locale, "whatsNew": text},
                      "relationships": {"build": {"data": ref("builds", build_id)}}}})


# Placeholders whose line is dropped from the notes when the value is not set.
OPTIONAL_PLACEHOLDERS = ("DEMO_VAULT_KEY", "DEMO_LANE_NAME")
# Contact details are personal and this repository is public: they come from secrets only.
CONTACT_ENV = {"contactFirstName": "REVIEW_CONTACT_FIRST_NAME", "contactLastName": "REVIEW_CONTACT_LAST_NAME",
               "contactEmail": "REVIEW_CONTACT_EMAIL", "contactPhone": "REVIEW_CONTACT_PHONE"}


def fill_placeholders(text, env):
    """Replace <NAME> with env[NAME]. A line with an unset optional placeholder is dropped.
    Returns (text, names of required placeholders still unfilled)."""
    lines = []
    for line in text.split("\n"):
        names = PLACEHOLDER.findall(line)
        if any(n in OPTIONAL_PLACEHOLDERS and not env.get(n) for n in names):
            continue
        lines.append(PLACEHOLDER.sub(lambda m: env.get(m.group(1)) or m.group(0), line))
    out = "\n".join(lines)
    return out, sorted(set(PLACEHOLDER.findall(out)))


def review_attributes(info, notes_text, env):
    """Attributes for PATCH betaAppReviewDetails, and the list of what is still missing.
    The four contact fields come from env (secrets), never from the file."""
    contact = {f: (env.get(v) or "").strip() for f, v in CONTACT_ENV.items()}
    missing = [CONTACT_ENV[f] for f in REVIEW_FIELDS if not contact[f]]
    notes, unfilled = fill_placeholders(notes_text, env)
    missing += [f"notes placeholder <{n}>" for n in unfilled]
    attrs = {f: v for f, v in contact.items() if v}
    attrs["demoAccountRequired"] = bool(info.get("demoAccountRequired", False))
    for f in ("demoAccountName", "demoAccountPassword"):
        if (info.get(f) or "").strip():
            attrs[f] = info[f].strip()
    if attrs["demoAccountRequired"]:
        missing += [f for f in ("demoAccountName", "demoAccountPassword") if f not in attrs]
    attrs["notes"] = notes[:4000]
    return attrs, missing


def plan_review_detail(detail_id, attrs):
    return ("PATCH", f"/v1/betaAppReviewDetails/{detail_id}",
            {"data": {"type": "betaAppReviewDetails", "id": detail_id, "attributes": attrs}})


def builds_query(app, number=None, limit=25):
    q = f"/v1/builds?filter[app]={app}&sort=-uploadedDate&limit={limit}"
    q += "&include=preReleaseVersion,buildBetaDetail,betaAppReviewSubmission"
    q += "&fields[builds]=version,uploadedDate,processingState,expired,expirationDate,usesNonExemptEncryption,minOsVersion,preReleaseVersion,buildBetaDetail,betaAppReviewSubmission"
    if number:
        q += f"&filter[version]={number}"
    return q


# ---------------------------------------------------------------- network

def _der_to_raw(der):
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    out = b""
    for _ in range(2):
        n = der[i + 1]
        out += der[i + 2:i + 2 + n].lstrip(b"\x00").rjust(32, b"\x00")
        i += 2 + n
    return out


def _b64url(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def token():
    header = {"alg": "ES256", "kid": os.environ["ASC_KEY_ID"], "typ": "JWT"}
    now = int(time.time())
    claims = {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"}
    signing = f"{_b64url(json.dumps(header).encode())}.{_b64url(json.dumps(claims).encode())}".encode()
    path, temp = os.environ.get("ASC_KEY_PATH"), False
    if not path:
        fd, path = tempfile.mkstemp(suffix=".p8")
        with os.fdopen(fd, "wb") as f:
            f.write(base64.b64decode(os.environ["ASC_KEY_P8_BASE64"]))
        temp = True
    try:
        der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", path], input=signing,
                             capture_output=True, check=True).stdout
    finally:
        if temp:
            os.unlink(path)
    return signing.decode() + "." + _b64url(_der_to_raw(der))


_tok = {"v": None, "at": 0}


def call(method, path, body=None):
    if not _tok["v"] or time.time() - _tok["at"] > 600:
        _tok["v"], _tok["at"] = token(), time.time()
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": "Bearer " + _tok["v"], "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        try:
            detail = "; ".join(f"{x.get('title')}: {x.get('detail')}" for x in json.loads(detail)["errors"])
        except Exception:
            pass
        die(f"App Store Connect {method} {path.split('?')[0]} -> {e.code}: {detail}")


def get_all(path):
    """GET following links.next; returns (data, included)."""
    data, included = [], []
    while path:
        r = call("GET", path)
        data += r.get("data", [])
        included += r.get("included", [])
        nxt = r.get("links", {}).get("next")
        path = nxt[len(API):] if nxt else None
    return data, included


def app_id(bundle):
    data = call("GET", f"/v1/apps?filter[bundleId]={bundle}&fields[apps]=bundleId,name")["data"]
    exact = [d for d in data if d["attributes"].get("bundleId") == bundle]
    if not exact:
        die(f"no App Store Connect record for {bundle}")
    return exact[0]["id"], exact[0]["attributes"].get("name")


def groups(app):
    data, _ = get_all(f"/v1/apps/{app}/betaGroups?limit=100&fields[betaGroups]=name,isInternalGroup,publicLinkEnabled")
    return data


def find_group(app, name):
    gs = groups(app)
    hit = [g for g in gs if g["attributes"]["name"] == name]
    if not hit:
        die(f"no beta group named \"{name}\". Groups: " + ", ".join(f"\"{g['attributes']['name']}\"" for g in gs))
    return hit[0]


def find_build(app, number):
    data, inc = get_all(builds_query(app, number))
    if not data:
        die(f"no build {number} for this app")
    if len(data) > 1:
        say(f"- note: {len(data)} builds numbered {number}; using the newest upload")
    return data[0], inc


# ---------------------------------------------------------------- commands

def _incl(inc, kind, ident):
    return next((i for i in inc if i["type"] == kind and i["id"] == ident), None)


def cmd_status(a, app, name):
    builds, inc = get_all(builds_query(app, limit=a.limit))
    gs = groups(app)
    members = {}
    for g in gs:
        ids, _ = get_all(f"/v1/betaGroups/{g['id']}/builds?limit=200&fields[builds]=version")
        for b in ids:
            members.setdefault(b["id"], []).append(g["attributes"]["name"])
    say(f"### TestFlight status: {name} (`{a.bundle}`)")
    say("")
    say("Groups: " + ", ".join(f"\"{g['attributes']['name']}\" ({'internal' if g['attributes'].get('isInternalGroup') else 'external'})" for g in gs))
    say("")
    say("| Build | Version | Uploaded (UTC) | Processing | Internal | External | Beta review | Expires | Groups |")
    say("|---|---|---|---|---|---|---|---|---|")
    for b in builds:
        at, rel = b["attributes"], b.get("relationships", {})
        pre = _incl(inc, "preReleaseVersions", (rel.get("preReleaseVersion", {}).get("data") or {}).get("id"))
        det = _incl(inc, "buildBetaDetails", (rel.get("buildBetaDetail", {}).get("data") or {}).get("id"))
        sub = _incl(inc, "betaAppReviewSubmissions", (rel.get("betaAppReviewSubmission", {}).get("data") or {}).get("id"))
        da = det["attributes"] if det else {}
        exp = "EXPIRED" if at.get("expired") else (at.get("expirationDate") or "?")[:10]
        say("| {} | {} | {} | {} | {} | {} | {} | {} | {} |".format(
            at["version"], pre["attributes"]["version"] if pre else "?", (at.get("uploadedDate") or "?")[:16].replace("T", " "),
            at.get("processingState", "?"), da.get("internalBuildState", "-"), da.get("externalBuildState", "-"),
            sub["attributes"].get("betaReviewState", "-") if sub else "none", exp,
            ", ".join(members.get(b["id"], [])) or "none"))


def run_plan(a, title, steps, lines):
    """Print the plan; run the requests only with --yes."""
    say(f"### {title}")
    say("")
    for l in lines:
        say(f"- {l}")
    say("")
    if not a.yes:
        say("**Plan only: nothing changed.** Run again with confirm ticked to do it.")
        return False
    for m, p, body in steps:
        call(m, p, body)
        say(f"- done: `{m} {p}`")
    return True


def cmd_add(a, app, name, remove=False):
    g, (b, _) = find_group(app, a.group), find_build(app, a.build)
    verb = "Remove" if remove else "Add"
    step = (plan_remove_from_group if remove else plan_add_to_group)(g["id"], b["id"])
    kind = "internal" if g["attributes"].get("isInternalGroup") else "external"
    lines = [f"{verb} build {a.build} {'from' if remove else 'to'} the {kind} group \"{a.group}\"."]
    if not remove and kind == "external":
        lines.append("An external group needs Beta App Review for this build; adding does not submit it. Use submit-beta-review.")
    run_plan(a, f"{verb} build {a.build} {'from' if remove else 'to'} \"{a.group}\"", [step], lines)


def cmd_expire(a, app, name):
    b, _ = find_build(app, a.build)
    run_plan(a, f"Expire build {a.build}", [plan_expire(b["id"])],
             [f"Expire build {a.build} (state {b['attributes'].get('processingState')}). Testers lose it; this cannot be undone.",
              "A build waiting for Beta App Review stops being reviewed."])


def cmd_submit(a, app, name):
    b, inc = find_build(app, a.build)
    if b["attributes"].get("processingState") != "VALID":
        die(f"build {a.build} is {b['attributes'].get('processingState')}, not VALID yet")
    detail = call("GET", f"/v1/apps/{app}/betaAppReviewDetail")["data"]["attributes"]
    empty = [f for f in REVIEW_FIELDS if not (detail.get(f) or "").strip()]
    lines = [f"Submit build {a.build} for Beta App Review (needed before external testers get it)."]
    if empty or not (detail.get("notes") or "").strip():
        lines.append("**Review details are incomplete** (" + ", ".join(empty + ([] if (detail.get('notes') or '').strip() else ['notes'])) +
                     "). Run set-test-info first.")
        if a.yes:
            die("review details incomplete; not submitting")
    run_plan(a, f"Submit build {a.build} for Beta App Review", [plan_submit_beta_review(b["id"])], lines)


def cmd_set_info(a, app, name):
    b, _ = find_build(app, a.build)
    steps, lines = [], []
    if a.whats_new:
        text = open(a.whats_new).read().strip()
        locs = call("GET", f"/v1/builds/{b['id']}/betaBuildLocalizations")["data"]
        loc = next((l for l in locs if l["attributes"]["locale"] == a.locale), None)
        steps.append(plan_whats_new(b["id"], loc["id"] if loc else None, a.locale, text))
        lines.append(f"Set \"What to Test\" ({a.locale}, {len(text)} characters) on build {a.build}:")
        lines += [f"    > {l}" for l in text.splitlines()[:12]]
    if a.review_file:
        info = json.load(open(a.review_file))
        notes_path = os.path.join(os.path.dirname(os.path.abspath(a.review_file)), info.get("notesFile", "review-notes.txt"))
        attrs, missing = review_attributes(info, open(notes_path).read(), os.environ)
        detail_id = call("GET", f"/v1/apps/{app}/betaAppReviewDetail")["data"]["id"]
        steps.append(plan_review_detail(detail_id, attrs))
        shown = {k: ("(set)" if k in CONTACT_ENV or k == "demoAccountPassword" else v) for k, v in attrs.items() if k != "notes"}
        lines.append(f"Set the Beta App Review details (app level): {json.dumps(shown)}; notes {len(attrs['notes'])} characters from {os.path.basename(notes_path)}.")
        if missing:
            lines.append("**Still missing:** " + "; ".join(missing))
            if a.yes:
                die("review details incomplete; nothing applied: " + "; ".join(missing))
    if not steps:
        die("give --whats-new FILE and/or --review-file FILE")
    run_plan(a, f"Set test information for build {a.build}", steps, lines)


def call_soft(path):
    """GET that returns (json, None) or (None, error text), never exits. Read-only."""
    if not _tok["v"] or time.time() - _tok["at"] > 600:
        _tok["v"], _tok["at"] = token(), time.time()
    req = urllib.request.Request(API + path, method="GET", headers={"Authorization": "Bearer " + _tok["v"]})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return (json.loads(raw) if raw else {}), None
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        try:
            detail = "; ".join(f"{x.get('title')}: {x.get('detail')}" for x in json.loads(detail)["errors"])
        except Exception:
            pass
        return None, f"HTTP {e.code}: {detail}"


def cmd_inspect(a, app, name):
    """Read-only: everything Apple says about one version, including builds that are not VALID and build uploads."""
    ver = a.version
    say(f"### Inspect {name} (`{a.bundle}`), version {ver}")
    say("")
    r, err = call_soft(f"/v1/builds?filter[app]={app}&limit=200&sort=-uploadedDate&include=preReleaseVersion"
                       "&fields[builds]=version,uploadedDate,processingState,expired,minOsVersion,usesNonExemptEncryption"
                       "&fields[preReleaseVersions]=version")
    say("**Builds (all processing states, newest first, up to 10):**")
    if err:
        say(f"- error: {err}")
    else:
        inc = r.get("included", [])
        say("| Build | Version | Uploaded (UTC) | Processing | Expired |")
        say("|---|---|---|---|---|")
        for b in r["data"][:10]:
            at, rel = b["attributes"], b.get("relationships", {})
            pre = _incl(inc, "preReleaseVersions", (rel.get("preReleaseVersion", {}).get("data") or {}).get("id"))
            say("| {} | {} | {} | {} | {} |".format(at.get("version"), pre["attributes"]["version"] if pre else "?",
                (at.get("uploadedDate") or "?")[:16].replace("T", " "), at.get("processingState"), at.get("expired")))
        n = [b for b in r["data"] if b["attributes"].get("processingState") != "VALID"]
        say(f"- builds not VALID: {len(n)}")
    say("")
    for st in ("PROCESSING", "FAILED", "INVALID"):
        r, err = call_soft(f"/v1/builds?filter[app]={app}&filter[processingState]={st}&limit=50&fields[builds]=version,uploadedDate,processingState")
        say(f"**Builds with processingState {st}:** " + (f"error: {err}" if err else
            (", ".join(f"{b['attributes']['version']} ({(b['attributes'].get('uploadedDate') or '?')[:16]})" for b in r["data"]) or "none")))
    say("")
    r, err = call_soft(f"/v1/preReleaseVersions?filter[app]={app}&filter[version]={ver}&include=builds")
    say(f"**Pre-release version {ver}:** " + (f"error: {err}" if err else (f"{len(r['data'])} found, builds included: {len(r.get('included', []))}" if r["data"] else "not found")))
    say("")
    r, err = call_soft(f"/v1/apps/{app}/buildUploads?limit=20")
    say("**Build uploads (/v1/apps/{id}/buildUploads):**")
    if err:
        say(f"- not readable: {err}")
    else:
        rows = r.get("data", [])
        if not rows:
            say("- none listed")
        for u in rows[:20]:
            at = u.get("attributes", {})
            say("- " + json.dumps({k: at.get(k) for k in ("cfBundleShortVersionString", "cfBundleVersion", "platform", "createdDate", "state") if k in at}))
            st = at.get("state") or {}
            for k in ("errors", "warnings", "infos"):
                for x in (st.get(k) or []):
                    say(f"    {k[:-1]}: {x.get('code')}: {x.get('description')}")


def plan_public_link(group_id, limit):
    attrs = {"publicLinkEnabled": True, "feedbackEnabled": True}
    if limit:
        attrs.update({"publicLinkLimitEnabled": True, "publicLinkLimit": limit})
    else:
        attrs["publicLinkLimitEnabled"] = False
    return ("PATCH", f"/v1/betaGroups/{group_id}", {"data": {"type": "betaGroups", "id": group_id, "attributes": attrs}})


def cmd_groups(a, app, name):
    """Read-only: beta groups with their settings. The public link itself is never printed."""
    r, err = call_soft(f"/v1/apps/{app}/betaGroups?limit=100")
    say(f"### Beta groups: {name} (`{a.bundle}`)")
    say("")
    if err:
        say(f"- error: {err}")
        return
    say("| Group | Internal | Public link | Link limit | Feedback | All builds | Created |")
    say("|---|---|---|---|---|---|---|")
    for g in r["data"]:
        at = g["attributes"]
        lim = at.get("publicLinkLimit") if at.get("publicLinkLimitEnabled") else "none"
        say("| {} | {} | {} | {} | {} | {} | {} |".format(at.get("name"), at.get("isInternalGroup"),
            "enabled" if at.get("publicLinkEnabled") else "off", lim, at.get("feedbackEnabled"),
            at.get("hasAccessToAllBuilds"), (at.get("createdDate") or "?")[:10]))
    d, err = call_soft(f"/v1/apps/{app}/betaAppReviewDetail")
    say("")
    if err:
        say(f"**Beta App Review details:** error: {err}")
    else:
        at = d["data"]["attributes"]
        have = [f for f in REVIEW_FIELDS if (at.get(f) or "").strip()]
        miss = [f for f in REVIEW_FIELDS if not (at.get(f) or "").strip()]
        say(f"**Beta App Review details (app level):** set: {', '.join(have) or 'none'}; empty: {', '.join(miss) or 'none'}; "
            f"notes {'set' if (at.get('notes') or '').strip() else 'empty'}; demo account required: {at.get('demoAccountRequired')}")


def cmd_public_link(a, app, name):
    g = find_group(app, a.group)
    if g["attributes"].get("isInternalGroup"):
        die(f"\"{a.group}\" is an internal group; a public link needs an external group")
    now = "already enabled" if g["attributes"].get("publicLinkEnabled") else "off"
    lines = [f"Turn on the public TestFlight link for the external group \"{a.group}\" (now: {now}), tester feedback on,"
             + (f" limited to {a.limit} testers." if a.limit else " no tester limit."),
             "Anyone with the link can install builds of this group once Beta App Review approves a build in it.",
             "The link is not printed here; read it in App Store Connect when it is on."]
    run_plan(a, f"Public link for \"{a.group}\"", [plan_public_link(g["id"], a.limit)], lines)


def cmd_certificates(a):
    """Read-only: how many signing certificates exist, by type. No names or ids are printed."""
    certs, _ = get_all("/v1/certificates?limit=200&fields[certificates]=certificateType,expirationDate,activated")
    by = {}
    for c in certs:
        at = c["attributes"]
        by.setdefault(at.get("certificateType", "?"), []).append((at.get("expirationDate") or "?")[:10])
    say(f"### Signing certificates: {len(certs)} in total")
    say("")
    say("| Type | Count | Expiry dates |")
    say("|---|---|---|")
    for t in sorted(by):
        say("| {} | {} | {} |".format(t, len(by[t]), ", ".join(sorted(by[t]))))


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--bundle", default=os.environ.get("BUNDLE_ID", DEFAULT_BUNDLE))
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("status"); s.add_argument("--limit", type=int, default=25)
    sub.add_parser("certificates")
    sub.add_parser("groups")
    s = sub.add_parser("public-link"); s.add_argument("--group", required=True); s.add_argument("--limit", type=int, default=0); s.add_argument("--yes", action="store_true")
    s = sub.add_parser("inspect"); s.add_argument("--version", required=True)
    for n in ("add-to-group", "remove-from-group"):
        s = sub.add_parser(n); s.add_argument("--build", required=True); s.add_argument("--group", required=True); s.add_argument("--yes", action="store_true")
    for n in ("expire", "submit-beta-review"):
        s = sub.add_parser(n); s.add_argument("--build", required=True); s.add_argument("--yes", action="store_true")
    s = sub.add_parser("set-test-info"); s.add_argument("--build", required=True); s.add_argument("--yes", action="store_true")
    s.add_argument("--whats-new"); s.add_argument("--review-file"); s.add_argument("--locale", default="en-US")
    a = p.parse_args(argv)
    for v in ("ASC_KEY_ID", "ASC_ISSUER_ID"):
        if not os.environ.get(v):
            sys.exit(f"missing secret {v}")
    if not (os.environ.get("ASC_KEY_PATH") or os.environ.get("ASC_KEY_P8_BASE64")):
        sys.exit("missing secret ASC_KEY_P8_BASE64")
    if a.cmd == "certificates":
        return cmd_certificates(a)
    app, name = app_id(a.bundle)
    if a.cmd == "inspect":
        return cmd_inspect(a, app, name)
    if a.cmd == "groups":
        return cmd_groups(a, app, name)
    if a.cmd == "public-link":
        return cmd_public_link(a, app, name)
    {"status": cmd_status, "add-to-group": cmd_add, "expire": cmd_expire, "submit-beta-review": cmd_submit,
     "set-test-info": cmd_set_info,
     "remove-from-group": lambda a, app, name: cmd_add(a, app, name, remove=True)}[a.cmd](a, app, name)


if __name__ == "__main__":
    main()
