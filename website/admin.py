"""Facts for the product and admin pages, read from the repository at build time.

Nothing here is typed by hand: features are checked against the files that
implement them, the push dashboard is read from the sessions' status pages,
the release history from git tags, the CI page from the workflow files and the
screen list from the app's Destinations.swift. Standard library only.
"""
import html
import json
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STATUS_SECTIONS = ('Done', 'In progress', 'Next', 'Blocked', 'Needs from others')
KIND_LABEL = {'native': 'Native', 'web': 'Web', 'hybrid': 'Native and web'}
esc = html.escape


def plain(text):
    """Markdown from a status page as safe, plain HTML text: links become their text,
    code ticks and emphasis go, and braces are escaped so they never look like build tokens."""
    text = re.sub(r'\[([^\]]+)\]\([^)]*\)', r'\1', text)
    text = re.sub(r'[`*]', '', text)
    return esc(text).replace('{', '&#123;').replace('}', '&#125;')


# --- features --------------------------------------------------------------

def root_scene(root=ROOT):
    """The WindowGroup of the app's @main type: what the app actually shows at launch."""
    for path in sorted(root.glob('PrompTugal/**/*.swift')):
        text = re.sub(r'(?m)^\s*//.*$', '', path.read_text(errors='replace'))
        if '@main' not in text:
            continue
        m = re.search(r'WindowGroup\s*(\([^)]*\))?\s*\{', text)
        if m:
            return text[m.end() - 1:_balanced(text, m.end() - 1, '{}')]
    return ''


def features(root=ROOT):
    """features.json with each feature's status worked out from the files on disk.

    PT_EXTRA_FEATURES (a path to a JSON list of features) adds features for tests, so a
    negative control always has a feature whose evidence does not exist."""
    data = json.loads((root / 'website' / 'features.json').read_text())['features']
    extra = os.environ.get('PT_EXTRA_FEATURES')
    if extra:
        data = data + json.loads(Path(extra).read_text())
    scene = root_scene(root)
    # Screens are reachable only when the shell is the app's root view.
    built = [d for d in destinations(root) if not d['pending']] if 'AppShell(' in scene else []
    screens = {d['id'] for d in built}
    views = set().union(*(d['views'] for d in built)) if built else set()

    def present(evidence):
        if evidence.startswith('screen:'):
            return evidence[len('screen:'):] in screens
        if evidence.startswith('root:'):
            return evidence[len('root:'):] in scene
        if evidence.startswith('view:'):
            return evidence[len('view:'):] in views
        return any(p.is_file() for p in root.glob(evidence))

    for f in data:
        missing = [g for g in f['evidence'] if not present(g)]
        f['shipped'] = not missing
        f['missing'] = missing
    return data


def features_cards(items, platform, shots=None):
    rows = []
    for f in (x for x in items if x['platform'] == platform):
        pic = ''
        if f['shipped'] and shots:
            ids = [e[len('screen:'):] for e in f['evidence'] if e.startswith('screen:')]
            pic = next((shot_img(shots, i, f['name'], device='iphone', width=200) for i in ids
                        if 'iphone' in shots.get(i, {})), '')
        status = 'In the beta' if f['shipped'] else 'Coming'
        cls = 'on' if f['shipped'] else 'soon'
        rows.append(f'<li class="feature" id="f-{esc(f["id"])}">{pic}<h3>{esc(f["name"])}</h3>'
                    f'<p>{esc(f["what"])}</p>'
                    f'<p class="tags"><span class="status {cls}">{status}</span> <span class="sep">·</span> '
                    f'<span class="kind">{KIND_LABEL[f["kind"]]}</span></p></li>')
    return '<ul class="features">' + ''.join(rows) + '</ul>'


def features_table(items, repo_url):
    rows = []
    for f in items:
        status = 'In the beta' if f['shipped'] else 'Coming'
        evidence = ', '.join(f'<code>{esc(g)}</code>' for g in f['evidence'])
        rows.append(f'<tr><td>{esc(f["name"])}</td><td>{"Readers" if f["platform"] == "readers" else "Teams"}</td>'
                    f'<td>{KIND_LABEL[f["kind"]]}</td><td><span class="status {"on" if f["shipped"] else "soon"}">'
                    f'{status}</span></td><td>{evidence}</td></tr>')
    return ('<div class="table-wrap"><table><thead><tr><th scope="col">Feature</th><th scope="col">For</th>'
            '<th scope="col">Built as</th><th scope="col">Status</th><th scope="col">Files that prove it</th>'
            '</tr></thead><tbody>' + ''.join(rows) + '</tbody></table></div>')


