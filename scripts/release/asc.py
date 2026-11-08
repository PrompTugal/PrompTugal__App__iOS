#!/usr/bin/env python3
"""Small App Store Connect API client for the release workflows.

Python standard library plus the system `openssl` (for the ES256 token), so it
runs on any GitHub runner without installing anything.

    asc.py wait-build   --version 0.3.1 --build 123 [--timeout 1800]
    asc.py compliance   --version 0.3.1 --build 123        # usesNonExemptEncryption = false
    asc.py whats-new    --version 0.3.1 --build 123 --file notes.txt
    asc.py submit       --version 0.3.1 --build 123 [--yes] # App Store review
    asc.py store-metadata --listing store/listing.json [--version 0.4.n] [--also en-GB=en-US]
                        [--skip whatsNew] [--content-rights USES_THIRD_PARTY_CONTENT] [--categories NEWS,BUSINESS]
                        [--review-notes review-notes.txt] [--set-version-string 0.4.n] [--yes]
                        # App Store listing; dry run unless --yes. Review contact from REVIEW_CONTACT_* and the
                        # notes placeholder <DEMO_OPENROUTER_KEY> from the environment: never printed.

Environment: ASC_KEY_ID, ASC_ISSUER_ID and either ASC_KEY_PATH (a .p8 file) or
ASC_KEY_P8_BASE64. BUNDLE_ID defaults to news.promptugal.reader.

Never prints the key or the token. `submit` without --yes only shows the plan.
"""
import argparse, base64, json, os, subprocess, sys, tempfile, time, urllib.error, urllib.request

API = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = os.environ.get("BUNDLE_ID", "news.promptugal.reader")
SUMMARY = os.environ.get("GITHUB_STEP_SUMMARY")


def say(msg):
    print(msg, flush=True)
    if SUMMARY:
        with open(SUMMARY, "a") as f:
            f.write(msg + "\n")


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der):
    """openssl gives a DER ECDSA signature; JWT wants r||s, 32 bytes each."""
    assert der[0] == 0x30
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    out = b""
    for _ in range(2):
        assert der[i] == 0x02
        n = der[i + 1]
        v = der[i + 2:i + 2 + n].lstrip(b"\x00")
        out += v.rjust(32, b"\x00")
        i += 2 + n
    return out


def key_path():
    if os.environ.get("ASC_KEY_PATH"):
        return os.environ["ASC_KEY_PATH"], False
    data = base64.b64decode(os.environ["ASC_KEY_P8_BASE64"])
    fd, path = tempfile.mkstemp(suffix=".p8")
    with os.fdopen(fd, "wb") as f:
        f.write(data)
    return path, True


def token():
    header = {"alg": "ES256", "kid": os.environ["ASC_KEY_ID"], "typ": "JWT"}
    now = int(time.time())
    claims = {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"}
    signing_input = f"{b64url(json.dumps(header).encode())}.{b64url(json.dumps(claims).encode())}".encode()
    path, temp = key_path()
    try:
        der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", path], input=signing_input,
                             capture_output=True, check=True).stdout
    finally:
        if temp:
            os.unlink(path)
    return signing_input.decode() + "." + b64url(der_to_raw(der))


_TOKEN = {"value": None, "at": 0}


def call(method, path, body=None, ok=(200, 201, 204)):
    if not _TOKEN["value"] or time.time() - _TOKEN["at"] > 600:
        _TOKEN["value"], _TOKEN["at"] = token(), time.time()
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": "Bearer " + _TOKEN["value"],
                                          "Content-Type": "application/json"})
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
        sys.exit(f"::error::App Store Connect {method} {path.split('?')[0]} -> {e.code}: {detail}")


def app_id():
    data = call("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}&fields[apps]=bundleId,name")["data"]
    if not data:
        sys.exit(f"::error::no app with bundle id {BUNDLE_ID} in App Store Connect; create the app record first")
    return data[0]["id"]


def cmd_has_record(a):
    """Exit 0 and print the record id if the bundle has an App Store Connect record; exit 3 if not.
    The release workflow uses it so an app without a record (Team, until Dinis creates it) is
    skipped, not failed, and so an upload can never go to a record of another bundle id."""
    data = call("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}&fields[apps]=bundleId,name")["data"]
    exact = [d for d in data if d.get("attributes", {}).get("bundleId") == BUNDLE_ID]
    if not exact:
        say(f"- ⏭️ no App Store Connect record for `{BUNDLE_ID}`; create it by hand (release-setup.md), nothing uploaded.")
        sys.exit(3)
    say(f"- App Store Connect record for `{BUNDLE_ID}`: \"{exact[0]['attributes'].get('name')}\" (id {exact[0]['id']}).")


