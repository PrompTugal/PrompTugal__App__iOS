# Hand-over: conductor.a.ios@promptugal.dinis (16 Nov 2026, ~15:30 UTC)

> Written at Dinis's word (relayed by conductor@PrompTugal.dinis): pause all PrompTugal agents so they can move to other team members' accounts, and leave a debrief so no context is lost. Read this first, then `tonight.md` (build history and the morning summary) and `README.md` (the going-local plan) in this folder.

## 1. Who I am and what I was asked to do

- **Identity:** conductor.a.ios@promptugal.dinis. I conduct the iOS repository PrompTugal/PrompTugal__App__iOS, working from branch `dev`. I run as a Claude Code cloud session for Dinis Cruz.
- **Mandate (from 15 Nov ~22:57 and ~23:30):** make the news app (`Apps/PrompTugal`, bundle `news.promptugal.reader`) the reader and command centre for PrompTugal.news by place: the Algarve, its 17 towns, and now Portugal's district capitals. The night's brief, in full, is in `tonight.md`. In short:
  - show the agents in action;
  - read dynamic JSON;
  - "near me";
  - Apple Intelligence summaries and personas;
  - contribute and talk to the conductor through sealed lanes;
  - a CI status page with "update available";
  - maps and visualisations;
  - pay per use at the website's prices;
  - the version number visible in the UI.
- **Hard rules:**
  - Read-only towards agents: nothing in the app starts, stops or steers an agent.
  - Anything simulated carries the visible "Simulated" badge.
  - Every story links to its source.
  - Every screen says whether its data is live, cached or the built-in snapshot.
  - Contacts appear only where a public site publishes them, with the source link.
  - Never commit a secret.
  - Don't change the App Store listing until Dinis approves the name.
  - Don't open PRs unless asked.

### My workers (cloud sessions I created; all told at 15:25 to debrief and stop)

| Worker | Session | Branch | Owns |
| --- | --- | --- | --- |
| appdev.live@ | session_018yvwtLXAwT2ujoryoLJEeb | work/live | `Packages/PTLocal/Sources/PTLocal/Live/`: live newsroom board, strips, 4 Algarve map styles, 3D flights, VoiceOver |
| appdev.ai@ | session_018yvwtNSzENYgwWJPDM6Nmj | work/ai | `PTLocal/.../AI/`: Foundation Models (weak-linked), persona ranker, Near me, IPMA ConditionsCard, Ask and summarise |
| appdev.talk@ | session_018yvwtN649CDbGrQRz7NZvy | work/talk | `Packages/PTTalk`: TalkTransport (sealed lanes), composers; `.conductor` uses the agreed comment lane |
| devops.status@ | session_018yvwtNFbNWmCjkR8yDWmMT | work/status | `ci-status.yml`, the `ios.yml` speed-ups, `scripts/testflight/tf.py set-app-info` + `app-info.json`, `PTLocal/.../Status/` |
| appdev.credit@ | session_018yvwtQwWn2sH8hzYVhSFoR | work/credit | `PTLocal/.../Credit/`: LocalCredit, meter.json prices, £5 start, StoreKit 2 top-ups, "where your credit goes" |
| appdev.wire@ | session_018yvwtLLmNUF2TxWtJySkuz | work/wire | `Apps/PrompTugal/Shell/` wiring (PlacesWiring.swift, version label, StoryWhen, summit cards) |

Their debriefs go to `briefs/2026-11-15__going-local/debriefs/<name>.md` on their own work/ branches. They were not merged when I stopped, so fetch those branches.

**Peers:**
- **ios.places@PrompTugal.dinis** (session_018yvwtMdYD3UV5XSJrL81sr): owned by the main conductor, not me. Owns `Packages/PTPlaces` (the Places tab, Across Portugal, "Now in <place>"). Pushes `night/ios-places`, which I merge to dev.
- **conductor@PrompTugal.dinis**: the main/web conductor, session_018yvwtMe4xXJFw1aRGHvua4.
- **conductor@web-summit.dinis**: session_018yvwtMPVc6R9iMzkBcVpE2.
- **VoiceDebrief conductor**: session_018yvwtN2tecTKQP9tjD8fq6. It asked to be messaged only when something changes.

## 2. How I operate

### Code layout

- **PTLocal** (mine) holds Live, AI, Credit, Status, `LocalStore` and the place models. `Lenient<T>` decoding means one bad item never hides the rest.
- **PTPlaces** (ios.places@) is the Places reader. It exposes these hooks:
  - `.placeAccessory`
  - `.placesHomeAccessory`
  - `.placesRegionMap`
  - the `PlacesCredit` closure
- **PTTalk** holds the lanes.
- **`apps.json`** lists each app's packages. `scripts/apps/check_apps.py` must pass before any push to dev.
- **The snapshot:** `scripts/places/snapshot.py` copies `data/by-place/*.json` into `PTLocal/Resources`. `--check` validates them.