def feature_tokens(repo_url, root=ROOT, shots=None):
    items = features(root)
    count = lambda platform, shipped: str(sum(1 for f in items if f['platform'] == platform and f['shipped'] == shipped))
    return {
        'features_readers': features_cards(items, 'readers', shots),
        'features_teams': features_cards(items, 'teams', shots),
        'features_table': features_table(items, repo_url),
        'features_total': str(len(items)),
        'features_shipped': str(sum(f['shipped'] for f in items)),
        'features_readers_shipped': count('readers', True),
        'features_readers_total': str(sum(1 for f in items if f['platform'] == 'readers')),
        'features_teams_shipped': count('teams', True),
        'features_teams_total': str(sum(1 for f in items if f['platform'] == 'teams')),
        'mock_sidebar': mock_sidebar(items),
        **{f'status_{f["id"].replace("-", "_")}': 'in the beta' if f['shipped'] else 'coming' for f in items},
    }


def mock_sidebar(items):
    """The decorative iPad sidebar on the home page: the features in the beta, nothing else."""
    names = [f['name'] for f in items if f['shipped']][:8]
    rows = ''.join(f'<li{" aria-current=\"true\"" if i == 0 else ""}><span>{esc(n)}</span></li>'
                   for i, n in enumerate(names))
    return '<ul class="sidebar-list">' + rows + '</ul>'


# --- git -------------------------------------------------------------------

