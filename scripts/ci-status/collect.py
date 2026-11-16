#!/usr/bin/env python3
"""collect.py [--out FILE]: the CI status of the app and the websites, as one JSON file.

Read by the product site's status page (website/build.py, CI_STATUS_JSON) and by the app's
Status screen (PTLocal/Status), from the `ci-status` branch that .github/workflows/ci-status.yml
force-pushes every ten minutes and after every run of the workflows below.

For each pipeline: the latest runs (status, start, duration, commit, branch), and for pushes to
the branch that ships, how long the push took to reach production:
  website   website.yml on dev: push -> the deploy job confirmed the live site serves the release
  ios       ios.yml on dev: push -> the build was uploaded to TestFlight, and -> App Store Connect
            finished processing it (the "TestFlight processing" job), when that job ran
  release   ios-release.yml (tags and manual runs): durations only
  news      PrompTugal.news's own deploy workflow(s), if its runs can be read: the run's duration
Plus the latest TestFlight build of each app (version and CFBundleVersion), from the
`build-info-apps` artifact ios.yml leaves after an upload (the same artifact
scripts/release/find-build-info.sh and the site's ios-build.json read).

Standard library only. Token: GH_TOKEN or GITHUB_TOKEN (the workflow's own token, actions: read).
Without a token it still works on public repositories, within the anonymous rate limit, but cannot
download artifacts, so the TestFlight builds are left out. Never fails: what it cannot read is
reported as unavailable, with the reason.
"""
import argparse
import io
import json
import os
import re
import statistics
import sys
import urllib.error
import urllib.request
import zipfile
from datetime import datetime, timezone

API = 'https://api.github.com'
REPO = os.environ.get('CI_STATUS_REPO') or os.environ.get('GITHUB_REPOSITORY') or 'PrompTugal/PrompTugal__App__iOS'
NEWS_REPO = os.environ.get('CI_STATUS_NEWS_REPO', 'PrompTugal/PrompTugal__News__Website')
TOKEN = os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN') or ''
SHIP_BRANCH = 'dev'
RUNS_SHOWN = 8          # runs listed per pipeline
DEV_RUNS_TIMED = 10     # dev push runs whose jobs are read for push-to-live (one API call each)

calls = 0


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def request(url, accept='application/vnd.github+json', redirect=True):
    global calls
    calls += 1
    req = urllib.request.Request(url, headers={'Accept': accept, 'User-Agent': 'ci-status-collector',
                                               'X-GitHub-Api-Version': '2022-11-28'})
    if TOKEN and url.startswith(API):
        req.add_header('Authorization', f'Bearer {TOKEN}')
    opener = urllib.request.build_opener() if redirect else urllib.request.build_opener(NoRedirect)
    return opener.open(req, timeout=30)


def get(path):
    with request(path if path.startswith('http') else API + path) as r:
        return json.load(r)


def download(url):
    """An artifact zip: the API answers 302 to a signed storage URL, fetched without our token."""
    try:
        request(url, redirect=False).close()
        return None
    except urllib.error.HTTPError as e:
        if e.code not in (301, 302, 303, 307) or not e.headers.get('Location'):
            raise
        location = e.headers['Location']
    with urllib.request.urlopen(urllib.request.Request(location, headers={'User-Agent': 'ci-status-collector'}), timeout=60) as r:
        return r.read()


def ts(value):
    return datetime.fromisoformat(value.replace('Z', '+00:00')) if value else None


