# Debrief: c.ios.local (PTLocal), 25 Nov 2026

> Worker for c.ios. Branch `work/c-local` (from `work/candidate-c2`, which holds dev at v0.4.123). Not compiled: no Mac here, CI is the compiler. No secrets in this file.

## What landed (Packages/PTLocal only)

1. **Freshness honesty** (`Freshness.swift`, `ProvenanceLabel(readAt:host:)`). A feed is "Live, read HH:mm" only when its own read time is under 3 hours old; otherwise "Snapshot, read 21 Nov", even if the device fetched it a second ago. Used on the places home, town page, town agent card, newsroom centre, live board and strips, Algarve maps, the runs card and both town layers. Place files use `updated` (a day), the dashboard `at`, status `built`, events `read_at`, civic `read_on`.
2. **Newsroom status feed** (`Live/NewsroomStatus.swift`, `Live/NewsroomRuns.swift`). `promptugal.news/api/v1/newsroom/status.json` is read by the one shared poller (`LiveNewsroom`, every fifth poll, cached). A "Pipeline and recent runs" card on the live board shows each stage and the 8 newest runs, each opening its agent's page (else the status page). Today the ledger's newest run is 5 Nov, and the card says so in amber.
3. **Town layers** (`Town/`). `TownLayers(placeID:)`: "What is on" from `data.promptugal.news/api/v1/events/by-place/<id>.json` (only events not over today, each opening its source), and for the 16 councils (Quarteira under Loulé) open notices from civic `use-cases/notices.json` (each opening its Diário da República PDF), plus the council's 2026 contracts and Civic page from `councils/<id>.json`. Each block is hidden when it has nothing for the town. One shared store (`TownLayersStore.shared`), each feed at most every 10 minutes, cached.

Tests: `FreshnessTests`, `NewsroomStatusTests`, `TownLayersTests` (fixtures include ids that are prefixes of each other).

## Needs the conductor

- **Wiring (Shell, not mine):** in `Apps/PrompTugal/Shell/PlacesWiring.swift`, `PlaceLayers.body`, add `TownLayers(placeID: placeID)` after `TownNewsroomLive(placeID: placeID)`. Until then the town layers are built but not shown.
- **A compile check:** first build of these files in a candidate run. Logs to read: `logs/PTLocal-build.log`, `logs/PTLocal.log`.

## Open

- data.* and civic.* stopped reading on 19 to 21 Nov, so every town layer says "Snapshot" until the collectors run again.
- The status runs ledger stopped on 5 Nov: the card shows real runs, but old ones. Runs are not merged into the ticker (agent ids in status.json, like `curator-vicky`, differ from dashboard roles).
- Place files carry only a day in `updated`, so a place read today after 03:00 reads as "Snapshot, read <today>".
- Notices "still open" are filtered by deadline on the device (the feed lists some already past).

## Added after the first ready: rights hold (Dinis, 25 Nov ~23:35, via c.ios)

- `PlaceSite.News` decodes `hold`. A held story keeps headline, summary, outlet, date and source link, with "Read it at <outlet>"; its AI path and steps are dropped at decode time, so no row, ranking or prompt can use them. Held summaries are used in on-device summaries; "Explain the AI path" is hidden for held stories. Tests in `RightsHoldTests`. Today every Faro item in the live by-place file is held.

## Batch 2: Data sources (Dinis via c.ios, 25 Nov ~23:35)

- `public struct DataSourcesView` (the screen) and `public struct DataSourcesCard` (a small card for the places home that pushes the screen). Both in `DataSources/`.
- One card per site (13): what it covers, its count, its freshness by its own read time, and a link to the site. Weather, events and signals are counted from data.promptugal.news's catalogue (`/api/v1/index.json`), which also lists its 30 sources with cadence, state, headline and last read, each linking to its page. Startups has no small feed (its facts.json is 1.25 MB), so its card says so and links to the site.
- `DataSourcesStore.shared`: one small feed per site, in parallel, at most every 10 minutes, cached. Tests in `DataSourcesTests`.
- Shell (the conductor's): add `DataSourcesView()` to More and `DataSourcesCard()` to `PlacesHomeLayers`.

## Batch 3: place taps through a hook

- `LocalHooks.swift`: `EnvironmentValues.localOpenPlace` and `View.localOpenPlace { id in ... }`. `AlgarveMapsView` calls it on a town tap when set (the shell routes `place:<id>`); without it, PTLocal pushes its own `TownView` as before.

## Batch 4: Offline edition (next version, item 4; Dinis 26 Nov ~02:45 via c.ios)

- `public struct OfflineEditionView` (a More row) and `OfflineEdition.shared` (`Offline/`). Reads `api/v1/manifest.json` (0.7 MB, 3,222 files), saves the same subset for every reader so the requests say nothing about who reads what: `articles.json` and each `articles/*.json`, `since.json`, `by-place/index.json`, the `by-place/<id>.json` of all 19 places the app knows (not only the followed ones, for that reason), `newsletter.json` and `newsletter/*.txt`. About 2.2 MB. Each file's SHA-256 is checked against the manifest; any mismatch changes nothing. Files go to a staging folder and replace the saved copy only when all are verified.
- Screen: "Saved for offline, read <date, time>", edition version, file count, size on this device, Save and Delete (with confirmation). A save on mobile data or in Low Data Mode asks first. Automatic saves only after a first save by hand, at most every 6 hours, only on a free connection (NWPathMonitor: not expensive, not constrained).
- Readers: `LocalStore.refreshPlaces` falls back to the saved place file when the network and the device copy both fail. Others can read `OfflineEdition.shared.data(for: "api/v1/...")` or `EditionFiles.standard().load(_:)` (nonisolated). PTPlaces and the articles reader are not mine: wiring them to prefer the edition offline is for their owners.
- Tests: `OfflineEditionTests`.
