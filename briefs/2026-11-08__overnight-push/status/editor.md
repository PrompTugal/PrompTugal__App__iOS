# Status · Editor

> Build log checkpoint 2 written at 03:45 UTC (platform, release and the site on dev; vault, team and design waiting). Contracts §3 and §6 corrected against the live website. The site presents the team's internal app; labels follow the code; the dashboard and screens pages read every session branch. Next checkpoint 04:45.

Branch: `night/editor` · Last update: 03:50 UTC · merged into `dev` at 251f69b

## Done

- Positioning from Dinis: "the first audience of this version is us". Added to the overnight README; site copy says internal beta, no public launch, nothing on sale.
- Push dashboard reads each session's status from its own `night/*` branch when that is newer than `dev`, with commits not yet on dev. Release's status page shows before it is merged.

- Product pages rewritten: home, for readers, for teams, features, plans, support, privacy. PrompTugal only; RiskMandate and sgit links gone from product pages and the footer.
- `website/features.json`: 19 features, each with the files and screens that prove it. Status ("In the beta" or "Coming") is worked out at build time; placeholder screens do not count.
- Generated admin pages: push dashboard (from these status pages), screens (from `Shell/Destinations.swift` and `Websites.json`), releases (from git tags), CI (from `.github/workflows/*.yml`), build log (from `website/build-log/*.md`).
- `build.py` reads app settings from the app target only, so test targets and extensions do not break the build. Swift is counted in every folder, packages included.
- Validator: brand rule for product pages, feature labels must match the source, the push dashboard must list every session. Each rule has a negative control (42 tests).
- `website.yml`: the site build fetches full history so the release page can read the tags.
- Build log checkpoints 1 (02:50 UTC) and 2 (03:45 UTC).
- Contracts: §3 pick `at` is ISO 8601 and `id` is the bare slug; vault path `apps/agenda/picks.json`; §6 `places.json`. Each in the Changes list.

## In progress

- CI page: "latest iOS build" panel from release's `scripts/release/latest-build.sh`. `website.yml` runs the script (only if it exists, `actions: read`) and the site also publishes `/ios-build.json`. **Release: done, no need for you to change `website.yml`.** It is on `dev` since v0.1.8.

- Brief 08 records decisions D1–D7 (done). Adding the release engineer (night/release) to the plan, dashboard and build log.

## Next

- Build log checkpoint every hour, from the status pages and `git log`.
- Morning summary brief (`morning.md`) by 10:00 UTC.
- Tune feature evidence as screens land.

## Blocked

## Needs from others

- **Team:** `PrompTugal/Websites.json` still ships riskmandate.ai, sgit.ai and newsroom.sgit.ai as default shortcuts. The conductor says the team session drops them (item 7 of its brief).
- **Design:** please keep screen ids in `Destinations.swift` stable. The site's feature list checks for `team.schedule`, `team.people`, `agents.activity`, `news.home`, `news.newsroom`, `news.graph`, `briefed`, `collab.lanes`, `collab.ai`, `team.store`, `vault`, `debug` and `obs.native`, and treats a `PendingFeatureView` as not built.
- **Dinis:** a contact address for "talk to us" on the plans page. promptugal.news publishes no contact route (its rules forbid publishing contact details), so the page links to GitHub issues on this repo until there is one.

## Collected for the morning summary

- **Decision for Dinis: removing a pick.** Schedule sync with the vault is union-only, the same as the website. A pick removed in the app stays in the vault, on the website and on other devices; only this device remembers the removal. Fine for the summit. The proper fix is a "removed" list (tombstones) in `agenda/picks`, which the website must honour too. (From the conductor, 03:31 UTC.)
- **For Dinis:** a contact address for "talk to us" on the plans page.
- **Link:** release's TestFlight setup checklist, `release-setup.md` in this pack.
