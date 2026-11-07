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
import admin      # noqa: E402
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
        import subprocess
        tracked = subprocess.run(['git', 'ls-files', '*.swift'], cwd=build.ROOT, capture_output=True, text=True).stdout.split()
        files = [build.ROOT / f for f in tracked if not f.startswith(('website/', 'scripts/', 'briefs/'))]
        self.assertEqual(sorted(files), sorted(build.swift_sources()))
        lines = sum(len(f.read_text().splitlines()) for f in files)
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

    def test_braces_in_briefs_are_not_tokens(self):
        self.assertEqual(build.no_tokens('<code>${{ github.token }}</code>'),
                         '<code>$&#123;&#123; github.token &#125;&#125;</code>')

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

    def test_refuses_other_brand_on_product_page(self):
        saved = validate.OTHER_BRANDS
        validate.OTHER_BRANDS = ('acmecorp',)          # the mechanism still works for a brand we list
        try:
            self.assertRefused(self.broken('readers.html', lambda t: t.replace('</main>', '<p>Built with AcmeCorp.</p></main>')),
                               'names another brand ("acmecorp")')
        finally:
            validate.OTHER_BRANDS = saved

    def test_powered_by_riskmandate_in_every_footer(self):
        for page in ('index.html', 'overnight.html', 'readers.html'):
            text = (self.clean / page).read_text()
            self.assertIn('href="https://riskmandate.ai/">RiskMandate</a>', text, page)
            self.assertIn('href="https://sgit.ai/">sgit</a>', text, page)
        self.assertEqual(validate.validate(self.clean), [])

    def test_allows_sgit_on_product_pages(self):
        out = self.tmp / 'sgit-ok'
        shutil.copytree(self.clean, out)
        page = out / 'overnight.html'
        page.write_text(page.read_text().replace('</main>', '<p>Vaults are made with sgit.</p></main>'))
        self.assertEqual(validate.validate(out), [])

    def test_allows_host_names_in_code_and_brands_in_admin(self):
        out = self.tmp / 'brands-ok'
        shutil.copytree(self.clean, out)
        page = out / 'privacy.html'
        page.write_text(page.read_text().replace('</main>', '<p><code>web-summit.sgit.ai</code></p></main>'))
        admin_page = out / 'admin' / 'index.html'
        admin_page.write_text(admin_page.read_text().replace('</main>', '<p>sgit.ai</p></main>'))
        self.assertEqual(validate.validate(out), [])

    def test_refuses_feature_claimed_before_it_is_in_the_source(self):
        """A feature whose files do not exist must not be labelled as in the beta.

        Every real feature may be shipped, so the test adds one that cannot be."""
        import os
        extra = self.tmp / 'extra-features.json'
        extra.write_text(json.dumps([{'id': 'not-built', 'platform': 'teams', 'name': 'Not built yet', 'kind': 'native',
                                      'what': 'A feature with no code.', 'evidence': ['PrompTugal/NoSuchFolder/*.swift']}]))
        out = self.tmp / 'with-unbuilt-feature'
        os.environ['PT_EXTRA_FEATURES'] = str(extra)
        try:
            build.build(out)
            coming = next(f for f in admin.features() if f['id'] == 'not-built')
            self.assertFalse(coming['shipped'])
            self.assertEqual(validate.validate(out), [])
            page = out / 'teams.html'
            text = page.read_text()
            start = text.index('id="f-not-built"')
            end = text.index('</li>', start)
            self.assertIn('status soon', text[start:end])
            page.write_text(text[:start] + text[start:end].replace('status soon', 'status on') + text[end:])
            self.assertRefused(validate.validate(out), 'feature not-built is labelled wrongly')
        finally:
            del os.environ['PT_EXTRA_FEATURES']

    def test_refuses_shipped_feature_labelled_coming(self):
        shipped = next(f for f in admin.features() if f['shipped'])
        page = f"{shipped['platform']}.html"
        def hide(text):
            start = text.index(f'id="f-{shipped["id"]}"')
            end = text.index('</li>', start)
            return text[:start] + text[start:end].replace('status on', 'status soon') + text[end:]
        self.assertRefused(self.broken(page, hide), f"feature {shipped['id']} is labelled wrongly")

    def test_refuses_missing_feature(self):
        first = admin.features()[0]
        page = f"{first['platform']}.html"
        self.assertRefused(self.broken(page, lambda t: t.replace(f'id="f-{first["id"]}"', 'id="f-gone"')),
                           f"feature {first['id']} from features.json is missing")

    def test_refuses_push_dashboard_without_a_session(self):
        self.assertRefused(self.broken('admin/push.html', lambda t: re.sub(r'/status/vault\.(html|md)"', '/status/x.html"', t)),
                           'status page vault is missing')

    def test_feature_status_follows_the_files(self):
        root = self.tmp / 'feature-root'
        (root / 'website').mkdir(parents=True)
        (root / 'website' / 'features.json').write_text(json.dumps({'features': [
            {'id': 'a', 'platform': 'readers', 'name': 'A', 'kind': 'native', 'what': 'x',
             'evidence': ['App/Schedule/*.swift', 'App/**/Store.swift']}]}))
        self.assertFalse(admin.features(root)[0]['shipped'])
        (root / 'App' / 'Schedule').mkdir(parents=True)
        (root / 'App' / 'Schedule' / 'Store.swift').write_text('// x')
        self.assertTrue(admin.features(root)[0]['shipped'])

    def test_app_settings_ignore_test_targets(self):
        def config(settings):
            body = ''.join(f'\t\t\t\t{k} = {v};\n' for k, v in settings.items())
            return f'\t\tX /* Debug */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n{body}\t\t\t}};\n'
        text = (config({'IPHONEOS_DEPLOYMENT_TARGET': '18.0'})
                + config({'PRODUCT_BUNDLE_IDENTIFIER': 'news.promptugal.reader', 'MARKETING_VERSION': '0.4.0', 'PRODUCT_NAME': '"$(TARGET_NAME)"'})
                + config({'PRODUCT_BUNDLE_IDENTIFIER': 'news.promptugal.readerTests', 'MARKETING_VERSION': '1.0', 'PRODUCT_NAME': '"$(TARGET_NAME)"'}))
        self.assertEqual(build.project_setting('PRODUCT_BUNDLE_IDENTIFIER', text), 'news.promptugal.reader')
        self.assertEqual(build.project_setting('MARKETING_VERSION', text), '0.4.0')
        self.assertEqual(build.project_setting('IPHONEOS_DEPLOYMENT_TARGET', text), '18.0')
        with self.assertRaises(SystemExit):
            build.project_setting('MARKETING_VERSION', text + config(
                {'PRODUCT_BUNDLE_IDENTIFIER': 'news.promptugal.reader', 'MARKETING_VERSION': '0.5.0'}))

    def test_status_text_cannot_inject_markup_or_tokens(self):
        out = admin.plain('Run `x={{ github.token }}` <script> and [the doc](../x.md)')
        self.assertNotIn('{{', out)
        self.assertNotIn('<script>', out)
        self.assertIn('the doc', out)
        self.assertNotIn('](', out)

    def test_screens_count_only_when_the_shell_is_the_root(self):
        root = self.tmp / 'root-scene'
        (root / 'website').mkdir(parents=True)
        (root / 'PrompTugal' / 'Shell').mkdir(parents=True)
        (root / 'website' / 'features.json').write_text(json.dumps({'features': [
            {'id': 'n', 'platform': 'readers', 'name': 'N', 'kind': 'native', 'what': 'x', 'evidence': ['screen:news.home']},
            {'id': 'b', 'platform': 'readers', 'name': 'B', 'kind': 'hybrid', 'what': 'x', 'evidence': ['root:.teamFeatures()']}]}))
        (root / 'PrompTugal' / 'Shell' / 'Destinations.swift').write_text(
            'AppDestination(id: "news.home", kind: .native) { AnyView(NewsHomeView()) }\n')
        app = root / 'PrompTugal' / 'App.swift'
        app.write_text('@main struct A: App {\n  var body: some Scene {\n    WindowGroup {\n      WebsiteView()\n'
                       '    }\n  }\n}\n// WindowGroup { AppShell().teamFeatures() }\n')
        self.assertEqual([f['shipped'] for f in admin.features(root)], [False, False])
        app.write_text('@main struct A: App { var body: some Scene { WindowGroup { AppShell().teamFeatures() } } }\n')
        self.assertEqual([f['shipped'] for f in admin.features(root)], [True, True])

    def _png(self, path, w, h):
        import struct, zlib
        def chunk(kind, data):
            return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
        raw = b''.join(b'\x00' + b'\xff\xff\xff' * w for _ in range(h))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
                         + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))

    def test_screenshots_are_published_at_their_real_size(self):
        import os
        shots = self.tmp / 'shots-in' / 'screens-abc'
        self._png(shots / 'iphone-debug.png', 30, 65)
        self._png(shots / 'ipad-debug.png', 41, 31)
        self._png(shots / 'ipad-today.png', 40, 30)
        (shots / 'notes.txt').write_text('ignored')
        self._png(shots / 'watch-debug.png', 10, 10)   # unknown device: ignored
        self._png(shots / 'iphone-news.png', 30, 65)   # not a screen id (a cut-off 'news.home'): left out
        self.assertEqual(admin.png_size(shots / 'iphone-debug.png'), (30, 65))
        self.assertIsNone(admin.png_size(shots / 'notes.txt'))
        found = admin.screenshots(shots.parent, devices={'iphone', 'ipad'})
        self.assertEqual(sorted(found['debug']), ['ipad', 'iphone'])
        self.assertEqual(sorted(admin.screenshots(shots.parent, devices={'iphone'})['debug']), ['iphone'])
        out = self.tmp / 'with-shots'
        os.environ['SCREENS_DIR'] = str(shots.parent)
        real_devices = admin.screen_devices
        admin.screen_devices = lambda root=None, folder=None: {'iphone', 'ipad'}   # as when iPad shots are published
        try:
            build.build(out)
        finally:
            del os.environ['SCREENS_DIR']
            admin.screen_devices = real_devices
        self.assertTrue((out / 'screens' / 'iphone-debug.png').exists())
        self.assertFalse((out / 'screens' / 'iphone-news.png').exists())
        page = (out / 'admin' / 'screens.html').read_text()
        self.assertIn('src="../screens/iphone-debug.png"', page)
        self.assertEqual(validate.validate(out), [])
        home = (out / 'index.html').read_text()
        self.assertIn('src="screens/ipad-today.png"', home)
        self.assertNotIn('page-mock', home)
        self.assertIn('page-mock', (self.clean / 'index.html').read_text())
        # negative controls: a size that is not the file's, a distorted size, a missing file
        broken = self.tmp / 'with-shots-broken'
        shutil.copytree(out, broken)
        screens_page = broken / 'admin' / 'screens.html'
        screens_page.write_text(screens_page.read_text().replace('data-png-width="30"', 'data-png-width="31"', 1))
        self.assertTrue(any('the file is 30x65' in p for p in validate.validate(broken)))
        screens_page.write_text(screens_page.read_text().replace('data-png-width="31"', 'data-png-width="30"', 1)
                                .replace('width="240" height="520"', 'width="240" height="300"', 1))
        self.assertTrue(any('distorts it' in p for p in validate.validate(broken)), validate.validate(broken))
        (broken / 'screens' / 'ipad-debug.png').unlink()
        self.assertTrue(any('broken link' in p and 'ipad-debug.png' in p for p in validate.validate(broken)))

    def _png_with_orientation(self, path, w, h, orientation):
        import struct, zlib
        self._png(path, w, h)
        data = path.read_bytes()
        tiff = b'MM\x00*' + struct.pack('>I', 8) + struct.pack('>H', 1) + struct.pack('>HHIHH', 0x0112, 3, 1, orientation, 0) + b'\x00' * 4
        chunk = struct.pack('>I', len(tiff)) + b'eXIf' + tiff + struct.pack('>I', zlib.crc32(b'eXIf' + tiff) & 0xffffffff)
        path.write_bytes(data[:33] + chunk + data[33:])   # after IHDR (8 + 25 bytes)

    def test_rotated_screenshots_are_left_out_and_refused(self):
        shots = self.tmp / 'rotated'
        self._png_with_orientation(shots / 'ipad-today.png', 40, 30, 8)
        self._png_with_orientation(shots / 'iphone-today.png', 30, 65, 1)
        self.assertEqual(admin.png_orientation(shots / 'ipad-today.png'), 8)
        self.assertEqual(admin.png_orientation(shots / 'iphone-today.png'), 1)
        found = admin.screenshots(shots, devices={'iphone', 'ipad'})
        self.assertEqual(sorted(found['today']), ['iphone'])
        # the validator refuses one that slips through
        out = self.tmp / 'rotated-site'
        shutil.copytree(self.clean, out)
        (out / 'screens').mkdir()
        shutil.copy(shots / 'ipad-today.png', out / 'screens' / 'ipad-today.png')
        page = out / 'privacy.html'
        page.write_text(page.read_text().replace('</main>', '<img src="screens/ipad-today.png" alt="x" width="40" height="30" '
                                                 'data-png-width="40" data-png-height="30"></main>'))
        self.assertRefused(validate.validate(out), 'EXIF orientation tag')

    def test_ipad_only_from_a_fixed_run(self):
        folder = self.tmp / 'run-number'
        folder.mkdir()
        self.assertEqual(admin.screen_devices(folder=folder), {'iphone'})          # no run.txt: iPhone only
        (folder / 'run.txt').write_text('13\n')
        self.assertEqual(admin.screen_devices(folder=folder), {'iphone'})
        (folder / 'run.txt').write_text('16\n')
        self.assertEqual(admin.screen_devices(folder=folder), {'iphone', 'ipad'})

    def test_overnight_captions_name_real_screens(self):
        night = admin.overnight()
        ids = [s['id'] for s in night['screens']]
        registered = {d['id'] for d in admin.destinations()}
        self.assertEqual(len(ids), len(set(ids)), 'a screen is captioned twice')
        self.assertTrue(set(ids) <= registered, f'not registered screens: {sorted(set(ids) - registered)}')
        self.assertIn(night['hero'], registered)
        self.assertTrue(all(s['title'] and s['text'] and s['kicker'] for s in night['screens']))

    def test_overnight_shows_both_devices_when_ci_took_them(self):
        shots = self.tmp / 'night-in' / 'screens-n'
        self._png(shots / 'ipad-wall.png', 40, 28)
        self._png(shots / 'iphone-wall.png', 30, 65)
        self._png(shots / 'iphone-debug.png', 30, 65)
        found = admin.screenshots(shots.parent, devices={'iphone', 'ipad'})
        html_out = admin.overnight_bands(admin.overnight()['screens'], found)
        self.assertNotIn('No screenshots in this site build', html_out)
        wall = html_out[html_out.index('id="night-wall"'):]
        self.assertIn('screens/ipad-wall.png', wall)
        self.assertIn('screens/iphone-wall.png', wall)
        today = html_out[html_out.index('id="night-today"'):html_out.index('id="night-team.people"')]
        self.assertNotIn('<img', today)            # no shot of this screen: caption only, no broken image
        self.assertIn('screens/ipad-wall.png', admin.overnight_hero(found, 'wall'))
        self.assertEqual(admin.overnight_hero(found, 'today'), '')

    def test_overnight_without_screenshots_is_a_notice(self):
        page = (self.clean / 'overnight.html').read_text()
        self.assertIn('No screenshots in this site build', page)
        self.assertNotIn('screens/ipad-', page)

    def test_no_screenshots_means_a_notice_not_a_broken_image(self):
        self.assertIn('No screenshots in this site build', (self.clean / 'admin' / 'screens.html').read_text())
        self.assertFalse((self.clean / 'screens').exists())

    def test_status_page_counts(self):
        info = admin.parse_status('# Status · X\n\n> Going well.\n\n## Done\n\n- a\n- b\n  more\n\n## Blocked\n\n## Next\n* c\n')
        self.assertEqual(info['summary'], 'Going well.')
        self.assertEqual(len(info['sections']['Done']), 2)
        self.assertEqual(info['sections']['Blocked'], [])
        self.assertEqual(info['sections']['Next'], ['c'])

    def test_workflows_are_read_from_the_files(self):
        site = next(w for w in admin.workflows() if w['file'] == 'website.yml')
        self.assertEqual([j['id'] for j in site['jobs']], ['release', 'build', 'deploy'])
        self.assertIn('Validate', next(j for j in site['jobs'] if j['id'] == 'build')['steps'])
        self.assertIn('push', site['triggers'])

    def test_destinations_are_read_from_swift(self):
        root = self.tmp / 'dest-root'
        (root / 'PrompTugal' / 'Shell').mkdir(parents=True)
        (root / 'PrompTugal' / 'Shell' / 'Destinations.swift').write_text(
            '/// Example:\n///     AppDestination(id: "team.schedule", title: "My schedule", kind: .hybrid) { AnyView(X()) }\n'
            'let all = [\n  AppDestination(id: "now", title: "Now", symbol: "clock", section: .today, kind: .native) { AnyView(NowView()) },\n'
            '  Destination(id: "site", title: "PrompTugal.news", symbol: "globe", section: .news,\n'
            '              kind: .web(URL(string: "https://promptugal.news/")!), view: { AnyView(EmptyView()) }),\n'
            '  AppDestination(id: "vault", title: "Vault", symbol: "lock", section: .vault, kind: .native) {\n'
            '      AnyView(PendingFeatureView(title: "Vault", owner: "night/vault"))\n  },\n'
            '  AppDestination(id: "settings", title: "Settings", symbol: "gear", section: .settings, kind: .native) { AnyView(S()) },\n'
            ']\nstruct PendingFeatureView: View { }\n')
        found = admin.destinations(root)
        self.assertEqual([(d['id'], d['kind'], d['pending']) for d in found],
                         [('now', 'native', False), ('site', 'web', False), ('vault', 'native', True),
                          ('settings', 'native', False)])
        self.assertEqual(found[1]['url'], 'https://promptugal.news/')

    def test_placeholder_screen_does_not_ship_a_feature(self):
        root = self.tmp / 'dest-root-2'
        (root / 'website').mkdir(parents=True)
        (root / 'PrompTugal' / 'Shell').mkdir(parents=True)
        (root / 'PrompTugal' / 'App.swift').write_text('@main struct A: App { var body: some Scene { WindowGroup { AppShell() } } }\n')
        (root / 'website' / 'features.json').write_text(json.dumps({'features': [
            {'id': 'v', 'platform': 'readers', 'name': 'V', 'kind': 'native', 'what': 'x', 'evidence': ['screen:vault']}]}))
        swift = root / 'PrompTugal' / 'Shell' / 'Destinations.swift'
        swift.write_text('AppDestination(id: "vault", kind: .native) { AnyView(PendingFeatureView(title: "V")) }\n')
        self.assertFalse(admin.features(root)[0]['shipped'])
        swift.write_text('AppDestination(id: "vault", kind: .native) { AnyView(VaultView()) }\n')
        self.assertTrue(admin.features(root)[0]['shipped'])
        (root / 'website' / 'features.json').write_text(json.dumps({'features': [
            {'id': 'p', 'platform': 'teams', 'name': 'P', 'kind': 'native', 'what': 'x', 'evidence': ['view:TeamPlansView']}]}))
        self.assertFalse(admin.features(root)[0]['shipped'])
        swift.write_text('AppDestination(id: "x", kind: .native) { AnyView(PendingFeatureView(title: "TeamPlansView()")) }\n')
        self.assertFalse(admin.features(root)[0]['shipped'])
        swift.write_text('AppDestination(id: "team.plans", kind: .native) { AnyView(TeamPlansView()) }\n')
        self.assertTrue(admin.features(root)[0]['shipped'])

    def test_latest_build_panel(self):
        self.assertIsNone(admin.latest_build(None))
        bad = self.tmp / 'bad.json'
        bad.write_text('{"available": false}')
        self.assertIsNone(admin.latest_build(bad))
        bad.write_text('not json')
        self.assertIsNone(admin.latest_build(bad))
        self.assertIn('No CI build information', admin.latest_build_html(None, build.REPO_URL))
        good = self.tmp / 'good.json'
        good.write_text(json.dumps({'available': True, 'version': '0.4.0', 'build': '103', 'commit': 'abcdef123',
                                    'builtAt': '2026-11-07T03:00:00Z', 'deviceFamily': [1, 2], 'minimumOS': '18.0',
                                    'appBytes': 1048576 * 2, 'ipaBytes': 657000,
                                    'runUrl': 'https://github.com/x/y/actions/runs/42', 'artifacts': [{'name': 'a', 'size': 10}]}))
        out = admin.latest_build_html(admin.latest_build(good), build.REPO_URL)
        self.assertEqual(admin._xcode('2660'), '26.6')
        self.assertEqual(admin._xcode('2651'), '26.5.1')
        for want in ('0.4.0 (build 103)', 'iPhone and iPad', '2.0 MB', '642 KB', '>42<', 'abcdef1'):
            self.assertIn(want, out)
        self.assertEqual(json.loads((self.clean / 'ios-build.json').read_text()), {'available': False})

    def test_build_log_checkpoints_are_published(self):
        for source in sorted((build.WEBSITE / 'build-log').glob('*.md')):
            page = self.clean / 'admin' / 'build-log' / f'{source.stem}.html'
            self.assertTrue(page.exists(), f'{source.name} was not published')
            self.assertIn(f'{source.stem}.html', (self.clean / 'admin' / 'build-log' / 'index.html').read_text())

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