### CI process (rule since 00:35, after the runner flood)

1. Workers push only to `work/<name>`, which triggers no CI, and send me "ready at <sha>".
2. I build a candidate:

   ```
   git fetch origin
   git checkout -B rN origin/dev
   git merge --no-ff origin/work/<a> origin/work/<b> ...
   ```

   On a VERSION conflict, take dev's: `git checkout origin/dev -- VERSION`. Then run `python3 scripts/apps/check_apps.py`, then `git push -f origin rN:work/candidate`.
3. Dispatch one quick run (GitHub MCP `actions_run_trigger`, `run_workflow`):
   - workflow `ios.yml`
   - ref `work/candidate`
   - inputs `{"app":"promptugal","quick":true}`

   This builds and runs the iPhone tests, in about 12–15 minutes.
4. If green, merge to dev:

   ```
   git checkout -B rNd origin/dev
   git merge --no-ff origin/work/candidate -m "Merge … green in ios.yml run <id>"
   ```

   Then check_apps, then `git push origin rNd:dev`.
5. A dev push builds the changed apps, runs the iPhone tests, then signs and uploads to TestFlight (news app first). TestFlight processing runs as its own job. `release: vX.Y.Z` bot commits follow automatically.
6. Build state: read
   `https://raw.githubusercontent.com/PrompTugal/PrompTugal__App__iOS/ci-status/ci-status.json`
   at `testflight.apps.promptugal` (`build`, `version`, `processed`, `processedAt`, `runNumber`). Push to processed takes 20–45 minutes when a Mac is free.

ios.places@ runs its own CI on `night/ios-places`, at most hourly. I merge that branch straight to dev once its run is green. I wait for any dev run's upload step to finish first. `ios.yml` has `cancel-in-progress: false` per ref, so nothing gets cancelled, but uploads stay in order.

### My schedule (now disabled)

- **Task:** `trig_01A2aPmNYVb7aoXDfvYfE5wj`, "PrompTugal iOS conductor: hourly round", cron `26 * * * *`. Disabled 15:23 UTC 16 Nov.
- **Prompt, verbatim:**

  > Hourly round (Dinis presents in the morning). 1) ReadNotifications. 2) Check CI for night/going-local and the workers' branches (work/live, work/ai, work/talk, work/status, work/credit and their night/* twins) with the GitHub MCP actions tools. 3) Merge any green worker round into night/going-local, re-run CI; when night/going-local is green, merge to dev (dev push = TestFlight upload) and note the build. 4) Drain Dinis's inbox lane: python3 <scratchpad>/ref/vd/tools/conductor/conductor.py --home ~/.promptugal-conductor-2 drain (lane 2, key sha256:6aa850c442c96ec6; never print or send its keys) and act on his messages/screenshots. 5) Check workers with list_sessions children; unblock or restart stuck ones. 6) Send conductor@web-summit.dinis (session_018yvwtMPVc6R9iMzkBcVpE2) a two-line status; message the VoiceDebrief conductor (session_018yvwtN2tecTKQP9tjD8fq6) ONLY when something changes (new build, blocker, or a message from the owner) — no "unchanged" notes (its request, 07:28). 7) When conductor@ sends the agreed name/subtitle/description and Dinis approves, set them in App Store Connect via the testflight-ops set-app-info action. Keep briefs/2026-11-15__going-local/ current.

- **Note:** `night/going-local` in that prompt is out of date. The real flow is the work/candidate process above.
- **One-off checks:** I scheduled them with `send_later`, about 15–30 minutes after a dev push, to report the build number to Dinis.

### Dinis's inbox lane (owner-only append lane)

- **Tool:** VoiceDebrief's `tools/conductor/conductor.py`. Clone VoiceDebrief/VoiceDebrief__App__iOS (public) and use its `setup`, `link`, `qr`, `selftest` and `drain` commands.
- **Envelope:** hybrid v2, RSA-OAEP-SHA256 plus AES-256-GCM.
- **Lane 2:** home `~/.promptugal-conductor-2`, key fingerprint `sha256:6aa850c442c96ec6`. Lane 1 was retired: its private key went out in plaintext (my mistake), so I rotated and shredded it.
- **The private key** exists only in this container and **sealed to the main conductor's key** (handed over on 16 Nov). It is not in git. A new session cannot drain lane 2 unless the main conductor unseals the key into it. The simpler option is to create lane 3 with `conductor.py setup`, seal its private key to the main conductor, and give Dinis the new write QR/link only through his own channel.
- **The app has no built-in lane link.** Dinis enters it by QR or paste.
- **Still open:** owner-only is not cryptographically enforced. The receiving side doesn't verify signatures yet. Dinis accepted that for now, since only he and a few internal people have the app.

## 3. State at hand-over

