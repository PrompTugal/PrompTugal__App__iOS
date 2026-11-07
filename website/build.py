#!/usr/bin/env python3
"""Build the ios.app.promptugal.news product site into website/public/.

One template, one source file per page. Every fact about the app (version,
build, minimum iOS, the bundled websites, the size of the code base) is read
from the Xcode project at build time, never typed by hand. Each HTML page gets
a Markdown twin at the same path for agents, and llms.txt and sitemap.xml list
every page.

Standard library only. Usage: python3 website/build.py [--out DIR]
The release version comes from /VERSION; CI sets SITE_COMMIT to stamp the commit.
"""
import argparse
import html
import json
import os
import re
import shutil
from html.parser import HTMLParser
from pathlib import Path

import markdown
import version

SITE_URL = 'https://ios.app.promptugal.news/'
REPO_URL = 'https://github.com/PrompTugal/PrompTugal__App__iOS'

WEBSITE = Path(__file__).resolve().parent
ROOT = WEBSITE.parent
APP = ROOT / 'PrompTugal'
PROJECT = ROOT / 'PrompTugal.xcodeproj' / 'project.pbxproj'
ASSETS = APP / 'Assets.xcassets'

# Published path -> source file in the Xcode asset catalog (artwork exists once).
IMAGES = {
    'assets/app-icon.png': ASSETS / 'AppIcon.appiconset' / 'AppIcon.png',
    'assets/shortcut-ShortcutPrompTugal.png': ASSETS / 'ShortcutPrompTugal.imageset' / 'Icon.png',
    'assets/shortcut-ShortcutWebSummit.png': ASSETS / 'ShortcutWebSummit.imageset' / 'Icon.png',
    'assets/shortcut-ShortcutRiskMandate.png': ASSETS / 'ShortcutRiskMandate.imageset' / 'Icon.png',
}

# Websites.json colour names -> CSS colours close to the iOS system tints.
TINTS = {'red': '#d93a33', 'orange': '#e8870e', 'green': '#2f9e44', 'teal': '#2a9fb0',
         'blue': '#2f6fdb', 'indigo': '#5856d6', 'purple': '#9b51c9'}


def project_setting(name):
    """The single value of a build setting, refusing if configurations disagree."""
    values = set(re.findall(rf'\b{name} = "?([^";]+)"?;', PROJECT.read_text()))
    if len(values) != 1:
        raise SystemExit(f'build: expected one value for {name} in project.pbxproj, found {sorted(values)}')
    return values.pop()


def app_facts():
    swift = sorted(APP.glob('*.swift'))
    websites = json.loads((APP / 'Websites.json').read_text())
    return {
        'version': project_setting('MARKETING_VERSION'),
        'build': project_setting('CURRENT_PROJECT_VERSION'),
        'min_ios': project_setting('IPHONEOS_DEPLOYMENT_TARGET'),
        'bundle_id': project_setting('PRODUCT_BUNDLE_IDENTIFIER'),
        'swift_files': str(len(swift)),
        'swift_lines': f'{sum(len(f.read_text().splitlines()) for f in swift):,}',
        'site_count': str(len(websites)),
        'websites': websites,
        'release': version.read(),
        'site_commit': os.environ.get('SITE_COMMIT', '')[:7],
    }


def badge(site):
    """Sidebar artwork as the app draws it: bundled image, else a text badge."""
    tint = TINTS.get(site['color'], 'var(--red)')
    if site.get('iconAsset'):
        src = f"assets/shortcut-{site['iconAsset']}.png"
        if src not in IMAGES:
            raise SystemExit(f"build: no published image for iconAsset {site['iconAsset']}")
        return f'<img class="badge" src="{src}" alt="" width="40" height="40">'
    text = html.escape(site.get('iconText') or site['name'][:2]).replace('\n', '<br>')
    return f'<span class="badge badge-text" style="--tint:{tint}" aria-hidden="true" data-md-skip>{text}</span>'


