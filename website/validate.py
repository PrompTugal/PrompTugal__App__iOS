#!/usr/bin/env python3
"""Refuse a built site that breaks the rules. Exit 1 with one line per problem.

Checks every page in the output directory:
  * internal links and images resolve, and every page is reachable from the home page
  * every page has a Markdown twin listed in llms.txt and sitemap.xml
  * JSON-LD parses, and the home page's softwareVersion matches the Xcode project
  * every website in Websites.json is on the home page
  * no scripts other than JSON-LD, no external stylesheets, no inline event handlers
  * one <h1>, a lang, a title and a description; every <img> has alt, width and height
  * no build tokens left behind and no banned words

Standard library only. Usage: python3 website/validate.py [DIR]
"""
import json
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urldefrag, urlparse

WEBSITE = Path(__file__).resolve().parent
ROOT = WEBSITE.parent
BANNED = ('seamless', 'revolutionary', 'cutting-edge', 'game-changing', 'game changer', 'effortless',
          'blazing', 'unleash', 'world-class', 'best-in-class', 'supercharge', 'lorem ipsum', 'todo')


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links, self.images, self.ids, self.scripts, self.problems = [], [], set(), [], []
        self.h1 = 0
        self.lang = self.title = self.description = None
        self._script = None
        self._title = False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if 'id' in a:
            self.ids.add(a['id'])
        for name in a:
            if name.startswith('on'):
                self.problems.append(f'inline event handler {name} on <{tag}>')
        if tag == 'html':
            self.lang = a.get('lang')
        elif tag == 'title':
            self._title = True
        elif tag == 'meta' and a.get('name') == 'description':
            self.description = a.get('content')
        elif tag == 'h1':
            self.h1 += 1
        elif tag == 'a' and 'href' in a:
            self.links.append(a['href'])
        elif tag == 'link' and a.get('rel') == 'stylesheet':
            if urlparse(a.get('href', '')).scheme:
                self.problems.append(f"external stylesheet {a['href']}")
            self.links.append(a.get('href', ''))
        elif tag == 'img':
            self.images.append(a.get('src', ''))
            for need in ('alt', 'width', 'height'):
                if a.get(need) is None:
                    self.problems.append(f"<img src={a.get('src')}> has no {need}")
        elif tag == 'script':
            if a.get('type') != 'application/ld+json' or 'src' in a:
                self.problems.append('a script that is not inline JSON-LD')
            self._script = ''

    def handle_endtag(self, tag):
        if tag == 'script' and self._script is not None:
            self.scripts.append(self._script)
            self._script = None
        elif tag == 'title':
            self._title = False

    def handle_data(self, data):
        if self._script is not None:
            self._script += data
        elif self._title:
            self.title = (self.title or '') + data


def project_version():
    text = (ROOT / 'PrompTugal.xcodeproj' / 'project.pbxproj').read_text()
    return set(re.findall(r'MARKETING_VERSION = ([^;]+);', text))


def validate(out):
    problems = []
    pages = {p.name: p for p in sorted(out.glob('*.html'))}
    if 'index.html' not in pages:
        return ['no index.html']
    parsed = {}
    for name, path in pages.items():
        text = path.read_text()
        page = Page()
        page.feed(text)
        parsed[name] = page
        problems += [f'{name}: {p}' for p in page.problems]
        if page.h1 != 1:
            problems.append(f'{name}: has {page.h1} <h1> elements, wants 1')
        for field in ('lang', 'title', 'description'):
            if not getattr(page, field):
                problems.append(f'{name}: no {field}')
        if '{{' in text or '}}' in text:
            problems.append(f'{name}: a build token was left unfilled')
        visible = re.sub(r'<[^>]+>', ' ', text).lower()
        for word in BANNED:
            if re.search(rf'\b{re.escape(word)}\b', visible):
                problems.append(f'{name}: banned word "{word}"')
        for block in page.scripts:
            try:
                json.loads(block)
            except ValueError as exc:
                problems.append(f'{name}: JSON-LD does not parse ({exc})')
        if not page.scripts:
            problems.append(f'{name}: no JSON-LD')

    # Links, anchors and images
    for name, page in parsed.items():
        for href in page.links + page.images:
            url = urlparse(href)
            if url.scheme or href.startswith('//') or href.startswith('mailto:'):
                if url.scheme == 'http':
                    problems.append(f'{name}: insecure link {href}')
                continue
            target, fragment = urldefrag(href)
            target = target or name
            if not (out / target).exists():
                problems.append(f'{name}: broken link {href}')
            elif fragment and target.endswith('.html') and fragment not in parsed.get(target, Page()).ids:
                problems.append(f'{name}: no #{fragment} in {target}')

    # Every page reachable from the home page
    seen, queue = set(), ['index.html']
    while queue:
        current = queue.pop()
        if current in seen or current not in parsed:
            continue
        seen.add(current)
        queue += [urldefrag(h)[0] for h in parsed[current].links if h.endswith('.html') or '.html#' in h]
    for name in sorted(set(parsed) - seen):
        problems.append(f'{name}: not reachable from index.html')

    # Agent surface
    llms = (out / 'llms.txt').read_text() if (out / 'llms.txt').exists() else ''
    sitemap = (out / 'sitemap.xml').read_text() if (out / 'sitemap.xml').exists() else ''
    for name in parsed:
        twin = name[:-5] + '.md'
        if not (out / twin).exists():
            problems.append(f'{name}: no Markdown twin {twin}')
        elif twin not in llms:
            problems.append(f'{name}: {twin} is not listed in llms.txt')
        loc = '' if name == 'index.html' else name
        if f'/{loc}</loc>' not in sitemap:
            problems.append(f'{name}: not in sitemap.xml')

    # Facts must match the app
    versions = project_version()
    home = parsed['index.html']
    app = next((json.loads(s) for s in home.scripts if '"softwareVersion"' in s), {})
    if {app.get('softwareVersion')} != versions:
        problems.append(f"index.html: softwareVersion {app.get('softwareVersion')} != project {sorted(versions)}")
    home_text = pages['index.html'].read_text()
    for site in json.loads((ROOT / 'PrompTugal' / 'Websites.json').read_text()):
        if f'href="{site["url"]}"' not in home_text:
            problems.append(f"index.html: website {site['url']} from Websites.json is missing")
    return problems


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else WEBSITE / 'public'
    problems = validate(out)
    for problem in problems:
        print(f'✗ {problem}')
    if problems:
        print(f'validate: {len(problems)} problem(s) in {out}')
        sys.exit(1)
    print(f'validate: {len(list(out.glob("*.html")))} pages OK in {out}')


if __name__ == '__main__':
    main()
