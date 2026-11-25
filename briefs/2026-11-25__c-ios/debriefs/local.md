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
