#!/usr/bin/env python3
"""Tests for build.py and validate.py. Each validator rule has a negative
control: a site broken on purpose that the validator must refuse. A rule that
passes a broken site has proven nothing.

Usage: python3 -m unittest website/test_site.py
"""
import json
import re
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build      # noqa: E402
import version    # noqa: E402
import validate   # noqa: E402


class SiteTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp())
        cls.clean = cls.tmp / 'clean'
        cls.facts, cls.pages = build.build(cls.clean)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp)

    def broken(self, name, edit):
        """A copy of the clean build with one file edited (or deleted when edit is None)."""
        out = self.tmp / f'broken-{self.id().rsplit(".", 1)[-1]}'
        if out.exists():
            shutil.rmtree(out)
        shutil.copytree(self.clean, out)
        if edit is None:
            (out / name).unlink()
        else:
            (out / name).write_text(edit((out / name).read_text()))
        return validate.validate(out)

    def assertRefused(self, problems, fragment):
        self.assertTrue(any(fragment in p for p in problems), f'expected "{fragment}" in {problems}')

    # --- the clean build ----------------------------------------------------

    def test_clean_build_passes(self):
        self.assertEqual(validate.validate(self.clean), [])

    def test_facts_come_from_the_project(self):
        pbxproj = build.PROJECT.read_text()
        self.assertIn(f"MARKETING_VERSION = {self.facts['version']};", pbxproj)
        self.assertEqual(int(self.facts['site_count']), len(self.facts['websites']))
        lines = sum(len(f.read_text().splitlines()) for f in build.APP.glob('*.swift'))
        self.assertEqual(self.facts['swift_lines'], f'{lines:,}')
        self.assertIn(f">{self.facts['swift_lines']}<", (self.clean / 'index.html').read_text())

    def test_every_page_has_a_twin_without_markup(self):
        for page in self.clean.glob('*.html'):
            twin = (self.clean / (page.stem + '.md')).read_text()
            self.assertNotRegex(twin, r'<(?!!--)[a-z/]', f'{page.stem}.md contains HTML')
            self.assertNotIn('{{', twin)
            self.assertTrue(twin.split('\n', 2)[2].strip(), f'{page.stem}.md is empty')

    def test_twins_link_to_twins(self):
        twin = (self.clean / 'index.md').read_text()
        self.assertIn('(privacy.md)', twin)
        self.assertNotIn('(privacy.html)', twin)

    def test_decorative_mockup_is_not_in_the_twin(self):
        self.assertNotIn('Reload', (self.clean / 'index.md').read_text())

    def test_unknown_token_stops_the_build(self):
        with self.assertRaises(SystemExit):
            build.fill('{{no_such_token}}', {})

    def test_bump_increments_only_the_last_number(self):
        path = self.tmp / 'VERSION'
        path.write_text('v0.1.9\n')
        self.assertEqual(version.bump(path), 'v0.1.10')
        self.assertEqual(version.read(path), 'v0.1.10')

    def test_release_is_stamped_from_version_file(self):
        stamp = json.loads((self.clean / 'version.json').read_text())
        self.assertEqual(stamp['release'], version.read())
        self.assertEqual(stamp['version'], self.facts['version'])

    def test_refuses_malformed_version(self):
        path = self.tmp / 'VERSION-bad'
        for bad in ('0.1.3', 'v0.1', 'v0.1.3-beta', ''):
            path.write_text(bad)
            with self.assertRaises(SystemExit, msg=bad):
                version.read(path)

    def test_briefs_are_published_with_their_source_as_twin(self):
        briefs = sorted((build.ROOT / 'briefs').rglob('*.md'))
        self.assertTrue(briefs, 'no briefs to publish')
        for source in briefs:
            rel = source.relative_to(build.ROOT / 'briefs')
            name = 'index' if source.name == 'README.md' else source.stem
            page = self.clean / 'admin' / 'briefs' / rel.parent / f'{name}.html'
            self.assertTrue(page.exists(), f'{rel} was not published')
            self.assertIn('noindex', page.read_text())
            self.assertTrue((page.with_suffix('.md')).read_text().endswith(source.read_text()))

    def test_brief_links_become_pages_or_github(self):
        pack = next((self.clean / 'admin' / 'briefs').iterdir())
        text = (pack / 'index.html').read_text()
        self.assertIn('href="04-vaults-on-ios.html"', text)
        self.assertIn(f'{build.REPO_URL}/blob/dev/briefs/', text)

    def test_markdown_escapes_html(self):
        import markdown
        out = markdown.render('<script>x</script> and `<b>`')
        self.assertNotIn('<script>', out)
        self.assertIn('&lt;b&gt;', out)

    def test_refuses_noindex_page_in_sitemap(self):
        page = next(self.clean.rglob('admin/index.html')).relative_to(self.clean).as_posix()
        self.assertRefused(self.broken('sitemap.xml', lambda t: t.replace(
            '</urlset>', f'  <url><loc>{build.SITE_URL}{page}</loc></url>\n</urlset>')), 'noindex page is in sitemap.xml')

    def test_refuses_broken_link_in_nested_page(self):
        self.assertRefused(self.broken('admin/index.html', lambda t: t.replace('href="../version.json"',
                                                                                'href="version.json"')),
                           'broken link version.json')

    # --- negative controls --------------------------------------------------

    def test_refuses_broken_link(self):
        self.assertRefused(self.broken('index.html', lambda t: t.replace('href="support.html#beta"',
                                                                          'href="missing.html"')), 'broken link')

    def test_refuses_missing_anchor(self):
        self.assertRefused(self.broken('index.html', lambda t: t.replace('support.html#beta', 'support.html#nope')),
                           'no #nope')

    def test_refuses_missing_twin(self):
        self.assertRefused(self.broken('privacy.md', None), 'no Markdown twin')

    def test_refuses_twin_missing_from_llms(self):
        self.assertRefused(self.broken('llms.txt', lambda t: t.replace('privacy.md', 'x.md')), 'not listed in llms.txt')

    def test_refuses_page_missing_from_sitemap(self):
        self.assertRefused(self.broken('sitemap.xml', lambda t: t.replace('privacy.html', 'x.html')),
                           'not in sitemap.xml')

    def test_refuses_orphan_page(self):
        def drop_links(text):
            return re.sub(r'<a href="(\.\./)*privacy\.html"[^>]*>.*?</a>', '', text)
        out = self.tmp / 'orphan'
        shutil.copytree(self.clean, out)
        for page in out.rglob('*.html'):
            page.write_text(drop_links(page.read_text()))
        self.assertRefused(validate.validate(out), 'privacy.html: not reachable')

    def test_refuses_version_drift(self):
        self.assertRefused(self.broken('index.html', lambda t: t.replace(
            f'"softwareVersion": "{self.facts["version"]}"', '"softwareVersion": "9.9.9"')), 'softwareVersion')

    def test_refuses_missing_website(self):
        self.assertRefused(self.broken('index.html', lambda t: t.replace('href="https://riskmandate.ai/"', 'href="#"')),
                           'riskmandate.ai/ from Websites.json is missing')

    def test_refuses_bad_json_ld(self):
        self.assertRefused(self.broken('support.html', lambda t: t.replace('"@type"', '@type', 1)),
                           'JSON-LD does not parse')

    def test_refuses_external_script(self):
        self.assertRefused(self.broken('index.html', lambda t: t.replace(
            '</head>', '<script src="https://cdn.example.com/x.js"></script></head>')), 'not inline JSON-LD')

    def test_refuses_inline_handler(self):
        self.assertRefused(self.broken('index.html', lambda t: t.replace('<main id="main">',
                                                                          '<main id="main" onclick="x()">')),
                           'inline event handler')

    def test_refuses_image_without_alt(self):
        self.assertRefused(self.broken('index.html', lambda t: t.replace('alt="" width="36"', 'width="36"')),
                           'has no alt')

    def test_refuses_two_h1(self):
        self.assertRefused(self.broken('privacy.html', lambda t: t.replace('</main>', '<h1>x</h1></main>')),
                           '<h1> elements')

    def test_refuses_banned_word(self):
        self.assertRefused(self.broken('privacy.html', lambda t: t.replace('</main>', '<p>A seamless app.</p></main>')),
                           'banned word "seamless"')

    def test_refuses_leftover_token(self):
        self.assertRefused(self.broken('privacy.html', lambda t: t.replace('</main>', '{{oops}}</main>')),
                           'build token')

    def test_refuses_insecure_link(self):
        self.assertRefused(self.broken('privacy.html', lambda t: t.replace('https://promptugal.news/', 'http://promptugal.news/', 1)),
                           'insecure link')


if __name__ == '__main__':
    unittest.main()
