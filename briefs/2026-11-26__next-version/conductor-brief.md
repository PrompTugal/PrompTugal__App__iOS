# Brief: what the PrompTugal iOS app can add, now that it is approved

> Copy of cl-6.conductor's brief of 26 Nov 2026 (PrompTugal__Agent__Conductor, board/briefs/2026-11-26-ios-app.md): what the iOS app can add now it is approved.

cl-6.conductor@PrompTugal.dinis, 26 November 2026. A brief for whoever builds the app (PrompTugal/PrompTugal__App__iOS, home PrompTugal__Agent__Apps), and for the agents whose data feeds it.

**Status:** a proposal, not a decision. Dinis's word, relayed by cl-6.maestro (25 Nov): "the iOS app has been approved ... the site is fully up to date because that feeds the iOS app ... we should be briefing the iOS app on things they can add there."

The conductor has no access to the app's repository. Before anything is built, the app's agent checks every point below against what the app does today. Proposed home for this brief in the app's repository: `docs/briefs/`.

## 1. What the app can read today (checked 26 Nov 2026, 02:40 UTC)

The site's JSON API is public, CC BY 4.0 for the data, and rebuilt on every release.
- **The index:** https://promptugal.news/api/v1/index.json (v0.1.2292). Its manifest has 3,222 files, each with a sha256 and a schema.
- **Articles:** `api/v1/articles.json`, plus one file per article. Every article is signed.
- **Places:** `api/v1/places.json` and `by-place/`. That covers Portugal, the Algarve and its municipalities, and 18 cities, including local news with its source and date.
- **Entities:** companies, events, people, organisations, topics, stories, evidence. There are also graphs, as JSON and N-Triples.
- **Other:** search (1,198 files), days, the newsletter, translations (`i18n`), live, and visualisations (`viz`).
- **The section sites:** each has its own JSON at its own domain, on the pipeline standard: weather, travel, civic, startups, events, signals, cyber, live, videos, library, bulletins and data.promptugal.news.

## 2. What it could add (proposals, in order of value)

1. **A "today" view.** The front page's lead and top stories (owner: correspondent). Show the article's signature and its sources inline.
2. **My places.** The reader picks towns; the app shows each one's latest local news and live data from `by-place/`.
   - Owner: places.
   - Data is read in the app only. Nothing about the reader leaves the phone: no account, no IP, no location sent.
3. **Freshness on every card.** Show when each figure was read and from where (`data_read_at`). That is the site's own principle: "show when each was read". Stale data then says it is stale.
4. **Offline reading** of the last edition. Files are already static and hashed in the manifest.
5. **Notifications** only for what a reader chose: a place, a topic, a weather warning (linked, never copied, per IPMA's terms). Each is opt-in.
6. **Languages,** from `i18n` (owner: translator).
7. **"How this was made":** the piece flows and signatures behind each article, a unique feature of the site.

## 3. What the app must not do

- Show data whose licence does not allow it in a paid app. Billing is on promptugal.news only (Dinis, 18 Nov). Rights checks each source.
- Record anything that identifies a reader. Votes or reads go only through observability's existing anonymous drain.
- Claim anything for RiskMandate beyond riskmandate.ai.

## 4. What the agents do for it now

- **Data:** collect, so nothing in the app is older than the day.
- **Journalist, correspondent, places, the sections:** keep their JSON current at each wake.
- **Dev:** keep the API's shape stable, and announce any change in the manifest and versions.
- **Rights and security:** review what the app shows.
- **Checker and researcher:** "what feeds the iOS app" is section 1 above.
