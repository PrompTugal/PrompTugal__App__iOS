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
    meta['slug'] = path.stem
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
    if page['slug'] == 'index':
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
        data = {'@context': 'https://schema.org', '@type': 'WebPage', 'name': page['title'],
                'url': url, 'description': page['description'],
                'isPartOf': {'@type': 'WebSite', 'name': 'PrompTugal for iOS', 'url': SITE_URL}}
    return json.dumps(data, indent=2, ensure_ascii=False)


def build(out):
    facts = app_facts()
    pages = sorted((read_page(p) for p in (WEBSITE / 'pages').glob('*.html')), key=lambda p: int(p['order']))
    template = (WEBSITE / 'template.html').read_text()
    tokens = {k: v for k, v in facts.items() if isinstance(v, str)}
    tokens.update(websites_sidebar=websites_sidebar(facts), websites_list=websites_list(facts),
                  repo_url=REPO_URL, site_url=SITE_URL, site_stamp=site_stamp(facts))

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
    sitemap = []
    for page in pages:
        filename = f"{page['slug']}.html"
        url = SITE_URL if page['slug'] == 'index' else SITE_URL + filename
        body = fill(page['body'], tokens)
        nav = ''.join(
            f'<a href="{p["slug"]}.html"{" aria-current=\"page\"" if p is page else ""}>{p["nav"]}</a>'
            for p in pages if p.get('nav'))
        page_tokens = dict(tokens, title=html.escape(page['title']), description=html.escape(page['description']),
                           canonical=url, nav=nav, body=body, jsonld=json_ld(page, facts, url), slug=page['slug'],
                           twin=f"{page['slug']}.md")
        (out / filename).write_text(fill(template, page_tokens))
        if page.get('twin', 'yes') == 'yes':
            (out / f"{page['slug']}.md").write_text(
                f"<!-- {url} · PrompTugal for iOS {facts['version']} -->\n\n" + to_markdown(body))
            llms.append(f"- [{page['title']}]({SITE_URL}{page['slug']}.md): {page['description']}")
            sitemap.append(f'  <url><loc>{url}</loc></url>')

    llms += ['', '## Source', '', f'- [Source code (Apache-2.0)]({REPO_URL})',
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