def websites_sidebar(facts):
    rows = []
    for i, site in enumerate(facts['websites']):
        current = ' aria-current="true"' if i == 0 else ''
        rows.append(f'<li{current}>{badge(site)}<span>{html.escape(site["name"])}</span></li>')
    return '<ul class="sidebar-list">' + ''.join(rows) + '</ul>'


def websites_list(facts):
    rows = []
    for site in facts['websites']:
        url = html.escape(site['url'])
        host = html.escape(site['url'].split('://', 1)[-1].rstrip('/'))
        rows.append(f'<li>{badge(site)}<a href="{url}">{host}</a></li>')
    return '<ul class="site-list">' + ''.join(rows) + '</ul>'


def site_stamp(facts):
    commit = facts['site_commit']
    if not commit:
        return f"Release {facts['release']} (local build)."
    return f'Release <a href="{REPO_URL}/tree/{facts["release"]}">{facts["release"]}</a>, commit <a href="{REPO_URL}/commit/{commit}">{commit}</a>.'


def read_page(path):
    """Split a page source into its front matter (an HTML comment) and body."""
    match = re.match(r'<!--\n(.*?)\n-->\n', path.read_text(), re.S)
    if not match:
        raise SystemExit(f'build: {path.name} has no front-matter comment')
    meta = dict(line.split(': ', 1) for line in match.group(1).splitlines())
    meta['body'] = path.read_text()[match.end():]
    meta['path'] = path.relative_to(WEBSITE / 'pages').as_posix()
    meta['slug'] = meta['path'][:-5]
    meta['noindex'] = meta.get('robots') == 'noindex'
    return meta


def fill(text, tokens):
    def swap(match):
        if match.group(1) not in tokens:
            raise SystemExit(f'build: unknown token {{{{{match.group(1)}}}}}')
        return tokens[match.group(1)]
    return re.sub(r'\{\{(\w+)\}\}', swap, text)


class MarkdownTwin(HTMLParser):
    """Turns a page body into Markdown. Handles only the tags the pages use."""
    BLOCKS = {'p', 'li', 'h1', 'h2', 'h3', 'pre', 'dt', 'dd', 'figcaption'}
    VOID = {'img', 'br', 'hr', 'meta', 'source'}

    def __init__(self):
        super().__init__()
        self.out, self.line, self.href, self.skip, self.lists, self.pre = [], '', [], 0, [], False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in self.VOID and (self.skip or 'data-md-skip' in attrs):
            return
        if self.skip or 'data-md-skip' in attrs:
            self.skip += 1
            return
        if tag in ('ul', 'ol'):
            self.lists.append([tag, 0])
        elif tag == 'li':
            kind = self.lists[-1] if self.lists else ['ul', 0]
            kind[1] += 1
            self.line = f'{kind[1]}. ' if kind[0] == 'ol' else '- '
        elif tag in ('h1', 'h2', 'h3'):
            self.line = '#' * int(tag[1]) + ' '
        elif tag == 'pre':
            self.pre = True
            self.line = '```\n'
        elif tag == 'dt':
            self.line = '**'
        elif tag == 'a':
            self.href.append(attrs.get('href', ''))
            self.line += '['
        elif tag == 'code' and not self.pre:
            self.line += '`'
        elif tag == 'strong':
            self.line += '**'
        elif tag == 'br':
            self.line += '  \n'

    def handle_endtag(self, tag):
        if self.skip:
            self.skip -= 1
            return
        if tag == 'a' and self.href:
            href = self.href.pop()
            if href.endswith('.html') and '://' not in href:
                href = href[:-5] + '.md'
            self.line += f']({href})'
        elif tag == 'code' and not self.pre:
            self.line += '`'
        elif tag == 'strong':
            self.line += '**'
        elif tag == 'dt':
            self.line += '**'
        elif tag in ('ul', 'ol') and self.lists:
            self.lists.pop()
            self.out.append('')
        if tag == 'pre':
            self.line = self.line.rstrip('\n') + '\n```'
            self.pre = False
        if tag in self.BLOCKS:
            self.out.append(self.line.strip(' ') if not tag == 'pre' else self.line)
            if tag not in ('li', 'dt'):
                self.out.append('')
            self.line = ''

    def handle_data(self, data):
        if self.skip:
            return
        self.line += data if self.pre else re.sub(r'\s+', ' ', data)

    def markdown(self):
        text = '\n'.join(self.out)
        return re.sub(r'\n{3,}', '\n\n', text).strip() + '\n'