def find_build(app, version, build):
    q = (f"/v1/builds?filter[app]={app}&filter[version]={build}"
         f"&filter[preReleaseVersion.version]={version}&fields[builds]=version,processingState,usesNonExemptEncryption,expired")
    data = call("GET", q)["data"]
    return data[0] if data else None


def cmd_wait_build(a):
    app = app_id()
    deadline = time.time() + a.timeout
    while True:
        b = find_build(app, a.version, a.build)
        state = b["attributes"]["processingState"] if b else "NOT_FOUND_YET"
        print(f"build {a.version} ({a.build}): {state}", flush=True)
        if state == "VALID":
            say(f"- ✅ App Store Connect finished processing {a.version} ({a.build}).")
            return b
        if state in ("FAILED", "INVALID"):
            sys.exit(f"::error::App Store Connect marked the build {state}; check the email from Apple")
        if time.time() > deadline:
            say(f"- ⏳ Build still {state} after {a.timeout // 60} min; it will finish on its own. Not waiting longer.")
            return None
        time.sleep(30)


def cmd_compliance(a):
    app = app_id()
    b = find_build(app, a.version, a.build)
    if not b:
        sys.exit("::error::build not found")
    if b["attributes"].get("usesNonExemptEncryption") is None:
        call("PATCH", f"/v1/builds/{b['id']}", {"data": {"type": "builds", "id": b["id"],
                                                         "attributes": {"usesNonExemptEncryption": False}}})
        say("- Export compliance answered: only encryption built into iOS (usesNonExemptEncryption = false).")
    else:
        say(f"- Export compliance already set: usesNonExemptEncryption = {b['attributes']['usesNonExemptEncryption']}.")


def cmd_whats_new(a):
    app = app_id()
    b = find_build(app, a.version, a.build)
    if not b:
        sys.exit("::error::build not found")
    text = open(a.file).read()[:3900]
    locs = call("GET", f"/v1/builds/{b['id']}/betaBuildLocalizations")["data"]
    loc = next((l for l in locs if l["attributes"]["locale"] == a.locale), None)
    if loc:
        call("PATCH", f"/v1/betaBuildLocalizations/{loc['id']}",
             {"data": {"type": "betaBuildLocalizations", "id": loc["id"], "attributes": {"whatsNew": text}}})
    else:
        call("POST", "/v1/betaBuildLocalizations",
             {"data": {"type": "betaBuildLocalizations", "attributes": {"locale": a.locale, "whatsNew": text},
                       "relationships": {"build": {"data": {"type": "builds", "id": b["id"]}}}}})
    say(f"- TestFlight \"What to Test\" set ({len(text)} characters, {a.locale}).")


def cmd_submit(a):
    app = app_id()
    b = find_build(app, a.version, a.build)
    if not b or b["attributes"]["processingState"] != "VALID":
        sys.exit("::error::build not found or not processed yet; run wait-build first")
    versions = call("GET", f"/v1/apps/{app}/appStoreVersions?filter[platform]=IOS&filter[versionString]={a.version}"
                           f"&fields[appStoreVersions]=versionString,appStoreState")["data"]
    say(f"### App Store submission plan for {a.version} ({a.build})")
    say("")
    if versions:
        v = versions[0]
        say(f"- App Store version {a.version} exists, state `{v['attributes']['appStoreState']}`.")
    else:
        v = None
        say(f"- App Store version {a.version} does not exist; it will be created (metadata stays manual).")
    say(f"- Attach build {a.build} to it, then create a review submission and submit it.")
    if not a.yes:
        say("")
        say("Dry run: nothing changed. Run with **confirm** ticked to submit.")
        return
    if not v:
        v = call("POST", "/v1/appStoreVersions", {"data": {"type": "appStoreVersions",
                 "attributes": {"platform": "IOS", "versionString": a.version},
                 "relationships": {"app": {"data": {"type": "apps", "id": app}}}}})["data"]
        say(f"- Created App Store version {a.version}. Fill in its metadata and screenshots in App Store Connect, then run this again.")
        return
    call("PATCH", f"/v1/appStoreVersions/{v['id']}/relationships/build", {"data": {"type": "builds", "id": b["id"]}})
    say(f"- Build {a.build} attached.")
    open_subs = call("GET", f"/v1/reviewSubmissions?filter[app]={app}&filter[platform]=IOS"
                            f"&filter[state]=READY_FOR_REVIEW")["data"]
    sub = open_subs[0] if open_subs else call("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions",
            "attributes": {"platform": "IOS"}, "relationships": {"app": {"data": {"type": "apps", "id": app}}}}})["data"]
    items = call("GET", f"/v1/reviewSubmissions/{sub['id']}/items")["data"]
    if not items:
        call("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": v["id"]}}}}})
    call("PATCH", f"/v1/reviewSubmissions/{sub['id']}",
         {"data": {"type": "reviewSubmissions", "id": sub["id"], "attributes": {"submitted": True}}})
    say(f"- ✅ Submitted {a.version} ({a.build}) for App Review.")


