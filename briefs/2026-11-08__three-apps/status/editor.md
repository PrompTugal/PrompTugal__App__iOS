# Status · Editor

> 00:05 UTC: the site structure, the three-apps page, the Team app pages in the admin area and the review notes are done on `split/editor`, green on build, validator and tests. Waiting for platform's phase 1 and the later phases to point the feature labels at the new folders.

Branch: `split/editor` · Last update: 00:05 UTC

## Done

- Site: the public pages (Home, The app, Features, Plans, Support, Privacy) describe the PrompTugal app. New page "The three apps", with RiskMandate marked "coming after the summit".
- Site: `teams.html`, the old privacy page and the Overnight page moved to `admin/team-app.html`, `admin/team-privacy.html` and `admin/overnight.html`. The admin index links all three.
- Checks: a feature is in an app only if the app is built from its files (`apps.json` folders and package closure). Before the split the old `PrompTugal/` folder is the app. Test folders never count. Six new tests.
- `features.json` names files, not paths, so moves do not break it. Sample data and reading credit are team features now.
- Push dashboard reads `split/*` branches as well as `night/*`. Test against a throwaway git repository.
- Review notes rewritten for the PrompTugal app: no sample data, no keys needed, no lanes, no purchases.
- Build log checkpoint 13.

## In progress

- 01:05 UTC: the conductor gave me `scripts/testflight/review-notes.txt` and `what-to-test.txt` (text files only). The PrompTugal versions are written next to them as `review-notes.promptugal.txt` and `what-to-test.promptugal.txt`, with the same placeholder names (DEMO_OPENROUTER_KEY, CAP, DEMO_VAULT_KEY, CONTACT_ADDRESS, RESPONSE_TIME); DEMO_LANE_NAME is gone because the public app has no lanes. They replace the originals in the phase 4 merge, because the workflow reads the old names and today's app is still the one app.

- 01:00 UTC: merged `dev` to v0.1.67 (TestFlight ops, release). Green, pushed. `scripts/testflight/review-notes.txt` and `what-to-test.txt` still describe the one app (sample data, Who are you); they are not mine. After phase 4 they need the PrompTugal versions from `briefs/…/review-notes.md`.

- 00:45 UTC: merged PTVaultUI (`e5328ff`). Vault, Face ID and trusted-signer labels follow the moved files (`**/VaultKeychain.swift`, `**/VaultViews.swift`): all three still in the beta. Green, pushed.

- 00:05 UTC: merged phase 1 (`9220d7e`). `apps.json` has only a `team` entry on the root project, so the PrompTugal app has no entry and counts as the one app: labels unchanged (13 of 13 public, same team count). Build, validator and 66 tests green. Pushed.

- Conductor: hold `split/editor` and merge after phase 4. Keep merging `origin/dev` in. Answers received: the public shell is `PublicShell(` in `Apps/PrompTugal/PublicShell.swift`; shared screen ids are unchanged; Ask there has no team context; screenshots are `screens-<sha>` for the PrompTugal app and `screens-<sha>-<app>` for the others. Screens check now accepts `PublicShell(`.

- Waiting for the conductor's word that phase 1 (scaffold) is on `dev`.

## Next

- Merge `origin/dev` when platform's phase 1 lands. Read `apps.json` and check the scope code against the real file.
- Phase 3: update `features.json` for the packages (screen ids, root markers) as each lands.
- Phase 4: point facts (version, bundle, icon, websites) at `Apps/PrompTugal`; re-read privacy and support against its code; fix the home screenshot ids.

## Blocked

- Nothing yet.

## Needs from others

- Design: which features the PrompTugal app has. The site assumes News, Agenda, Websites, Ask, Vault, reminders, the graph and a privacy cover, and no team screens. Tell me the screen ids in its Destinations list and the root view that marks it (today the feature labels use `AppShell(` and `.teamFeatures()`).
- Collab: confirm that Ask in the PrompTugal app has no team, teammate or agent context. The privacy page and the review notes say so.
- Release: how `screens.yml` will name the two apps' screenshots, so the home page picks the PrompTugal app's.
- Dinis: a contact address for the support page (still GitHub issues).
- The conductor: merge this branch after phase 4, or earlier? The privacy and support pages describe the public app without lanes, so they are true only once `Apps/PrompTugal` exists. The apps page already says "not finished" until the three projects exist.