- **dev:** `e7d8470` (release v0.4.121), docs only after 9387f4b.
- **TestFlight, news app:**

  | Build | Version | Processed | What it is |
  | --- | --- | --- | --- |
  | **667** | 0.4.120 | 11:44 UTC | Latest: "Now in <place>" |
  | 664 | 0.4.118 | | Across Portugal; the safe fallback |
  | 662 | | | VoiceOver on the live board |
  | 660 | | | Opens on Places, place comments |

  The full table is in `tonight.md`.
- **Done and on dev:** everything in the table in `tonight.md`, plus run 566/567. 1057a4d dropped ConditionsCard from the place accessory because "Now in <place>" (website `api/v1/by-place/<id>/now.json`) replaces it. `ConditionsCard` and `ConditionsLine` still exist in PTLocal/AI but nothing uses them.
- **Nothing pending on any work/ branch** at 15:20 except the workers' coming debriefs.
- **Waiting on Dinis:**
  1. **App Store name and subtitle.** Proposal: "PrompTugal.news" and "Local news, town by town, every fact sourced". The app still shows "PrompTugal: Lisbon Summit". Once he approves, edit `scripts/testflight/app-info.json` and run the testflight-ops `set-app-info` action.
  2. **Faster Mac builds:** larger macOS runners or a self-hosted Mac.
- **Open, not started:**
  - signature verification on lane receive;
  - joining multi-part messages across drains in `conductor.py`;
  - App Store Connect IAP products for credit top-ups, needed before release;
  - a device run of the Apple Intelligence paths (only CI so far);
  - the "For you" persona card placement, which appdev.ai@ hasn't confirmed;
  - the website-side asks: investment map data, per-place live signals.
- **Branch housekeeping:** `work/candidate` is a throwaway (force-pushed). Many `night/*` branches from 7–9 Nov are stale and unrelated.

## 4. Lessons learned

- **The macOS runner flood is the main trap.** Every push to a CI-triggering branch costs 15–35 minutes of a shared Mac. Around 00:30, about 30 runs an hour queued behind each other. What fixed it:
  - workers push to non-CI `work/*` branches;
  - one candidate run per batch;
  - "Already on dev?" skips duplicates;
  - only changed apps build;
  - no Release build on night branches;
  - iPhone-only tests on dev;
  - the news app uploads first.

  Night runs went from about 35 minutes to about 7, and push to processed is now 20–45 minutes.
- **Changing `apps.json`** makes every branch build all apps until it lands on dev. Batch such changes.
- **VERSION conflicts on every merge.** Always take dev's VERSION; the release bot bumps it.
- **Swift pitfalls that broke CI tonight:**
  - a public init default argument that uses internal `Bundle.module` (fixed with `LocalResources.bundle`);
  - type-checker timeouts on long SwiftUI expressions (split them);
  - `self` used before init in `@Observable` classes;
  - a lenient array decoder that looped forever (now `Lenient<T>`);
  - test fixtures whose needles were prefixes of each other ("topic1" matched "topic10").
- **Duplicate work.** Two readers got built (mine and ios.places@'s). Settle ownership early. Here, ios.places@ owns the Places UI and PTLocal provides layers through hooks.
- **Secrets.** Never paste a private key into a message, not even to a trusted conductor. Seal it. Lane 1 had to be rotated because of exactly this.
- **Freeze before a demo.** Keep only data and crash fixes, and announce it to the workers. It held from about 05:00 until Dinis's own 10:40 ask.
- **Peer messages:** send "unchanged" notes only to those who want them.

## 5. Identity and secrets (ids only)

- **Lane 2 private key** (fingerprint `sha256:6aa850c442c96ec6`): in `~/.promptugal-conductor-2` in this container, and sealed to the main conductor. Not in git.
- **CI signing secrets** (App Store Connect API key, certificates, profiles): GitHub Actions secrets of the repository, used by `ios.yml`. I never held their values.
- **No other keys, tokens or vault keys** were held by this session.

## 6. What the next session must do first

1. Read this file, then `tonight.md` and `README.md` in this folder, then the six worker debriefs (fetch `work/live`, `work/ai`, `work/talk`, `work/status`, `work/credit`, `work/wire`).
2. Confirm dev builds green and check `ci-status.json`. The latest TestFlight build should be 667 or newer.
3. Ask Dinis about the App Store name and subtitle and about faster Macs. Don't set the name without his explicit yes.
4. Re-establish the inbox lane. Get lane 2's key from the main conductor, or create lane 3 (`conductor.py setup`, seal the private key to the main conductor, QR only to Dinis). Never print a key.
5. Recreate the hourly round as a scheduled task, using the corrected work/candidate flow above, only if Dinis wants rounds to resume. Stagger it against the other agents' minutes.
6. Restart workers only for the open items in section 3, one owner per path, each pushing to `work/<name>`.
