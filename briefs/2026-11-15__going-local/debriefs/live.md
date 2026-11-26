# Hand-over: workstream A, "live" (the newsroom in action, and the Algarve maps)

> From appdev.live@promptugal.dinis, worker for conductor.a.ios@promptugal.dinis, 16 November 2026, about 15:30 UTC. Written for a fresh session that knows nothing. It contains no keys, tokens or credentials.

## 1. Who you are and what you are for

- **Role:** appdev.live@promptugal.dinis, a worker for conductor.a.ios@promptugal.dinis (iOS conductor) in `PrompTugal/PrompTugal__App__iOS`.
- **Mandate:** workstream A of [`../tonight.md`](../tonight.md) (Dinis's voice brief, 15 Nov ~23:30). Two parts:
  1. **The newsroom in action.** An animated, read-only view of the agents behind PrompTugal.news, built from `https://promptugal.news/api/v1/newsroom/dashboard.json`. It shows agents as nodes, pulses for recent activity, handoffs flowing between nodes, a ticker of changes, and "this story, these agents".
  2. **Map rounds.** At least three switchable styles of the Algarve map: flat, 3D, and an abstract colour-coded grid/cartogram. The brief asked for design and data-science iteration.
- **Rules that still apply:**
  - Real data only. Anything simulated carries `SimulatedBadge`; nothing in Live is simulated.
  - Apple SDK only. iOS 18 minimum.
  - Read-only towards agents: nothing in the app starts, stops or steers an agent.
  - Never commit secrets.
  - Commit trailers: `Agent: appdev.live@promptugal.dinis` / `For: conductor.a.ios@promptugal.dinis`.

## 2. What you own

- **Code:** `Packages/PTLocal/Sources/PTLocal/Live/`, every file there. Outside it, the only edit is the "Watch the newsroom in action" card near the top of `Packages/PTLocal/Sources/PTLocal/NewsroomCentreView.swift`.
- **Tests:** `Packages/PTLocal/Tests/PTLocalTests/LiveTests.swift`.
- **Branch:** `work/live`.
  - Push only there.
  - Never push to `dev`, `main` or `night/**`; see section 4 for why `night/**` is off-limits.
  - As of this hand-over, `work/live` = `dev` at `e7d8470` (release v0.4.121). Everything I wrote is on `dev`.
- **Not mine, but uses my code:**
  - `Apps/PrompTugal/Shell/PlacesWiring.swift`: appdev.wire@ attaches `NewsroomLiveSection`, `TownNewsroomLive` and `AlgarveStyledMap` to the PTPlaces hooks.
  - `Packages/PTPlaces`: owned by ios.places@PrompTugal.dinis. It defines `.placesHomeAccessory`, `.placeAccessory` and `.placesRegionMap`.

## 3. What is in `Live/` (file by file)

| File | What it does |
| --- | --- |
| `LiveModels.swift` | `LiveDashboardExtras`: the dashboard fields the shared `NewsroomDashboard` does not keep, i.e. each agent's 24-char hour `grid` (`·` = quiet, anything else = fired), `commits_24h`, and `grid_hours`. Also `LiveEvent`, a ticker line with kind and origin (`latest`, `watched`, `sinceLastVisit`). Agent helpers: `handle`, `placeName`, and `lastSign(now:)`, which takes the later of `updated` and `last_wake.started`, clamped to now. |
| `NewsroomDiff.swift` | Pure functions. `latest(_:now:)` seeds the ticker from one dashboard. `changes(from:to:now:)` diffs two dashboards: updates with new `done` items, wakes, new asks, handoff count increases, joined agents. `placeChanges` diffs place files: new stories, new map entries, a site going live. Also `merge` and `roles(in:)`. |
| `LiveNewsroom.swift` | `@Observable` model. `LiveNewsroom.shared` is the one instance for the whole app. `run()` loops while the caller's task lives and polls only if the last read was 55 s or more ago, so several screens share one read a minute. It refreshes the place files every 5th poll. The first read is diffed against the copy cached from the device's last visit (`LocalDiskCache` key `live-dashboard-previous`). `activity(role:now:)` decays 1→0 over 30 min. |
| `NewsroomLayout.swift` | Pure layout in unit coordinates. Town agents are placed at their town's lat/lon inside `townBand`, relaxed apart with Dorling so Castro Marim and VRSA don't overlap. Region and country agents sit above. `*.places` desks sit on a two-wing arc. Other desks go in rows below. Handoff names not on the dashboard become "outside" nodes on the top edge. Also handoff curves, VoiceOver order (`spokenOrder`) and labels (`spoken`). |
| `NewsroomBoard.swift` | The board: one `Canvas` in a `TimelineView(.animation)` with pulses, sparks (2 min after a change was seen), handoff particles, selection by spatial tap, a 24h replay mode, and VoiceOver children per agent. With Reduce Motion: paused timeline and static halos. |
| `NewsroomLiveView.swift` | `public NewsroomLiveView(selecting:)`, the screen. Contents: headline numbers; board plus legend plus replay; selected-agent card (a town shows its 3 newest stories); "This story, these agents"; link to the maps; ticker (All/Towns/Desks/Asks); 24h fire grid; honesty note. On iPad (regular width) the board sits beside a 380-pt column with the agent card and the ticker. |
| `LiveStrips.swift` | `public NewsroomLiveSection()` for the places home: pulsing agent faces plus the last 3 ticker lines. `public TownNewsroomLive(placeID:)` for a place page: its agent, state, 24h strip and lines. Also `AgentFace`. |
| `LiveSummary.swift` | Headline numbers: active in 30 min, agent-hours fired in 24 h, handoffs in 24 h, asks waiting. |
| `LiveReplay.swift`, `ReplayControl.swift` | Replay the last 24 h from the hour grid: hour bars, scrubber, play. No autoplay under Reduce Motion. |
| `StoryAgents.swift` | "This story, these agents". `wrote` = the agent in the `by` field of each site carrying the story. `mentions` = a desk whose dashboard notes name the story's town or publisher. Also `newest(site:limit:)`. |
| `CartogramLayout.swift` | Pure maths: the 9×3 tile map positions of the 17 towns, true-proportion projection, Dorling relaxation (deterministic), radii by area, and a square-root intensity scale. |
| `AlgarveMapStyles.swift` | Standalone public component `AlgarveStyledMap(towns: [AlgarveMapTown], onOpen:)` with four styles:<br>• Map: flat.<br>• 3D: `.imagery(elevation: .realistic)`, camera pitched at 68°, tour Loulé → Faro → west to east (`AlgarveTour.order`), caption with the newest headline and the agent's own line.<br>• Grid and Cartogram: one view, so they morph into each other. Metric: stories, map entries or agent activity.<br>Also `AlgarveMapTown.fromLocalStore()`, and `AlgarveMapsView`, the PTLocal-hosted screen. |

**Where it appears in the app** (all on `dev`):
1. More → Newsroom → "Watch the newsroom in action" (`NewsroomLiveView`).
2. The Places home (`NewsroomLiveSection`) and every place page (`TownNewsroomLive`), via `PlacesWiring.swift`.
3. The Algarve page: `AlgarveStyledMap` replaces PTPlaces' satellite map via `.placesRegionMap`.
4. From the live screen, "The towns, four ways" opens `AlgarveMapsView`.

## 4. How the work runs (exact process)

- **No Mac here.** CI is the compiler: there is no Swift toolchain on the Linux container, and `which swift` returns nothing. Review your own code hard before pushing.
- **CI rule since 16 Nov 00:31 UTC.** Dinis set it because the shared macOS runners were flooded.
  - Push only to `work/live`, which has no CI.
  - Do **not** push to `night/live` or any `night/**` branch, because `ios.yml` runs on `night/**`, `dev` and PRs.
  - Batch your work. When a batch is ready, tell the conductor `ready at <sha>` with `send_message`, at most once an hour.
  - The conductor merges all workers into `work/candidate`/`night/going-local`, runs ONE build, and merges green candidates to `dev`. A push to `dev` uploads to TestFlight.
  - Don't cancel other people's runs. Ask the conductor if you need a compile check sooner.
- **Commands:**
  ```
  cd /home/user/PrompTugal__App__iOS
  git fetch origin dev work/live night/going-local
  git checkout work/live
  git merge --no-edit origin/dev   # or origin/night/going-local; never rebase a pushed branch (force-push is refused)
  # ... edit Packages/PTLocal/Sources/PTLocal/Live/*, Tests/PTLocalTests/LiveTests.swift ...
  git add -A Packages/PTLocal && git commit   # with the trailers above
  git push origin HEAD:work/live
  ```
- **Reading a CI failure.** Use the GitHub MCP tools; there is no `gh` CLI.
  1. `actions_list` with method `list_workflow_runs`, `resource_id: ios.yml`, branch filter. Then `list_workflow_jobs` for the run.
  2. Job logs are capped and the build step's errors are often outside the window. The reliable path is the **`mac-logs` artifact**: `list_workflow_run_artifacts`, then `download_workflow_run_artifact` (gives a temporary URL), then `curl` it into the scratchpad, `unzip`, and run:
     ```
     grep -rh "error:" x | sort -u
     grep -rhE "✘|recorded an issue" x
     ```
     `logs/PTLocal-build.log` and `logs/PTLocal.log` are yours.
- **Messages.**
  - Conductor: `send_message` to session `session_018yvwtNhGU1EEJs2oWCLqrJ`.
  - ios.places@: session `session_018yvwtMdYD3UV5XSJrL81sr`.
  - These session ids will change after the account move; ask the new conductor.
  - Use `send_later` to wake yourself, since nothing else wakes an idle session.

## 5. State

**Done, all on `dev`.** The milestones, in order:
- `9c382c9` first board and maps
- `d19cb1d` standalone map component, strips, shared watcher
- `7217206` type-check fix
- `62a97d9` replay
- `b414caf` town stories on the board, ticker filters
- `a18bbde` headline numbers, phone labels
- `2ea92d5` 3D captions
- `00b0be5` Loulé-first tour
- `5d6917e` iPad layout (round 4, green in run 555)
- `526db77` / `9cefa56` VoiceOver on the board (via candidate `a34acf6`)

PTLocal Live test suites were all green in integration runs 547 and 548 onward.

**Open / not done:**
- **3D flight polish.** The camera moves with `withAnimation(.easeInOut(duration: 4.5))` on `MapCameraPosition`. A nicer flight (zoom out, cross, zoom in) would use `.mapCameraKeyframeAnimator`. I didn't do it because of compile risk without a Mac; try it in a batch with nothing else risky.
- **`status.json` (`api/v1/newsroom/status.json`) is unused.** Its runs ledger stopped on 5 Nov. If the web team revives it, it has per-run events (`runs[]` with `when`, `agent`, `what`), which would give the ticker true per-event times and individual handoffs.
- **Handoffs are 24 h aggregates.** The dashboard's `handoffs` is `{from, to, n}` with only about 4 pairs, and several endpoints (curator, newsroom, Dinis) are not agents on the dashboard. They're drawn as "outside" nodes. A per-handoff feed from the web side would make the particles literal.
- **"This story, these agents" is shallow.** It credits the site agent (`by`) and desks whose notes mention the town or publisher. The place files have no per-story `found_by`; asking the web side for it, or for the `provenance` that ios.places@ reads from `/api/v1/by-place/<id>.json`, would make it exact.
- **Never looked at on a device or simulator.** Layout was reasoned, not seen. Check the board on an iPhone SE width and the iPad split.

**Half-done:** nothing. No local uncommitted work.

## 6. Lessons and traps

- **Type-checker timeouts are the main compile risk.** Run 526 failed on one long tuple `compactMap`/`sorted`/`map` chain. Prefer small structs, plain loops, and explicit `CGFloat` locals in Canvas maths. Avoid ternaries mixing `CGFloat` and `Double` literals.
- **`let x = x(...)` is an error.** A local named like the method it calls fails to compile. The board's helper is `lit(_:now:)` for that reason.
- **Keep testable logic out of `View` types.** Statics on a `View` are `@MainActor`, and calling them from nonisolated Swift Testing functions can fail. Pure logic lives in enums: `NewsroomLayout`, `NewsroomDiff`, `AlgarveCartogram`, `StoryAgents`, `LiveReplay`, `AlgarveTour`.
- **Agents write timestamps ahead of the clock** (e.g. `updated` 00:10Z at 23:26Z). Always clamp to now (`LiveClock.clamp`, `lastSign`).
- **The dashboard is about 500 KB.** One shared poller (`LiveNewsroom.shared`), one read a minute, minute-stamped query to beat caches. Don't add per-view pollers.
- **Force-push is blocked** by the permission classifier. Merge instead of rebasing a pushed branch.
- **`AlgarveView` (PTLocal) was dropped from the app.** PTPlaces is the Places reader. Don't build UI into `LocalViews.swift`; offer components through the PTPlaces hooks instead.
- **Shared Macs are scarce.** Respect the CI rule (section 4); builds took 20-30 min when flooded, about 6-10 min after dev's CI speed-up.

## 7. First things the next session must do

1. Read [`../tonight.md`](../tonight.md), [`../README.md`](../README.md) and this file. Check out `work/live` and run `git merge origin/dev`.
2. Find out who the conductor is now (after the account move) and confirm the CI rule still holds before pushing anything.
3. Open `Packages/PTLocal/Sources/PTLocal/Live/NewsroomLiveView.swift` and `LiveTests.swift` to get oriented. Fetch `dashboard.json` with curl to see the live shape; check whether `grid`, `last_wake`, `handoffs` and `updated` have changed.
4. If you get a device or simulator: look at the board on a phone and an iPad, and fix label crowding and timing by eye.
5. Then pick from "Open" in section 5. The keyframe-animated 3D flight and exact story provenance are the highest-value next steps.
