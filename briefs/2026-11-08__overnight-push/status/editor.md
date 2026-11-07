# Status · Editor

> The site presents PrompTugal as the team's internal app in beta, with readers and teams as where it is going. Features are labelled from the code; the push dashboard reads every session's own branch; the CI page shows the latest iOS build. Build log checkpoint 2 at 03:50 UTC.

Branch: `night/editor` · Last update: 03:10 UTC · merged into `dev` at 251f69b

## Done

- Positioning from Dinis: "the first audience of this version is us". Added to the overnight README; site copy says internal beta, no public launch, nothing on sale.
- Push dashboard reads each session's status from its own `night/*` branch when that is newer than `dev`, with commits not yet on dev. Release's status page shows before it is merged.

- Product pages rewritten: home, for readers, for teams, features, plans, support, privacy. PrompTugal only; RiskMandate and sgit links gone from product pages and the footer.
- `website/features.json`: 19 features, each with the files and screens that prove it. Status ("In the beta" or "Coming") is worked out at build time; placeholder screens do not count.
- Generated admin pages: push dashboard (from these status pages), screens (from `Shell/Destinations.swift` and `Websites.json`), releases (from git tags), CI (from `.github/workflows/*.yml`), build log (from `website/build-log/*.md`).
- `build.py` reads app settings from the app target only, so test targets and extensions do not break the build. Swift is counted in every folder, packages included.
- Validator: brand rule for product pages, feature labels must match the source, the push dashboard must list every session. Each rule has a negative control (42 tests).
- `website.yml`: the site build fetches full history so the release page can read the tags.
- Build log checkpoint 1 (02:50 UTC).

## In progress

- CI page: "latest iOS build" panel from release's `scripts/release/latest-build.sh`. `website.yml` runs the script (only if it exists, `actions: read`) and the site also publishes `/ios-build.json`. Release: no need for you to change `website.yml`.

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