# ---- App Store listing (metadata only: no build, no screenshots, no submission) ----

APP_INFO_FIELDS = ("name", "subtitle", "privacyPolicyUrl")
VERSION_FIELDS = ("description", "keywords", "promotionalText", "whatsNew", "supportUrl", "marketingUrl")
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "WAITING_FOR_REVIEW",
            "INVALID_BINARY"}


def get_opt(path):
    """GET that returns None instead of stopping when the resource does not exist."""
    try:
        return call("GET", path)
    except SystemExit:
        return None


def short(value, n=60):
    value = "" if value is None else str(value).replace("\n", " ")
    return value if len(value) <= n else value[:n - 1] + "…"


def diff_fields(current, wanted, fields):
    return {f: wanted[f] for f in fields if f in wanted and (current or {}).get(f) != wanted[f]}


def cmd_store_metadata(a):
    listing = json.load(open(a.listing))["locales"]
    for spec in a.also:
        dst, src = spec.split("=")
        listing[dst] = dict(listing[src])
    app = app_id()
    attrs = call("GET", f"/v1/apps/{app}")["data"]["attributes"]
    say(f"### App Store listing for `{BUNDLE_ID}`: {'APPLY' if a.yes else 'dry run, nothing is changed'}")
    say("")
    say(f"- App \"{attrs.get('name')}\", primary locale `{attrs.get('primaryLocale')}`, "
        f"content rights `{attrs.get('contentRightsDeclaration')}`.")
    versions = call("GET", f"/v1/apps/{app}/appStoreVersions?filter[platform]=IOS&limit=20")["data"]
    for v in versions:
        say(f"- Version {v['attributes']['versionString']}: `{v['attributes'].get('appStoreState')}` (id {v['id']})")
    if a.version:
        version = next((v for v in versions if v["attributes"]["versionString"] == a.version), None)
    else:
        version = next((v for v in versions if v["attributes"].get("appStoreState") in EDITABLE), None)
    if not version:
        say("- ❌ No editable App Store version" + (f" {a.version}" if a.version else "") +
            ". Create it first (`submit` creates it without --yes only as a plan).")
        sys.exit(1)
    vid = version["id"]
    say(f"- Using version {version['attributes']['versionString']} (`{version['attributes'].get('appStoreState')}`).")

    infos = call("GET", f"/v1/apps/{app}/appInfos")["data"]
    info = next((i for i in infos if (i["attributes"].get("appStoreState") or i["attributes"].get("state")) in EDITABLE), infos[0])
    say(f"- App info `{info['id']}` state `{info['attributes'].get('appStoreState') or info['attributes'].get('state')}`.")

    changes = []   # (what, method, path, body)
    info_locs = {l["attributes"]["locale"]: l for l in call("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations?limit=50")["data"]}
    ver_locs = {l["attributes"]["locale"]: l for l in call("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations?limit=50")["data"]}
    say("")
    say("| Locale | Part | Field | Now | Would be |")
    say("| --- | --- | --- | --- | --- |")
    for loc, want in listing.items():
        cur = info_locs.get(loc)
        d = diff_fields(cur["attributes"] if cur else None, want, APP_INFO_FIELDS)
        for f, val in d.items():
            say(f"| {loc} | app info | {f} | {short(cur['attributes'].get(f)) if cur else '(no localization)'} | {short(val)} |")
        if d and cur:
            changes.append((f"{loc} app info", "PATCH", f"/v1/appInfoLocalizations/{cur['id']}",
                            {"data": {"type": "appInfoLocalizations", "id": cur["id"], "attributes": d}}))
        elif d:
            body = {"data": {"type": "appInfoLocalizations", "attributes": dict(d, locale=loc),
                             "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}}}}
            changes.append((f"{loc} app info (new locale)", "POST", "/v1/appInfoLocalizations", body))
        cur = ver_locs.get(loc)
        d = diff_fields(cur["attributes"] if cur else None, want, [f for f in VERSION_FIELDS if f not in a.skip])
        for f, val in d.items():
            say(f"| {loc} | version | {f} | {short(cur['attributes'].get(f)) if cur else '(no localization)'} | {short(val)} |")
        if d and cur:
            changes.append((f"{loc} version", "PATCH", f"/v1/appStoreVersionLocalizations/{cur['id']}",
                            {"data": {"type": "appStoreVersionLocalizations", "id": cur["id"], "attributes": d}}))
        elif d:
            body = {"data": {"type": "appStoreVersionLocalizations", "attributes": dict(d, locale=loc),
                             "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}}
            changes.append((f"{loc} version (new locale)", "POST", "/v1/appStoreVersionLocalizations", body))
    # Extras: version string, content rights, categories, App Review details
    if a.set_version_string and version["attributes"]["versionString"] != a.set_version_string:
        say(f"| | version | versionString | {version['attributes']['versionString']} | {a.set_version_string} |")
        changes.append(("version string", "PATCH", f"/v1/appStoreVersions/{vid}",
                        {"data": {"type": "appStoreVersions", "id": vid,
                                  "attributes": {"versionString": a.set_version_string}}}))
    if a.content_rights and attrs.get("contentRightsDeclaration") != a.content_rights:
        say(f"| | app | contentRightsDeclaration | {attrs.get('contentRightsDeclaration')} | {a.content_rights} |")
        changes.append(("content rights", "PATCH", f"/v1/apps/{app}",
                        {"data": {"type": "apps", "id": app, "attributes": {"contentRightsDeclaration": a.content_rights}}}))
    if a.categories:
        want_cat = dict(zip(("primaryCategory", "secondaryCategory"), a.categories.split(",")))
        inc = get_opt(f"/v1/appInfos/{info['id']}?include=primaryCategory,secondaryCategory") or {}
        rel = (inc.get("data") or {}).get("relationships", {})
        now_cat = {k: ((rel.get(k) or {}).get("data") or {}).get("id") for k in want_cat}
        todo = {k: v for k, v in want_cat.items() if now_cat.get(k) != v}
        for k, v in todo.items():
            say(f"| | app info | {k} | {now_cat.get(k)} | {v} |")
        if todo:
            rels = {k: {"data": {"type": "appCategories", "id": v}} for k, v in todo.items()}
            changes.append(("categories", "PATCH", f"/v1/appInfos/{info['id']}",
                            {"data": {"type": "appInfos", "id": info["id"], "relationships": rels}}))
    if a.review_notes:
        env_for = {"contactFirstName": "REVIEW_CONTACT_FIRST_NAME", "contactLastName": "REVIEW_CONTACT_LAST_NAME",
                   "contactEmail": "REVIEW_CONTACT_EMAIL", "contactPhone": "REVIEW_CONTACT_PHONE"}
        contact = {f: (os.environ.get(v) or "").strip() for f, v in env_for.items()}
        notes = open(a.review_notes).read()
        import re
        names = sorted(set(re.findall(r"<([A-Z][A-Z_]+)>", notes)))
        unfilled = [n for n in names if not os.environ.get(n)]
        for n in names:
            if os.environ.get(n):
                notes = notes.replace(f"<{n}>", os.environ[n])
        detail = get_opt(f"/v1/appStoreVersions/{vid}/appStoreReviewDetail")
        cur = ((detail or {}).get("data") or {})
        cur_attrs = cur.get("attributes", {})
        want_attrs = {f: v for f, v in contact.items() if v}
        want_attrs["demoAccountRequired"] = False
        want_attrs["notes"] = notes[:4000]
        diff = [f for f, v in want_attrs.items() if cur_attrs.get(f) != v]
        missing = [env_for[f] for f, v in contact.items() if not v] + [f"<{n}>" for n in unfilled]
        say(f"| | review details | fields to set | {', '.join(sorted(cur_attrs)) or '(none)'} | {', '.join(diff) or 'already equal'} (values not shown) |")
        if missing:
            say(f"- ⚠️ App Review details: missing from the environment: {', '.join(missing)}. Nothing is set for the review details until they exist.")
        elif diff:
            if cur.get("id"):
                changes.append(("review details", "PATCH", f"/v1/appStoreReviewDetails/{cur['id']}",
                                {"data": {"type": "appStoreReviewDetails", "id": cur["id"], "attributes": want_attrs}}))
            else:
                changes.append(("review details (new)", "POST", "/v1/appStoreReviewDetails",
                                {"data": {"type": "appStoreReviewDetails", "attributes": want_attrs,
                                          "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}}))
    if not changes:
        say("| | | | nothing differs | |")
    say("")
    # Read-only report on what this command does not touch
    say("Not touched by this command (current state, for the checklist):")
    for loc, l in ver_locs.items():
        sets = get_opt(f"/v1/appStoreVersionLocalizations/{l['id']}/appScreenshotSets") or {"data": []}
        kinds = [f"{s['attributes']['screenshotDisplayType']}" for s in sets["data"]]
        say(f"- {loc}: screenshot sets {', '.join(kinds) or 'none'}")
    detail = get_opt(f"/v1/appStoreVersions/{vid}/appStoreReviewDetail")
    say(f"- Review details: {'present' if detail and detail.get('data') else 'missing'}")
    age = get_opt(f"/v1/appInfos/{info['id']}/ageRatingDeclaration")
    say(f"- Age rating declaration: {'present' if age and age.get('data') else 'missing'}")
    inc = get_opt(f"/v1/appInfos/{info['id']}?include=primaryCategory,secondaryCategory") or {}
    cats = [x["id"] for x in inc.get("included", [])]
    say(f"- Categories: {', '.join(cats) or 'none set'}")
    say(f"- Changes planned: {len(changes)}")
    if not a.yes:
        say("")
        say("Dry run: nothing changed. Run with **confirm** ticked to apply these changes.")
        return
    for what, method, path, body in changes:
        call(method, path, body)
        say(f"- ✅ {what}: {method} done")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("has-record")
    sm = sub.add_parser("store-metadata")
    sm.add_argument("--listing", required=True)
    sm.add_argument("--version", default="")
    sm.add_argument("--also", action="append", default=[], help="LOCALE=SOURCE: copy a listing locale (en-GB=en-US)")
    sm.add_argument("--skip", action="append", default=[], help="a version field not to set (whatsNew on a first version)")
    sm.add_argument("--content-rights", default="")
    sm.add_argument("--categories", default="", help="PRIMARY,SECONDARY category ids, e.g. NEWS,BUSINESS")
    sm.add_argument("--review-notes", default="")
    sm.add_argument("--set-version-string", default="")
    sm.add_argument("--yes", action="store_true")
    for name in ("wait-build", "compliance", "whats-new", "submit"):
        s = sub.add_parser(name)
        s.add_argument("--version", required=True)
        s.add_argument("--build", required=True)
        if name == "wait-build":
            s.add_argument("--timeout", type=int, default=1800)
        if name == "whats-new":
            s.add_argument("--file", required=True)
            s.add_argument("--locale", default="en-US")
        if name == "submit":
            s.add_argument("--yes", action="store_true")
    a = p.parse_args()
    for v in ("ASC_KEY_ID", "ASC_ISSUER_ID"):
        if not os.environ.get(v):
            sys.exit(f"skipped: secret {v} missing")
    if not (os.environ.get("ASC_KEY_PATH") or os.environ.get("ASC_KEY_P8_BASE64")):
        sys.exit("skipped: secret ASC_KEY_P8_BASE64 missing")
    {"has-record": cmd_has_record, "wait-build": cmd_wait_build, "compliance": cmd_compliance,
     "whats-new": cmd_whats_new, "submit": cmd_submit, "store-metadata": cmd_store_metadata}[a.cmd](a)


if __name__ == "__main__":
    main()
