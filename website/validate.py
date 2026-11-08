#!/usr/bin/env python3
"""Refuse a built site that breaks the rules. Exit 1 with one line per problem.

Checks every page in the output directory:
  * internal links and images resolve, and every page is reachable from the home page
  * every page has a Markdown twin listed in llms.txt and sitemap.xml
  * JSON-LD parses, and the home page's softwareVersion matches the Xcode project
  * product pages (outside admin/) name no brand listed in OTHER_BRANDS (ours are all allowed)
  * every feature in features.json is on its platform page, labelled as the source says
  * the push dashboard lists every status page of every brief pack
  * no scripts other than JSON-LD, no external stylesheets, no inline event handlers
  * one <h1>, a lang, a title and a description; every <img> has alt, width and height
  * no build tokens left behind and no banned words
  * every screenshot's declared size is the PNG's real size, shown without distortion

Standard library only. Usage: python3 website/validate.py [DIR]
"""
import json
import posixpath
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urldefrag, urlparse

WEBSITE = Path(__file__).resolve().parent
ROOT = WEBSITE.parent
sys.path.insert(0, str(WEBSITE))
import admin  # noqa: E402
import build  # noqa: E402
import version  # noqa: E402

# Product pages name only our own products and the tech under them: PrompTugal, sgit and RiskMandate
# (Dinis, 8 Nov: sgit is one of the things we do; RiskMandate powers the site). Add any other company's
# name here to keep it off product pages. Host names inside <code> are data, not branding.
OTHER_BRANDS = ()
BANNED = ('seamless', 'revolutionary', 'cutting-edge', 'game-changing', 'game changer', 'effortless',
          'blazing', 'unleash', 'world-class', 'best-in-class', 'supercharge', 'lorem ipsum', 'todo')


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links, self.images, self.ids, self.scripts, self.problems = [], [], set(), [], []
        self.img_attrs = []
        self.h1 = 0
        self.noindex = False
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
        elif tag == 'meta' and a.get('name') == 'robots':
            self.noindex = 'noindex' in (a.get('content') or '')
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
            self.img_attrs.append(a)
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
    text = (admin.public_project(ROOT) / 'project.pbxproj').read_text()
    marketing = set(re.findall(r'MARKETING_VERSION = ([^;]+);', text))
    release = version.read()
    return {build.app_version(release, m) for m in marketing}


def validate(out):
    problems = []
    pages = {p.relative_to(out).as_posix(): p for p in sorted(out.rglob('*.html'))}
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

    def resolve(name, href):
        """The page-relative href as a path relative to the site root ('' when it leaves the site)."""
        target = urldefrag(href)[0]
        if not target:
            return name
        joined = posixpath.normpath(posixpath.join(posixpath.dirname(name), target))
        return '' if joined.startswith('..') else joined

    # Links, anchors and images
    for name, page in parsed.items():
        for href in page.links + page.images:
            url = urlparse(href)
            if url.scheme or href.startswith('//') or href.startswith('mailto:'):
                if url.scheme == 'http':
                    problems.append(f'{name}: insecure link {href}')
                continue
            target, fragment = resolve(name, href), urldefrag(href)[1]
            if not target or not (out / target).exists():
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
        queue += [resolve(current, h) for h in parsed[current].links
                  if not urlparse(h).scheme and urldefrag(h)[0].endswith('.html')]
    for name in sorted(set(parsed) - seen):
        problems.append(f'{name}: not reachable from index.html')

    # Agent surface: every page has a twin in llms.txt; indexable pages, and only those, are in the sitemap
    llms = (out / 'llms.txt').read_text() if (out / 'llms.txt').exists() else ''
    sitemap = (out / 'sitemap.xml').read_text() if (out / 'sitemap.xml').exists() else ''
    for name, page in parsed.items():
        twin = name[:-5] + '.md'
        if not (out / twin).exists():
            problems.append(f'{name}: no Markdown twin {twin}')
        elif f'/{twin})' not in llms:
            problems.append(f'{name}: {twin} is not listed in llms.txt')
        loc = '' if name == 'index.html' else name
        listed = f'/{loc}</loc>' in sitemap
        if page.noindex and listed:
            problems.append(f'{name}: noindex page is in sitemap.xml')
        elif not page.noindex and not listed:
            problems.append(f'{name}: not in sitemap.xml')

    # Facts must match the app
    versions = project_version()
    home = parsed['index.html']
    app = next((json.loads(s) for s in home.scripts if '"softwareVersion"' in s), {})
    if {app.get('softwareVersion')} != versions:
        problems.append(f"index.html: softwareVersion {app.get('softwareVersion')} != project {sorted(versions)}")
    # Screenshots are real: the declared pixel size is the file's, and the shown size keeps its shape
    for name, page in parsed.items():
        for a in page.img_attrs:
            if 'data-png-width' not in a:
                continue
            target = resolve(name, a.get('src', ''))
            real = admin.png_size(out / target) if target else None
            if not real:
                continue  # a missing file is already reported as a broken link
            if admin.png_orientation(out / target) != 1:
                problems.append(f"{name}: screenshot {a['src']} has an EXIF orientation tag, so browsers show it rotated")
            declared = (int(a['data-png-width']), int(a['data-png-height']))
            if declared != real:
                problems.append(f"{name}: screenshot {a['src']} says {declared[0]}x{declared[1]}, the file is {real[0]}x{real[1]}")
            w, h = int(a.get('width', 0)), int(a.get('height', 0))
            if not w or abs(h - real[1] * w / real[0]) > 1:
                problems.append(f"{name}: screenshot {a['src']} is shown at {w}x{h}, which distorts it")

    # PrompTugal only on product pages
    for name, path in pages.items():
        if name.startswith('admin/'):
            continue
        text = re.sub(r'<code>.*?</code>|<head>.*?</head>', ' ', path.read_text(), flags=re.S)
        visible = re.sub(r'<[^>]+>', ' ', text).lower()
        for brand in OTHER_BRANDS:
            if brand in visible:
                problems.append(f'{name}: names another brand ("{brand}") on a product page')

    # Feature labels follow the files in the repository
    for feature in admin.features(ROOT):
        page = admin.PLATFORM_PAGE[feature['platform']]
        if page not in pages:
            problems.append(f"{page}: missing, but features.json lists {feature['id']} for it")
            continue
        block = re.search(rf'<li class="feature" id="f-{re.escape(feature["id"])}">(.*?)</li>', pages[page].read_text(), re.S)
        if not block:
            problems.append(f"{page}: feature {feature['id']} from features.json is missing")
            continue
        claims = 'status on' in block.group(1)
        if claims != feature['shipped']:
            want = 'in the beta' if feature['shipped'] else 'coming'
            problems.append(f"{page}: feature {feature['id']} is labelled wrongly; the source says {want}")

    # The push dashboard covers every status page
    if 'admin/push.html' in pages:
        dash = pages['admin/push.html'].read_text()
        for path in sorted(ROOT.glob('briefs/*/status/*.md')):
            pack = path.parent.parent.name
            if f'/{pack}/status/{path.stem}.html"' not in dash and f'/{pack}/status/{path.stem}.md"' not in dash:
                problems.append(f'admin/push.html: status page {path.stem} of {pack} is missing')
    return problems


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else WEBSITE / 'public'
    problems = validate(out)
    for problem in problems:
        print(f'✗ {problem}')
    if problems:
        print(f'validate: {len(problems)} problem(s) in {out}')
        sys.exit(1)
    print(f'validate: {len(list(out.rglob("*.html")))} pages OK in {out}')


if __name__ == '__main__':
    main()