def to_markdown(body):
    parser = MarkdownTwin()
    parser.feed(body)
    return parser.markdown()


def json_ld(page, facts, url):
    if page['path'] == 'index.html':
        data = {
            '@context': 'https://schema.org', '@type': 'MobileApplication',
            'name': 'PrompTugal', 'operatingSystem': f"iOS {facts['min_ios']}, iPadOS {facts['min_ios']}",
            'applicationCategory': 'NewsApplication', 'softwareVersion': facts['version'],
            'url': url, 'image': SITE_URL + 'assets/app-icon.png', 'description': page['description'],
            'offers': {'@type': 'Offer', 'price': '0', 'priceCurrency': 'EUR'},
            'publisher': {'@type': 'Organization', 'name': 'PrompTugal.news', 'url': 'https://promptugal.news/'},
            'codeRepository': REPO_URL,
        }
    else:
        kind = 'TechArticle' if page.get('kind') == 'brief' else 'WebPage'
        data = {'@context': 'https://schema.org', '@type': kind, 'name': page['title'],
                'url': url, 'description': page['description'],
                'isPartOf': {'@type': 'WebSite', 'name': 'PrompTugal for iOS', 'url': SITE_URL}}
    return json.dumps(data, indent=2, ensure_ascii=False)


def brief_link(source, briefs):
    """Rewrite a link inside a brief: other briefs -> their page, repo files -> GitHub."""
    def link(href):
        if '://' in href or href.startswith(('#', 'mailto:')):
            return href
        target, _, fragment = href.partition('#')
        resolved = (source.parent / target).resolve()
        suffix = f'#{fragment}' if fragment else ''
        if resolved.suffix == '.md' and resolved.is_relative_to(briefs) and resolved.exists():
            out = resolved.with_name('index.html' if resolved.name == 'README.md' else resolved.stem + '.html')
            here = source.with_name('index.html' if source.name == 'README.md' else source.stem + '.html')
            return os.path.relpath(out, here.parent) + suffix
        if resolved.is_relative_to(ROOT) and resolved.exists():
            return f'{REPO_URL}/blob/dev/{resolved.relative_to(ROOT).as_posix()}{suffix}'
        return href
    return link


def read_briefs():
    """Every brief pack under /briefs becomes pages under admin/briefs/."""
    briefs, pages = ROOT / 'briefs', []
    for source in sorted(briefs.rglob('*.md')):
        text = source.read_text()
        title, summary = markdown.title_and_summary(text)
        rel = source.relative_to(briefs)
        name = 'index' if source.name == 'README.md' else source.stem
        path = (Path('admin/briefs') / rel.parent / f'{name}.html').as_posix()
        pages.append({'path': path, 'title': title, 'description': summary, 'noindex': True, 'kind': 'brief',
                      'body': '<article class="band"><div class="wrap prose brief">\n'
                              + markdown.render(text, brief_link(source, briefs)) + '\n</div></article>',
                      'twin_text': text, 'source': rel.as_posix()})
    return pages


def brief_packs(pages):
    """The admin index's list of packs and the briefs in each."""
    packs = {}
    for page in pages:
        if page.get('kind') == 'brief':
            packs.setdefault(page['path'].split('/')[2], []).append(page)
    blocks = []
    for pack, items in sorted(packs.items(), reverse=True):
        items.sort(key=lambda p: (not p['path'].endswith('/index.html'), p['path']))
        head, rest = items[0], items[1:]
        rel = lambda p: p['path'][len('admin/'):]
        rows = ''.join(f'<li><a href="{rel(p)}">{html.escape(p["title"])}</a><span>{html.escape(p["description"])}</span></li>'
                       for p in rest)
        blocks.append(f'<article class="card pack"><h3><a href="{rel(head)}">{html.escape(head["title"])}</a></h3>'
                      f'<p>{html.escape(head["description"])}</p><ol class="brief-list">{rows}</ol></article>')
    return '\n'.join(blocks) or '<p>No briefs yet.</p>'


