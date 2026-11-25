# Debrief: workstream B ("ai"): Apple Intelligence, persona mode, Near me, IPMA conditions

> By appdev.ai@promptugal.dinis, for conductor.a.ios@promptugal.dinis and whichever fresh session picks this up.
> Written 16 November 2026, about 15:30 UTC, when Dinis paused the PrompTugal agents to move them to other
> team members' accounts. No key, token or credential appears in this file, and none was ever needed: every data
> source here is public.

## 1. Who I was and what my mandate was

- **Agent:** `appdev.ai@promptugal.dinis`, a worker under `conductor.a.ios@promptugal.dinis` (conductor session
  `session_018yvwtNhGU1EEJs2oWCLqrJ`), in the repository `PrompTugal/PrompTugal__App__iOS`.
- **Brief:** workstream B of `briefs/2026-11-15__going-local/tonight.md`, Dinis's voice brief of 15 November, about
  23:30. Read that file and `briefs/2026-11-15__going-local/README.md` first. Dinis presented on the morning of 16
  November.
- **Asked for:**
  1. Apple Intelligence (Foundation Models) on the device, weak-linked so iOS 18 still launches, with honest
     "not available" states: summarise a town from its by-place JSON, summarise a story, "explain the AI path",
     streamed and labelled as generated on the device.
  2. Persona mode: pick or type who you are ("I am from Algarve Evolution", "I invest in health tech"). The Algarve
     home and town pages reorder and highlight what matters to that persona, with a deterministic ranking that works
     without the model, enhanced by the model where it is available.
  3. Location while using the app: "Near me" finds the nearest of the 17 towns and shows its news first. It works
     without permission by letting the user pick a town.
  4. Added by the conductor at about 00:32: LOCAL CONDITIONS from IPMA open data (warnings, forecast, station
     observations) in a "Conditions now" card.
- **Rules:**
  - Real data only. Anything simulated carries `SimulatedBadge`; nothing I built is simulated.
  - Apple SDK only.
  - CI is the compiler: there is no Mac and no Swift toolchain in the sandbox.
  - Never push to `dev` or `main`.
  - Commit trailers: `Agent: appdev.ai@promptugal.dinis` / `For: conductor.a.ios@promptugal.dinis`.

## 2. What I own

The branch is **`work/ai`**. At hand-over it equals `origin/dev` (`e7d8470`, release v0.4.121) plus this debrief.
Everything of mine is merged into `dev` and shipped in TestFlight (build 654 and later).

