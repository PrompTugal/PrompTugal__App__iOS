#!/usr/bin/env python3
"""Measure macOS jobs per dev push, queue vs run time, and push-to-TestFlight lead time.

  python3 measure.py fetch SINCE OUT.json     # e.g. 2026-11-08T00:00:00Z (needs gh, actions: read)
  python3 measure.py report OUT.json

A job "ran" only when it got a runner (runner_name set): jobs cancelled while queued carry
started_at/completed_at too, and counting them inflates both run time and concurrency.
Pagination is by page number: the API's Link headers use numeric repository paths.
"""
import collections as C, concurrent.futures as cf, json, statistics as st, subprocess, sys
from datetime import datetime as D

R = "repos/PrompTugal/PrompTugal__App__iOS"
t = lambda s: D.fromisoformat(s.replace("Z", "+00:00"))
mac = lambda j: any(l.startswith("macos") or l == "self-hosted" for l in j["labels"])
ran = lambda j: mac(j) and j.get("runner_name") and j["started_at"] and j["completed_at"]
mins = lambda s: round(s / 60, 1)


def get(p):
    for _ in range(4):
        r = subprocess.run(["gh", "api", p], capture_output=True, text=True)
        if r.returncode == 0:
            return json.loads(r.stdout)
    raise RuntimeError(r.stderr[:300])


def pages(p, key):
    out, n = [], 1
    while True:
        d = get(f"{p}&per_page=100&page={n}")
        out += d[key]
        if len(d[key]) < 100:
            return out
        n += 1


def fetch(since, path):
    runs = pages(f"{R}/actions/runs?created=>={since}", "workflow_runs")
    with cf.ThreadPoolExecutor(12) as ex:
        jobs = dict(ex.map(lambda r: (r["id"], pages(f"{R}/actions/runs/{r['id']}/jobs?filter=latest", "jobs")), runs))
    for r in runs:
        r["_jobs"] = jobs[r["id"]]
    json.dump(runs, open(path, "w"))


def q(j): return (t(j["started_at"]) - t(j["created_at"])).total_seconds()
def d(j): return (t(j["completed_at"]) - t(j["started_at"])).total_seconds()
def f(L): return f"n={len(L)} median {mins(st.median(L))} p90 {mins(sorted(L)[int(.9 * len(L))])} max {mins(max(L))}" if L else "n=0"


def report(path):
    runs = json.load(open(path))
    print("window", min(r["created_at"] for r in runs), "to", max(r["created_at"] for r in runs))
    # Where the macOS minutes and the queue went.
    share = C.defaultdict(lambda: [0, 0, 0, 0])
    ev, labels = [], C.defaultdict(list)
    for r in runs:
        k = (r["name"], r["event"], "dev" if r["head_branch"] == "dev" else "branch")
        for j in r["_jobs"]:
            if mac(j) and not j.get("runner_name") and j["conclusion"] == "cancelled":
                share[k][3] += 1
            if ran(j):
                share[k][0] += 1; share[k][1] += d(j); share[k][2] += q(j)
                ev += [(t(j["started_at"]), 1), (t(j["completed_at"]), -1)]
                labels[j["labels"][0]].append(q(j))
    print("\nmacOS jobs by workflow, event, branch: ran, mac-min, queue-min, cancelled before a runner")
    for k, v in sorted(share.items(), key=lambda x: -x[1][1]):
        print(f"  {k}: {v[0]} jobs, {round(v[1] / 60)} mac-min, {round(v[2] / 60)} queue-min, {v[3]} cancelled in queue")
    for lab, L in labels.items():
        print(f"queue on {lab}: {f(L)}")
    ev.sort(); c, prev, hist = 0, None, C.Counter()
    for tt, dd in ev:
        if prev: hist[c] += (tt - prev).total_seconds() / 60
        c += dd; prev = tt
    print("minutes at each number of concurrent macOS jobs:", {k: round(v) for k, v in sorted(hist.items())})

    # Per dev push. The push is the website.yml run (every dev push has one); the macOS work is
    # the ios.yml run on that sha, plus the ios-release run on its release commit (parent = push).
    par = {}
    for r in runs:
        if r["name"] == "iOS release" and r["event"] == "workflow_run":
            p = subprocess.run(["git", "rev-parse", r["head_sha"] + "^"], capture_output=True, text=True).stdout.strip()
            par[p] = r
    ios = {r["head_sha"]: r for r in runs if r["name"] == "iOS" and r["event"] == "push" and r["head_branch"] == "dev"}
    pushes = [r for r in runs if r["name"] == "Release and deploy" and r["event"] == "push" and r["head_branch"] == "dev"]
    per, up, proc = [], [], []
    for w in pushes:
        js = [j for x in (ios.get(w["head_sha"]), par.get(w["head_sha"])) if x for j in x["_jobs"] if ran(j)]
        if not js:
            continue
        per.append(len(js))
        u = [t(s["completed_at"]) for j in js for s in j["steps"]
             if s["conclusion"] == "success" and (s["name"].startswith("Archive, sign") or s["name"].startswith("Sign, export and upload"))]
        p = [t(j["completed_at"]) for x in runs if x["head_sha"] == w["head_sha"] or x is par.get(w["head_sha"]) for j in x["_jobs"]
             if j["completed_at"] and j["conclusion"] == "success" and (j["name"].startswith("TestFlight") or j["name"].startswith("TestFlight processing"))]
        if u: up.append((max(u) - t(w["created_at"])).total_seconds())
        if p: proc.append((max(p) - t(w["created_at"])).total_seconds())
    print(f"\ndev pushes {len(pushes)}, that took a Mac {len(per)}; macOS jobs per such push: median {st.median(per) if per else '-'}, mean {round(st.mean(per), 1) if per else '-'}, max {max(per) if per else '-'}")
    print("push -> last upload done:", f(up))
    print("push -> TestFlight jobs done (processed):", f(proc))


if __name__ == "__main__":
    if sys.argv[1] == "fetch":
        fetch(sys.argv[2], sys.argv[3])
    else:
        report(sys.argv[2])