def build(out):
    facts = app_facts()
    sources = sorted((WEBSITE / 'pages').rglob('*.html'))
    pages = sorted((read_page(p) for p in sources), key=lambda p: int(p['order'])) + read_briefs()
    template = (WEBSITE / 'template.html').read_text()
    tokens = {k: v for k, v in facts.items() if isinstance(v, str)}
    tokens.update(websites_sidebar=websites_sidebar(facts), websites_list=websites_list(facts),
                  repo_url=REPO_URL, site_url=SITE_URL, site_stamp=site_stamp(facts), brief_packs=brief_packs(pages))

    if out.exists():
        shutil.rmtree(out)
    (out / 'assets').mkdir(parents=True)
    shutil.copy(WEBSITE / 'site.css', out / 'assets' / 'site.css')
    for published, source in IMAGES.items():
        shutil.copy(source, out / published)

    llms = ['# PrompTugal for iOS', '',
            f"> PrompTugal {facts['version']} for iPhone and iPad: the PrompTugal.news newsroom and "
            f"the sites around it ({facts['site_count']} websites) in one app, with an offline reader for the "
            'Web Summit Lisbon agenda. Independent of Web Summit.', '', '## Pages', '']
    llms_team = ['', '## For the team: developer area and briefs', '']
    sitemap = []
    for page in pages:
        path = page['path']
        root = '../' * path.count('/')
        url = SITE_URL + ('' if path == 'index.html' else path)
        twin = Path(path).with_suffix('.md').name
        body = fill(page['body'], tokens) if page.get('kind') != 'brief' else page['body']
        nav = ''.join(
            f'<a href="{root}{p["path"]}"{" aria-current=\"page\"" if p is page else ""}>{p["nav"]}</a>'
            for p in pages if p.get('nav'))
        robots = '<meta name="robots" content="noindex">' if page.get('noindex') else ''
        page_tokens = dict(tokens, title=html.escape(page['title']), description=html.escape(page['description']),
                           canonical=url, nav=nav, body=body, jsonld=json_ld(page, facts, url),
                           twin=twin, root=root, robots=robots)
        target = out / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(fill(template, page_tokens))
        twin_text = page.get('twin_text') or to_markdown(body)
        target.with_suffix('.md').write_text(f"<!-- {url} · PrompTugal for iOS {facts['version']} -->\n\n" + twin_text)
        entry = f"- [{page['title']}]({SITE_URL}{Path(path).with_suffix('.md').as_posix()}): {page['description']}"
        (llms_team if path.startswith('admin/') else llms).append(entry)
        if not page.get('noindex'):
            sitemap.append(f'  <url><loc>{url}</loc></url>')

    llms += llms_team + ['', '## Source', '', f'- [Source code (Apache-2.0)]({REPO_URL})',
                         '- [PrompTugal.news](https://promptugal.news/llms.txt): the newsroom the app reads', '']
    (out / 'llms.txt').write_text('\n'.join(llms))
    (out / 'sitemap.xml').write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        + '\n'.join(sitemap) + '\n</urlset>\n')
    (out / 'robots.txt').write_text(f'User-agent: *\nAllow: /\nSitemap: {SITE_URL}sitemap.xml\n')
    (out / 'version.json').write_text(json.dumps(
        {key: facts[key] for key in ('release', 'version', 'build', 'site_commit')}, indent=2) + '\n')
    return facts, pages


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--out', type=Path, default=WEBSITE / 'public')
    args = parser.parse_args()
    facts, pages = build(args.out)
    print(f"built {len(pages)} pages for PrompTugal {facts['version']} into {args.out}")


if __name__ == '__main__':
    main()