def git(*args, root=ROOT):
    try:
        out = subprocess.run(['git', *args], cwd=root, capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return ''
    return out.stdout if out.returncode == 0 else ''


def git_ok(*args, root=ROOT):
    try:
        return subprocess.run(['git', *args], cwd=root, capture_output=True, timeout=30).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def releases(root=ROOT):
    """Every v0.1.* tag, newest first, with the changes it released."""
    tags = [t for t in git('tag', '-l', 'v*', '--sort=-v:refname', root=root).split() if re.fullmatch(r'v\d+\.\d+\.\d+', t)]
    out = []
    for i, tag in enumerate(tags):
        date = git('log', '-1', '--format=%cI', tag, root=root).strip()
        previous = tags[i + 1] if i + 1 < len(tags) else ''
        span = f'{previous}..{tag}' if previous else tag
        changes = [line.split(' ', 1) for line in git('log', '--no-merges', '--format=%h %s', span, root=root).splitlines()
                   if line and not line.split(' ', 1)[1].startswith('release: ')]
        out.append({'tag': tag, 'date': date, 'changes': changes})
    return out


def releases_html(items, repo_url):
    if not items:
        return ('<p class="notice">This build has no git tags to read. The deploy workflow fetches the full history, '
                'so the live site lists every release.</p>')
    blocks = []
    for r in items:
        when = r['date'][:16].replace('T', ' ') + ' UTC' if r['date'] else ''
        rows = ''.join(f'<li><a href="{repo_url}/commit/{esc(h)}"><code>{esc(h)}</code></a> {esc(s)}</li>'
                       for h, s in r['changes']) or '<li>No changes besides the version bump.</li>'
        blocks.append(f'<article class="release" id="{esc(r["tag"])}"><h3><a href="{repo_url}/tree/{esc(r["tag"])}">'
                      f'{esc(r["tag"])}</a> <span class="muted">{esc(when)}</span></h3><ul>{rows}</ul></article>')
    return '\n'.join(blocks)


# --- status pages ----------------------------------------------------------

def parse_status(text):
    """A status page: title, summary, and the bullet items under each section."""
    title = re.search(r'^#\s+(.+)$', text, re.M)
    summary = re.search(r'^>\s+(.+)$', text, re.M)
    sections, current = {}, None
    for line in text.splitlines():
        heading = re.match(r'##\s+(.+?)\s*$', line)
        if heading:
            current = heading.group(1).strip()
            sections.setdefault(current, [])
        elif current and re.match(r'([-*]|\d+\.)\s+\S', line):
            sections[current].append(line[2:].strip())
    return {'title': title.group(1).strip() if title else '', 'summary': summary.group(1).strip() if summary else '',
            'sections': sections}


def push_status(root=ROOT, remote='origin'):
    """Every session's status page in the overnight pack.

    A session's own branch (origin/night/<slug>) is newer than dev between merges,
    so when the branch is in this checkout (the deploy fetches every branch) its copy
    of the status page is read instead, with how many commits it is ahead of HEAD.
    Status pages that exist only on a branch are included too, linked to GitHub."""
    out, seen = [], set()
    branches = {line.strip()[len(remote) + len('/night/'):]: line.strip()
                for line in git('branch', '-r', '--format=%(refname:short)', root=root).splitlines()
                if line.strip().startswith(f'{remote}/night/')}
    packs = sorted({p.parent.parent for p in root.glob('briefs/*__overnight-push/status/*.md')})
    for pack in packs:
        rel_pack = pack.relative_to(root).as_posix()
        slugs = {p.stem for p in pack.glob('status/*.md')}
        slugs |= {s for s, ref in branches.items() if git_ok('cat-file', '-e', f'{ref}:{rel_pack}/status/{s}.md', root=root)}
        for slug in sorted(slugs):
            rel = f'{rel_pack}/status/{slug}.md'
            local = root / rel
            text = local.read_text() if local.exists() else ''
            info = {'source': 'dev', 'ahead': None, 'on_site': local.exists()}
            updated = git('log', '-1', '--format=%cI', '--', rel, root=root).strip() if local.exists() else ''
            ref = branches.get(slug)
            if ref:
                info['ahead'] = int(git('rev-list', '--count', f'HEAD..{ref}', root=root).strip() or 0)
                branch_text = git('show', f'{ref}:{rel}', root=root)
                branch_updated = git('log', '-1', '--format=%cI', ref, '--', rel, root=root).strip()
                if branch_text and branch_updated and branch_updated > updated:
                    text, updated, info['source'] = branch_text, branch_updated, f'night/{slug}'
            info.update(parse_status(text))
            info.update(slug=slug, pack=pack.name, updated=updated, branch=ref)
            seen.add(slug)
            out.append(info)
    return out


def push_dashboard(items, repo_url=''):
    if not items:
        return '<p>No status pages yet.</p>'
    head = ''.join(f'<th scope="col">{s}</th>' for s in STATUS_SECTIONS)
    rows = []
    for s in items:
        name = re.sub(r'^Status\s*·\s*', '', s['title']) or s['slug']
        if s['source'] == 'dev' and s['on_site']:
            href = f'briefs/{s["pack"]}/status/{s["slug"]}.html'
        else:
            href = f'{repo_url}/blob/night/{s["slug"]}/briefs/{s["pack"]}/status/{s["slug"]}.md'
        counts = ''.join(f'<td class="n{" warn" if k == "Blocked" and s["sections"].get(k) else ""}">'
                         f'{len(s["sections"].get(k, []))}</td>' for k in STATUS_SECTIONS)
        when = s['updated'][11:16] + ' UTC' if s['updated'] else 'not in git'
        ahead = '' if s['ahead'] is None else str(s['ahead'])
        rows.append(f'<tr><th scope="row"><a href="{href}">{esc(name)}</a></th>{counts}'
                    f'<td>{esc(when)}</td><td><code>{esc(s["source"])}</code></td><td class="n">{ahead}</td>'
                    f'<td>{plain(s["summary"])}</td></tr>')
    return ('<div class="table-wrap"><table class="dash"><thead><tr><th scope="col">Session</th>' + head +
            '<th scope="col">Last change</th><th scope="col">Read from</th><th scope="col">Commits not on dev</th>'
            '<th scope="col">Summary</th></tr></thead><tbody>' + ''.join(rows) + '</tbody></table></div>')


def push_blockers(items):
    rows = []
    for s in items:
        name = re.sub(r'^Status\s*·\s*', '', s['title']) or s['slug']
        for kind in ('Blocked', 'Needs from others'):
            for item in s['sections'].get(kind, []):
                rows.append(f'<li><strong>{esc(name)}</strong> ({kind.lower()}): {plain(item)}</li>')
    return '<ul>' + ''.join(rows) + '</ul>' if rows else '<p>Nothing blocked and nothing asked of others.</p>'


# --- CI --------------------------------------------------------------------

def workflows(root=ROOT):
    """Each workflow file: its name, the comment at the top, triggers, jobs and steps."""
    out = []
    for path in sorted((root / '.github' / 'workflows').glob('*.yml')):
        text = path.read_text()
        name = re.search(r'^name:\s*(.+)$', text, re.M)
        comment = []
        for line in text.splitlines()[1:]:
            if line.startswith('#'):
                comment.append(line.lstrip('#').strip())
            elif comment or line.strip():
                if not line.startswith('#') and comment:
                    break
        triggers = re.search(r'^on:\s*\n((?:[ \t]+.*\n|\s*\n)+)', text, re.M)
        trig = re.findall(r'^  (\w[\w-]*):', triggers.group(1), re.M) if triggers else []
        jobs, current = [], None
        in_jobs = False
        for line in text.splitlines():
            if re.match(r'^jobs:\s*$', line):
                in_jobs = True
                continue
            if in_jobs and re.match(r'^\S', line):
                in_jobs = False
            if not in_jobs:
                continue
            job = re.match(r'^  ([\w-]+):\s*$', line)
            step = re.match(r'^\s+- name:\s*(.+)$', line)
            runs_on = re.match(r'^    runs-on:\s*(.+)$', line)
            if job:
                current = {'id': job.group(1), 'steps': [], 'runs_on': ''}
                jobs.append(current)
            elif step and current:
                current['steps'].append(step.group(1).strip().strip('"\''))
            elif runs_on and current:
                current['runs_on'] = runs_on.group(1).strip()
        out.append({'file': path.name, 'name': name.group(1).strip() if name else path.stem,
                    'comment': '\n'.join(comment).strip(), 'triggers': trig, 'jobs': jobs})
    return out


def workflows_html(items, repo_url):
    if not items:
        return '<p>No workflows found.</p>'
    blocks = []
    for w in items:
        jobs = ''.join(f'<li><strong>{esc(j["id"])}</strong>'
                       f'{" on <code>" + esc(j["runs_on"]) + "</code>" if j["runs_on"] else ""}'
                       f'<ol>{"".join("<li>" + esc(s) + "</li>" for s in j["steps"])}</ol></li>' for j in w['jobs'])
        comment = f'<pre><code>{esc(w["comment"])}</code></pre>' if w['comment'] else ''
        blocks.append(f'<article class="card" id="wf-{esc(Path(w["file"]).stem)}"><h3>{esc(w["name"])} '
                      f'<a class="muted" href="{repo_url}/blob/dev/.github/workflows/{esc(w["file"])}">'
                      f'<code>{esc(w["file"])}</code></a></h3>'
                      f'<p>Runs on: {", ".join("<code>" + esc(t) + "</code>" for t in w["triggers"]) or "not stated"}. '
                      f'{len(w["jobs"])} jobs, {sum(len(j["steps"]) for j in w["jobs"])} named steps.</p>'
                      f'{comment}<ol class="jobs">{jobs}</ol></article>')
    # GitHub expressions such as ${{ matrix.device }} are shown as ‹matrix.device›, so they
    # never look like an unfilled build token to the validator (or to a reader).
    return re.sub(r'\$\{\{\s*(.*?)\s*\}\}', r'‹\1›', '\n'.join(blocks))


# --- screens ---------------------------------------------------------------

def _balanced(text, start, pair='()'):
    """The index just past the bracket that closes the one at text[start]."""
    depth = 0
    for i in range(start, len(text)):
        if text[i] == pair[0]:
            depth += 1
        elif text[i] == pair[1]:
            depth -= 1
            if depth == 0:
                return i + 1
    return len(text)


def destinations(root=ROOT):
    """Destination(...) registrations in the app's Shell, in source order.

    Comments are ignored. Each registration is its call plus a trailing closure, if
    any. A screen whose view is a PendingFeatureView is registered but not built yet."""
    out = []
    for path in sorted(root.glob('PrompTugal/**/Destinations.swift')):
        out += parse_destinations(path.read_text(), path.relative_to(root).as_posix())
    return out


def branch_destinations(root=ROOT, remote='origin'):
    """Screens registered on night/* branches that dev does not have yet, or has differently."""
    on_dev = {d['id']: d for d in destinations(root)}
    out = []
    for ref in git('branch', '-r', '--format=%(refname:short)', root=root).split():
        if not ref.startswith(f'{remote}/night/'):
            continue
        files = [f for f in git('ls-tree', '-r', '--name-only', ref, 'PrompTugal', root=root).splitlines()
                 if f.endswith('/Destinations.swift')]
        for f in files:
            for d in parse_destinations(git('show', f'{ref}:{f}', root=root), f):
                old = on_dev.get(d['id'])
                if old is None or (old['pending'] and not d['pending']) or old['kind'] != d['kind']:
                    d['branch'] = ref[len(remote) + 1:]
                    d['change'] = 'new' if old is None else ('built' if old['pending'] and not d['pending'] else 'changed')
                    out.append(d)
    return out


def parse_destinations(source, file=''):
    """The registrations in one Destinations.swift source text."""
    out = []
    if True:
        text = re.sub(r'/\*.*?\*/', '', source, flags=re.S)
        text = re.sub(r'(?m)^\s*//.*$', '', text)
        for m in re.finditer(r'\b(?:App)?Destination\((?=\s*id:\s*")', text):
            end = _balanced(text, m.end() - 1)
            closure = re.match(r'\s*\{', text[end:])
            if closure:
                end = _balanced(text, end + closure.end() - 1, '{}')
            body = text[m.end():end]
            ident = re.match(r'\s*id:\s*"([^"]+)"', body).group(1)
            title = re.search(r'title:\s*"([^"]+)"', body)
            section = re.search(r'section:\s*\.(\w+)', body)
            kind = re.search(r'kind:\s*\.(\w+)', body)
            web = re.search(r'kind:\s*\.web(?=\()', body)
            target = body[web.end() + 1:_balanced(body, web.end()) - 1] if web else ''
            url = re.search(r'"(https://[^"]+)"', target)
            out.append({'id': ident, 'title': title.group(1) if title else ident,
                        'section': section.group(1) if section else '', 'kind': kind.group(1) if kind else '',
                        'url': url.group(1) if url else re.sub(r'\s+', ' ', target).strip(),
                        'pending': 'PendingFeatureView' in body,
                        'views': set(re.findall(r'\b([A-Z]\w*View)\(', body)) - {'AnyView', 'PendingFeatureView'},
                        'file': file})
    return out


def branch_screens_html(items):
    if not items:
        return '<p>No session branch registers a screen that <code>dev</code> does not already have.</p>'
    rows = ''.join(f'<tr><td>{esc(d["title"])}</td><td><code>{esc(d["id"])}</code></td>'
                   f'<td><span class="kind">{esc(KIND_LABEL.get(d["kind"], d["kind"] or "?"))}</span></td>'
                   f'<td>{"placeholder" if d["pending"] else "built"}</td><td>{esc(d["change"])}</td>'
                   f'<td><code>{esc(d["branch"])}</code></td></tr>' for d in items)
    return (f'<p>{len(items)} screens are new or changed on session branches and reach the app when the conductor '
            'merges them.</p><div class="table-wrap"><table><thead><tr><th scope="col">Screen</th><th scope="col">id</th>'
            '<th scope="col">Built as</th><th scope="col">State</th><th scope="col">Compared with dev</th>'
            '<th scope="col">Branch</th></tr></thead><tbody>' + rows + '</tbody></table></div>')


def screens_html(items, websites):
    if items:
        counts = {k: sum(1 for d in items if d['kind'] == k) for k in ('native', 'web', 'hybrid')}
        pending = sum(1 for d in items if d['pending'])
        rows = ''.join(f'<tr><td>{esc(d["title"])}</td><td><code>{esc(d["id"])}</code></td><td>{esc(d["section"])}</td>'
                       f'<td><span class="kind">{esc(KIND_LABEL.get(d["kind"], d["kind"] or "?"))}</span></td>'
                       f'<td>{"placeholder" if d["pending"] else "built"}</td>'
                       f'<td>{"<code>" + esc(d["url"]) + "</code>" if d["url"] else ""}</td></tr>' for d in items)
        table = (f'<p>{len(items)} screens registered: {counts["native"]} native, {counts["web"]} web, '
                 f'{counts["hybrid"]} native and web. {pending} of them are placeholders for a feature that '
                 'another session has not merged yet.</p><div class="table-wrap"><table><thead><tr>'
                 '<th scope="col">Screen</th><th scope="col">id</th><th scope="col">Section</th>'
                 '<th scope="col">Built as</th><th scope="col">State</th><th scope="col">Web address</th></tr></thead><tbody>'
                 + rows + '</tbody></table></div>')
    else:
        table = ('<p class="notice">No <code>Destinations.swift</code> on this branch yet. The app has one native '
                 'screen, the offline reader, and opens websites in the sidebar below.</p>')
    sites = ''.join(f'<tr><td>{esc(s["name"])}</td><td><code>{esc(s["url"])}</code></td></tr>' for s in websites)
    return (table + '<h3>Websites in the sidebar</h3><p>From <code>PrompTugal/Websites.json</code>, the defaults the '
            'app ships with. Users can edit the list in the Files app.</p><div class="table-wrap"><table><thead><tr>'
            '<th scope="col">Name</th><th scope="col">Address</th></tr></thead><tbody>' + sites + '</tbody></table></div>')


def areas_html(areas):
    rows = ''.join(f'<tr><td><code>{esc(a)}</code></td><td class="n">{n}</td><td class="n">{lines:,}</td></tr>'
                   for a, (n, lines) in sorted(areas.items()))
    return ('<div class="table-wrap"><table><thead><tr><th scope="col">Folder</th><th scope="col">Swift files</th>'
            '<th scope="col">Lines</th></tr></thead><tbody>' + rows + '</tbody></table></div>')


# --- latest iOS build (from scripts/release/latest-build.sh) ----------------

def latest_build(path):
    """The JSON latest-build.sh wrote, or None when there is none or it does not parse."""
    if not path:
        return None
    try:
        data = json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return None
    return data if isinstance(data, dict) and data.get('available') else None


def _size(n):
    try:
        n = int(n)
    except (TypeError, ValueError):
        return '?'
    return f'{n / 1_048_576:.1f} MB' if n >= 1_048_576 else f'{round(n / 1024):,} KB'


def _xcode(value):
    """DTXcode as Apple writes it ("2660") to a version ("26.6")."""
    text = str(value or '?')
    if re.fullmatch(r'\d{4}', text):
        major, minor, patch = int(text[:2]), int(text[2]), int(text[3])
        return f'{major}.{minor}' + (f'.{patch}' if patch else '')
    return text


def latest_build_html(data, repo_url):
    if not data:
        return ('<p class="notice">No CI build information in this site build. The site build asks for the latest '
                'successful iOS release run on <code>dev</code>; it shows here once there is one.</p>')
    devices = {1: 'iPhone', 2: 'iPad'}
    family = ' and '.join(devices.get(d, str(d)) for d in data.get('deviceFamily', [])) or '?'
    commit = str(data.get('commit', ''))[:7]
    built = str(data.get('builtAt', ''))[:16].replace('T', ' ')
    run = data.get('runUrl') or data.get('run') or ''
    rows = [('App version', f'{esc(str(data.get("version", "?")))} (build {esc(str(data.get("build", "?")))})'),
            ('Commit', f'<a href="{repo_url}/commit/{esc(commit)}"><code>{esc(commit)}</code></a>' if commit else '?'),
            ('Built', f'{esc(built)} UTC' if built else '?'),
            ('Devices', esc(family)),
            ('Minimum iOS', esc(str(data.get('minimumOS', '?')))),
            ('Xcode and SDK', f'{esc(_xcode(data.get("xcode")))}, {esc(str(data.get("sdk", "?")))}'),
            ('Sizes', f'app {_size(data.get("appBytes"))}, unsigned .ipa {_size(data.get("ipaBytes"))}'),
            ('Run', f'<a href="{esc(run)}">{esc(run.rsplit("/", 1)[-1])}</a>' if run.startswith('https://') else '?')]
    arts = ''.join(f'<li><code>{esc(str(a.get("name", "")))}</code> ({_size(a.get("size"))})</li>'
                   for a in data.get('artifacts', []) if isinstance(a, dict))
    table = ''.join(f'<div><dt>{k}</dt><dd>{v}</dd></div>' for k, v in rows)
    return (f'<dl class="kv">{table}</dl>'
            + (f'<p>Artifacts of that run (GitHub keeps them for a limited time):</p><ul>{arts}</ul>' if arts else ''))


# --- screenshots (from the screens workflow's artifact) ---------------------

DEVICES = {'iphone': 'iPhone', 'ipad': 'iPad'}


def png_size(path):
    """Width and height from a PNG's IHDR chunk, or None if it is not a PNG."""
    try:
        with open(path, 'rb') as f:
            head = f.read(24)
    except OSError:
        return None
    if len(head) < 24 or head[:8] != b'\x89PNG\r\n\x1a\n' or head[12:16] != b'IHDR':
        return None
    return int.from_bytes(head[16:20], 'big'), int.from_bytes(head[20:24], 'big')


def screen_devices(root=ROOT):
    """The devices whose screenshots the site publishes (website/screens.json)."""
    try:
        return set(json.loads((root / 'website' / 'screens.json').read_text())['devices']) & set(DEVICES)
    except (OSError, ValueError, KeyError):
        return set(DEVICES)


def screenshots(folder, devices=None):
    """{screen id: {device: (source path, width, height)}} from files named <device>-<id>.png,
    for the devices the site publishes."""
    out = {}
    devices = screen_devices() if devices is None else devices
    if not folder or not Path(folder).is_dir():
        return out
    for path in sorted(Path(folder).rglob('*.png')):
        device, _, ident = path.stem.partition('-')
        device = device.lower()
        size = png_size(path)
        if device in devices and ident and size:
            out.setdefault(ident, {})[device] = (path, *size)
    return out


def shot_name(device, ident):
    return f'screens/{device}-{re.sub(r"[^A-Za-z0-9._-]", "_", ident)}.png'


def shot_img(shots, ident, title, root='', device=None, width=None):
    """One <img> for a screen (iPhone first, else iPad), at its true size scaled to width."""
    entry = shots.get(ident, {})
    for d in ([device] if device else ['iphone', 'ipad']):
        if d in entry:
            _, w, h = entry[d]
            shown_w = width or w
            shown_h = round(h * shown_w / w)
            return (f'<img class="shot shot-{d}" src="{root}{shot_name(d, ident)}" '
                    f'alt="{esc(title)} on {DEVICES[d]}, a screenshot of the app" width="{shown_w}" height="{shown_h}" '
                    f'loading="lazy" data-png-width="{w}" data-png-height="{h}">')
    return ''


def screens_gallery(items, shots, root='../'):
    if not shots:
        return ('<p class="notice">No screenshots in this site build. When the app’s screens workflow has run on '
                '<code>dev</code>, the site shows every screen on iPhone and iPad here.</p>')
    cards = []
    missing = [d for d in items if d['id'] not in shots]
    for d in (x for x in items if x['id'] in shots):
        pics = ''.join(shot_img(shots, d['id'], d['title'], root=root, device=dev, width=240 if dev == 'iphone' else 360)
                       for dev in DEVICES if dev in shots.get(d['id'], {}))
        body = pics or '<p class="muted">No screenshot of this screen yet.</p>'
        cards.append(f'<figure class="card shot-card" id="shot-{esc(d["id"])}"><div class="shots">{body}</div>'
                     f'<figcaption><strong>{esc(d["title"])}</strong> <code>{esc(d["id"])}</code></figcaption></figure>')
    have = len(items) - len(missing)
    rest = ('<p class="muted">No screenshot yet: ' + ', '.join(f'{esc(d["title"])} (<code>{esc(d["id"])}</code>)'
                                                     for d in missing) + '.</p>') if missing else ''
    return (f'<p>{have} of {len(items)} screens have a screenshot, taken by CI on a simulator from the code on '
            '<code>dev</code>.</p><div class="gallery">' + ''.join(cards) + '</div>' + rest)