def iso(dt):
    return dt.astimezone(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ') if dt else None


def seconds(a, b):
    return int((b - a).total_seconds()) if a and b else None


def run_summary(r, now):
    start = ts(r.get('run_started_at') or r.get('created_at'))
    done = r.get('status') == 'completed'
    end = ts(r.get('updated_at')) if done else None
    commit = r.get('head_commit') or {}
    return {
        'id': r['id'], 'number': r.get('run_number'), 'attempt': r.get('run_attempt', 1),
        'url': r.get('html_url'), 'event': r.get('event'), 'branch': r.get('head_branch'),
        'status': r.get('status'), 'conclusion': r.get('conclusion'),
        'createdAt': r.get('created_at'), 'startedAt': iso(start), 'finishedAt': iso(end),
        'durationSeconds': seconds(start, end if done else now), 'running': not done,
        'commit': r.get('head_sha'), 'shortCommit': (r.get('head_sha') or '')[:7],
        'title': (commit.get('message') or r.get('display_title') or '').split('\n')[0][:140],
        'committedAt': commit.get('timestamp'),
    }


def runs(repo, workflow, per_page=RUNS_SHOWN, **filters):
    q = '&'.join(f'{k}={v}' for k, v in filters.items())
    return get(f'/repos/{repo}/actions/workflows/{workflow}/runs?per_page={per_page}' + (f'&{q}' if q else ''))['workflow_runs']


def jobs(repo, run_id):
    return get(f'/repos/{repo}/actions/runs/{run_id}/jobs?per_page=100')['jobs']


def find_job(job_list, *names):
    for job in job_list:
        if any(job.get('name', '').lower() == n.lower() or job.get('name', '').lower().startswith(n.lower() + ' ') for n in names):
            return job
    return None


def find_step(job_list, name):
    for job in job_list:
        for step in job.get('steps') or []:
            if step.get('name') == name:
                return step
    return None


def timing(values):
    values = [v for v in values if v is not None]
    if not values:
        return None
    return {'latestSeconds': values[0], 'medianSeconds': int(statistics.median(values)),
            'fastestSeconds': min(values), 'samples': len(values)}


def unavailable(pid, title, repo, workflow, reason):
    return {'id': pid, 'title': title, 'repo': repo, 'workflow': workflow, 'available': False,
            'reason': reason, 'runs': [], 'pushToLive': None}


def pipeline(pid, title, repo, workflow, now, live_label=None):
    try:
        latest = [r for r in runs(repo, workflow, per_page=RUNS_SHOWN * 2) if r.get('conclusion') != 'skipped'][:RUNS_SHOWN]
    except urllib.error.HTTPError as e:
        return unavailable(pid, title, repo, workflow, f'GitHub answered {e.code} for the runs of {workflow}'), []
    except (urllib.error.URLError, TimeoutError) as e:
        return unavailable(pid, title, repo, workflow, f'could not reach GitHub: {e}'), []
    return {'id': pid, 'title': title, 'repo': repo, 'workflow': workflow, 'available': True,
            'url': f'https://github.com/{repo}/actions/workflows/{workflow}',
            'liveLabel': live_label, 'runs': [run_summary(r, now) for r in latest], 'pushToLive': None}, latest


def website(now):
    p, _ = pipeline('website', 'Product site (ios.app.promptugal.news)', REPO, 'website.yml', now,
                    live_label='live on ios.app.promptugal.news')
    if not p['available']:
        return p
    pushes = runs(REPO, 'website.yml', per_page=DEV_RUNS_TIMED, branch=SHIP_BRANCH, event='push')
    timed = {}
    for r in pushes:
        if r.get('status') != 'completed':
            continue
        deploy = find_job(jobs(REPO, r['id']), 'deploy')
        if deploy and deploy.get('conclusion') == 'success':
            timed[r['id']] = {'pushedAt': r['created_at'], 'liveAt': deploy.get('completed_at'),
                              'seconds': seconds(ts(r['created_at']), ts(deploy.get('completed_at')))}
    attach(p, pushes, timed, now)
    p['pushToLive'] = timing([t['seconds'] for t in timed.values()])
    return p


def ios(now):
    p, _ = pipeline('ios', 'iOS apps (build, test, TestFlight)', REPO, 'ios.yml', now,
                    live_label='processed in TestFlight')
    if not p['available']:
        return p, []
    pushes = runs(REPO, 'ios.yml', per_page=DEV_RUNS_TIMED, branch=SHIP_BRANCH, event='push')
    timed, uploads, upload_times = {}, [], []
    for r in pushes:
        if r.get('status') != 'completed':
            continue
        job_list = jobs(REPO, r['id'])
        upload = find_step(job_list, 'Sign, export and upload to TestFlight')
        if not upload or upload.get('conclusion') != 'success':
            continue
        processing = find_job(job_list, 'TestFlight processing')
        processed = processing is not None and processing.get('conclusion') == 'success'
        pushed = ts(r['created_at'])
        entry = {'pushedAt': r['created_at'], 'uploadedAt': upload.get('completed_at'),
                 'uploadSeconds': seconds(pushed, ts(upload.get('completed_at'))),
                 'processed': processed,
                 'processedAt': processing.get('completed_at') if processed else None,
                 'seconds': seconds(pushed, ts(processing.get('completed_at'))) if processed else None}
        timed[r['id']] = entry
        upload_times.append(entry['uploadSeconds'])
        uploads.append((r, entry))
    attach(p, pushes, timed, now)
    p['pushToLive'] = timing([t['seconds'] for t in timed.values()])
    p['pushToUpload'] = timing(upload_times)
    return p, uploads


def attach(p, pushes, timed, now):
    """Put each dev push run's push-to-live on its row, adding the timed runs the latest list missed."""
    shown = {r['id'] for r in p['runs']}
    for r in pushes:
        if r['id'] in timed and r['id'] not in shown:
            p['runs'].append(run_summary(r, now))
    p['runs'].sort(key=lambda r: r['createdAt'] or '', reverse=True)
    for row in p['runs']:
        if row['id'] in timed:
            row['pushToLive'] = timed[row['id']]


def testflight(uploads):
    """The newest uploaded build of each app, from the build-info-apps artifacts of the runs that uploaded."""
    apps = {}
    if not TOKEN:
        return {'available': False, 'reason': 'no token, so the build-info artifacts cannot be downloaded', 'apps': {}}
    for r, entry in uploads:   # newest first
        try:
            arts = get(f'/repos/{REPO}/actions/runs/{r["id"]}/artifacts?per_page=100')['artifacts']
            art = next((a for a in arts if a['name'] == 'build-info-apps' and not a.get('expired')), None)
            if not art:
                continue
            data = download(art['archive_download_url'])
        except (urllib.error.URLError, TimeoutError, KeyError):
            continue
        if not data:
            continue
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            names = z.namelist()
            for name in names:
                m = re.fullmatch(r'([^/]+)/uploaded\.json', name)
                if not m or m.group(1) in apps:
                    continue
                key = m.group(1)
                up = json.loads(z.read(name))
                info = json.loads(z.read(f'{key}/build-info.json')) if f'{key}/build-info.json' in names else {}
                apps[key] = {'app': key, 'bundle': up.get('bundle'), 'version': up.get('version'),
                             'build': str(up.get('build')), 'commit': info.get('commit') or r.get('head_sha'),
                             'uploadedAt': entry['uploadedAt'], 'processed': entry['processed'],
                             'processedAt': entry['processedAt'], 'pushedAt': entry['pushedAt'],
                             'runNumber': r.get('run_number'), 'runUrl': r.get('html_url')}
        if len(apps) >= 4:
            break
    return {'available': True, 'apps': apps}


def release(now):
    p, _ = pipeline('release', 'iOS release (tags and manual runs)', REPO, 'ios-release.yml', now)
    return p


def news(now):
    """PrompTugal.news's deploy: the workflows whose name or file says deploy, pages or release."""
    title = 'PrompTugal.news site deploy'
    try:
        flows = get(f'/repos/{NEWS_REPO}/actions/workflows?per_page=100')['workflows']
    except urllib.error.HTTPError as e:
        return unavailable('news', title, NEWS_REPO, None, f'GitHub answered {e.code} for its workflows')
    except (urllib.error.URLError, TimeoutError) as e:
        return unavailable('news', title, NEWS_REPO, None, f'could not reach GitHub: {e}')
    pick = [w for w in flows if w.get('state') == 'active'
            and re.search(r'deploy|pages|publish|release', f"{w.get('name')} {w.get('path')}", re.I)]
    if not pick:
        return unavailable('news', title, NEWS_REPO, None, 'no workflow named deploy, pages, publish or release')
    pick.sort(key=lambda w: (0 if re.search(r'deploy', w.get('name', ''), re.I) else 1, w.get('path', '')))
    flow = pick[0]
    workflow = flow['path'].split('/')[-1] if flow.get('path', '').startswith('.github/') else flow['id']
    p, latest = pipeline('news', title, NEWS_REPO, workflow, now, live_label='deploy run finished')
    if not p['available']:
        return p
    p['workflowName'] = flow.get('name')
    p['url'] = flow.get('html_url') or p['url']
    done = [r for r in p['runs'] if r['event'] in ('push', 'schedule', 'workflow_dispatch')
            and r['conclusion'] == 'success' and not r['running']]
    for row in done:
        row['pushToLive'] = {'pushedAt': row['createdAt'], 'liveAt': row['finishedAt'],
                             'seconds': seconds(ts(row['createdAt']), ts(row['finishedAt']))}
    p['pushToLive'] = timing([r['pushToLive']['seconds'] for r in done if r['event'] == 'push'])
    return p


def collect():
    now = datetime.now(timezone.utc)
    def safe(fn, pid, title, workflow, repo=REPO):
        try:
            return fn(now)
        except Exception as e:  # noqa: BLE001 - one pipeline's failure leaves the others
            p = unavailable(pid, title, repo, workflow, f'{type(e).__name__}: {e}')
            return (p, []) if fn is ios else p

    site = safe(website, 'website', 'Product site (ios.app.promptugal.news)', 'website.yml')
    app, uploads = safe(ios, 'ios', 'iOS apps (build, test, TestFlight)', 'ios.yml')
    status = {
        'schema': 1,
        'generatedAt': iso(now),
        'generatedBy': (f"{os.environ.get('GITHUB_SERVER_URL', 'https://github.com')}/{REPO}/actions/runs/{os.environ['GITHUB_RUN_ID']}"
                        if os.environ.get('GITHUB_RUN_ID') else 'local'),
        'repo': REPO,
        'shipBranch': SHIP_BRANCH,
        'refreshMinutes': 10,
        'pipelines': [site, app, safe(release, 'release', 'iOS release (tags and manual runs)', 'ios-release.yml'),
                      safe(news, 'news', 'PrompTugal.news site deploy', None, NEWS_REPO)],
        'testflight': testflight(uploads),
    }
    status['apiCalls'] = calls
    return status


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--out', default='-')
    args = parser.parse_args()
    try:
        status = collect()
    except Exception as e:  # noqa: BLE001 - the status file must still be written
        status = {'schema': 1, 'generatedAt': iso(datetime.now(timezone.utc)), 'repo': REPO,
                  'available': False, 'reason': f'{type(e).__name__}: {e}', 'pipelines': [],
                  'testflight': {'available': False, 'apps': {}}}
    text = json.dumps(status, indent=2) + '\n'
    if args.out == '-':
        sys.stdout.write(text)
    else:
        with open(args.out, 'w') as f:
            f.write(text)
        print(f"ci-status: {len(status['pipelines'])} pipelines, {len(status['testflight'].get('apps', {}))} TestFlight apps, "
              f"{status.get('apiCalls', 0)} API calls -> {args.out}", file=sys.stderr)


if __name__ == '__main__':
    main()