| Path | What it is |
| --- | --- |
| `Packages/PTLocal/Sources/PTLocal/AI/LocalModel.swift` | `LocalModel`. Foundation Models behind `#if canImport(FoundationModels)` and `if #available(iOS 26.0, *)`. Provides `status` (with an honest reason: device not eligible, switched off, model downloading, iOS too old, no SDK) and `stream(instructions:prompt:onText:)`: one fresh `LanguageModelSession` per request, streamed. Ported from VoiceDebrief `Engine/OnDeviceModel.swift` and `LabModelDoor.swift` (Apache 2.0; attribution is in the file header) and from this repo's `Apps/RiskMandate/Sources/Workbench/OnDeviceModel.swift`. |
| `.../AI/LocalPrompts.swift` | Pure prompt builders: town summary (from `PlaceSite`, the decoded by-place JSON), story summary, "explain the AI path", persona briefing. A character budget (6,000) keeps prompts inside the model's small context window, and the prompt says what was left out. |
| `.../AI/Persona.swift` | `Persona` (Codable; `keywords` and `townID` are optional), the presets, and `Persona.fromData` (one-tap personas: the most-mentioned AI-map organisations, with aliases such as UAlg and "University of the Algarve"). `Persona.startup(in:)`. `PersonaStore` (UserDefaults key `local.persona`; the model's suggestions are kept in memory only). `PersonaRanker`, the deterministic ranking: names weigh 5, topic concepts and the reader's own words 2, the model's suggested words 1. Title ×3, summary ×2, AI path ×1. Accent-insensitive, whole-word, with `*` for a prefix match. A stable sort, so pages don't jump. A town boost of +4 that says "in <town>". `suggestedTerms(from:existing:)` parses the model's comma list. |
| `.../AI/NearMe.swift` | `NearMe.nearest` (haversine, pure), `NearestTown` (counts as local within 30 km), and `NearMeLocator` (`@Observable`): `CLLocationManager`, when in use only, asked only on a tap, one fix per tap, accuracy to the kilometre. Only the nearest town id is kept. A town picked by hand is stored under UserDefaults `local.nearme.picked`. The delegate is a separate `NSObject` class (`LocationDelegate`) so the observable stays a plain class. |
| `.../AI/LocalAIViews.swift` | Public views: `TownSummaryCard(site:)`, `StorySummaryButton(story:town:)` (opens `StoryAISheet`), `PersonaBanner`, `PersonaPicker`, `PersonaForYouCard`, `PersonaToolbarButton`, `NearMeView`. Internal: `OnDeviceAsk`, `OnDeviceCard`, `OnDeviceAnswer`, `LocalModelStatusLine`, `PersonaMatchChip`. |
| `.../AI/LocalAIRows.swift` | `AIStoryRow`, `AIEntryRow`, `AITownHeader`: self-contained rows with serif headlines and town accents, as PTPlaces draws them. |
| `.../AI/AskAndSummariseView.swift` | The standalone demo screen, More → "Ask and summarise" (destination id `local.ask`). |
| `.../AI/Conditions/IPMA.swift` | IPMA open data, public and keyless: warnings (`warnings_www.json`, area `FAR` = the Algarve), the daily forecast for Faro 1080500, Loulé 1080800, Portimão 1081100 and Sagres 1081505 (each town uses the nearest), station observations plus the station list, and the nearest station within 40 km that has a reading in the last 3 hours, preferring one with both temperature and wind. -99 means missing. Includes the wind codes and IPMA's weather-type table. |
| `.../AI/Conditions/ConditionsStore.swift` | Reads at most every 10 minutes, keeps a disk cache (`LocalDiskCache`, keys `ipma-*`), labels its data live or offline. |
| `.../AI/Conditions/ConditionsCard.swift` | `ConditionsCard(placeID:)` and `ConditionsLine(placeID:)`. The Algarve page reads near Faro and says so; the Portugal page shows nothing. |
| `Packages/PTLocal/Tests/PTLocalTests/LocalAITests.swift`, `ConditionsTests.swift` | Swift Testing suites: "Persona ranking", "Near me", "On-device prompts", "Apple Intelligence's persona words", "Personas from the data", "IPMA conditions". All green on dev. |
| `Apps/PrompTugal/PrompTugal.xcconfig` | `OTHER_LDFLAGS = $(inherited) -weak_framework FoundationModels`. **Keep it.** Without it, iOS 18 devices crash at launch. |
| `Apps/PrompTugal/Info.plist` | `NSLocationWhenInUseUsageDescription` with an honest reason, plus a comment. |
| `Apps/PrompTugal/Resources/PrivacyInfo.xcprivacy` | A comment only. Location never leaves the device, so no data type is "collected" in Apple's sense. |
| `Apps/PrompTugal/Shell/Destinations.swift`, `PublicSettingsView.swift` | The More entry for Ask and summarise. Since then the shell belongs to the wiring worker (appdev.wire@). |

## 3. Where my pieces show in the app (on dev, as of e7d8470)

`Apps/PrompTugal/Shell/PlacesWiring.swift` belongs to appdev.wire@. It hosts my views through PTPlaces' public hooks
(`Packages/PTPlaces/Sources/PTPlaces/PlacesHooks.swift`, owned by ios.places@):

- **Places home** (`PlacesHomeLayers`): `NewsroomLiveSection()`, then `PersonaBanner()`, `PersonaForYouCard()` and
  `NearMeView()`. **The For-you card is confirmed wired on dev.** It was the open question at 04:00; it landed.
- **Place page** (`PlaceLayers`): `TownNewsroomLive` and `TownSummaryCard(site:)`, the latter only when
  `LocalStore` has the town. **`ConditionsCard` was deliberately removed from the place page** in `1057a4d` ("shell:
  drop ConditionsCard from the place accessory; ios.places' 'Now in <place>' panel shows the same IPMA data (and
  more) from the website's now.json"). The card still appears on Ask and summarise, and `ConditionsLine` sits under
  the town in Near me.
- **More → Ask and summarise:** all the pieces on one screen.

## 4. How I worked (the process that held by the end of the night)

- **The repository:** `git clone https://github.com/PrompTugal/PrompTugal__App__iOS`, work on `work/ai`. There is
  no `gh` CLI in the cloud sandbox: use the GitHub MCP tools (`actions_list`, `actions_get`, `get_job_logs`).
- **CI rule (from about 00:30 on 16 November, Dinis: the shared Macs were flooded):**
  - Push **only to `work/ai`**, which has no CI.
  - Do not push to `night/*` and do not dispatch runs.
  - Tell the conductor "ready at <sha>" at most hourly. The conductor merges every worker into `night/going-local`,
    runs ONE build (`ios.yml`), then moves green work to `dev`. A push to `dev` builds and uploads to TestFlight.
  - Never cancel anyone else's run.
- **Before that rule:** `ios.yml` built `night/**` pushes, so I pushed the same commit to `work/ai` and `night/ai`.
  Don't do that any more.
- **Reading a failed run:** `get_job_logs` truncates and times out on these logs (more than 1 MB). What worked:
  `actions_get` → `get_workflow_run_logs_url`, then `curl -sSL -o logs.zip "<url>"` into a scratch folder,
  `unzip`, and these two greps:

  ```
  grep -rhoE "[^ ]*\.swift:[0-9]+:[0-9]+: error: .*" . | sort -u
  grep -rh "Failed: \|✘ Test\|recorded an issue" . | sort -u
  ```

  The job's last lines also say `Failed: promptugal: Debug build package PTLocal: build` (or similar), naming the
  part that failed.
- **Timing:** a full macOS run took 25 to 40 minutes, and runs queue behind each other. Use
  `mcp__claude-code-remote__send_later` (every 40 to 60 minutes) or a background `sleep`, never a foreground sleep.
- **Talking to the conductor:** `mcp__claude-code-remote__send_message` with session_id
  `session_018yvwtNhGU1EEJs2oWCLqrJ`. Say the branch, the sha, the run, and what to look at.
- **Commits** end with the Agent/For trailers above, plus the session's attribution lines.

## 5. State

**Done, merged to `dev` and green** (dev run 550, `3b0a6cb`, and later releases through v0.4.121; TestFlight 654 and
later):

- `9b40e4e`, `f90dff5`, `9e54b25`: the AI pieces, persona mode, Near me, the Ask and summarise screen, tests. First
  green: run 521 on `night/ai`.
- `ba1d0c0`: IPMA conditions.
- `a492e5a`: compile-safety tidy.
- `c05ea8c`: "Widen with Apple Intelligence" (the model's suggested persona words, weight 1, labelled as its own).
- `f87b814`: `ConditionsLine` under the Near me town.
- `cb32cb1`: one-tap personas from the data, a startup in your town, an investor.
- `e7d2e87`: the Conditions card on the Algarve page reads near Faro; nothing on Portugal.
- `a13d2ab`: merged dev with the conductor's test-only fix `3b0a6cb`.

**Open, never verified:**

1. **No device run, ever.** CI compiles and runs unit tests only. Never seen running on a real device:
   - the streamed Foundation Models output (TownSummaryCard, StoryAISheet, the persona briefing, "Widen with Apple
     Intelligence");
   - the location prompt and fix;
   - the live IPMA fetch in the app. The feeds were checked by curl, and the parsing is tested on fixtures in the
     same shapes.

   First job: install the TestFlight build on an iOS 26 device with Apple Intelligence on, and on an iOS 18 device
   to check the launch and the "not available" text.
2. **`LanguageModelSession(instructions: String)` and `streamResponse(to:)` with `snapshot.content`** compile with
   Xcode 26.6 (the iOS 26.5 SDK) on the runner. If a later SDK changes the shapes, `LocalModel.swift` is the only file
   to touch. Error mapping deliberately falls back to the error's own words, because the error cases changed between
   SDKs (VoiceDebrief's note).
3. **Persona mode does not reorder PTPlaces' own story lists.** It adds the "For you" card on the home and the
   persona-led town summary. To reorder PTPlaces' lists, ios.places@ would need a hook, or would call
   `PersonaStore.shared.match(_:)` / `PersonaRanker.order(_:by:)`. That was not asked of them.
4. **The model's suggested words live in memory only.** They reset on relaunch and when the persona changes. That is
   intended, but it may surprise someone.
5. **IPMA observations are about 1 MB and are decoded on the main actor** every 10 minutes while a card is visible.
   That's fine for the demo. Move the decode off the main actor if it ever shows as a hitch.

**Half-done:** nothing. There is no uncommitted work.

## 6. Lessons and traps

- **Bundle.module is internal.** Never use it as a default argument of a public init. Use
  `LocalResources.bundle`. In a test target, `bundle: .module` is wrong: use the store's default.
- **Tuple patterns in conditions:** `if let (a, b) = optionalTuple` does not compile. Use labelled tuples and
  `result?.data`.
- **Mixing NSObject and @Observable** (`override init` on a `@MainActor` class) is fragile. Keep the
  `CLLocationManagerDelegate` in a separate `NSObject` class that holds a weak owner and hops to `@MainActor`.
- **Name the tuple labels explicitly** when a `compactMap` must produce `[(info: PlaceInfo, site: PlaceSite)]`.
- **Prefix needles cover their own extensions** (`topic1*` covers `topic10`). The dedup relies on that on purpose;
  test fixtures must use words that are not prefixes of each other.
- **Ranking:** place names count for nothing ("Algarve" is in every story). Names in the persona's text are runs of
  two or more capitalised words, split at punctuation, and are dropped if they are only places. Count mentions as
  whole words: the substring "arte" is in "parte".
- **IPMA:**
  - Warning times are Portugal local time with no zone. Observation hours are UTC.
  - There is no gust field in observations.json.
  - Wind code 9 is north too, and 0 is calm or variable.
  - Area `FAR` covers the whole Algarve.
  - The 1 MB observations file needs `maxBytes` above `HTTPClient`'s 1 MB default (I use 4 MB).
- **Scope moved twice in the first hour:** AlgarveView/TownView were dropped for PTPlaces, then everything had to be
  self-contained public pieces. Keep views self-contained (own rows, plain inputs), so whoever owns the shell can
  host them.
- **Before pushing, merge `origin/night/going-local` or `origin/dev` into the work branch** so the conductor's merge
  is clean. Fixes to other people's code arrive that way, and you need them for your next run.
- **Don't trust a failed integrated run to be yours.** Twice the failure was another worker's (Credit). Grep the
  errors and the `✘ Test` lines, and report precisely.

## 7. First things the next session must do

1. Read `briefs/2026-11-15__going-local/tonight.md`, `README.md`, then this file. Ask the conductor (or Dinis)
   whether workstream B continues, and under which agent name and branch.
2. `git fetch origin && git checkout -B work/ai origin/work/ai`, then `git merge origin/dev`.
3. Get one **device run** (TestFlight) and fix what it shows: Apple Intelligence available and unavailable, the
   location prompt, IPMA live. That is the biggest unknown.
4. Check `Apps/PrompTugal/Shell/PlacesWiring.swift` on dev for what is wired now, before changing any public API in
   `PTLocal/AI` that the shell depends on: `PersonaBanner`, `PersonaForYouCard`, `NearMeView`, `TownSummaryCard`,
   `AskAndSummariseView`, `ConditionsCard`.
5. Follow the CI rule: push to the work branch only, say "ready at <sha>", one integrated build.
