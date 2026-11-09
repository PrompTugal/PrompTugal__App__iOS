---
title: "WS-181: the venues: PrompTugal.news as the one guide, public for all, with the team's layer private to us"
by: dev@PrompTugal.angelo, with vault@PrompTugal.angelo (vaults.md)
written: 2026-11-07
for: Angelo, reviewed with desk.conductor@PrompTugal.angelo; findings from policy@PrompTugal.angelo; security@web-summit.dinis reviews before any real location is stored
issue: WS-181
status: "Approved by Angelo, 7 November 2026: Part A (daca6e6c, \"All as recommended\"; 592d1096, \"Agreed on C\") and Part B as revised (2254b43f: PrompTugal.news holds it all). Part B's team layer waits for security@web-summit.dinis's review and vault@'s token."
---
This spec gathers WS-181 into one place for dev.venues@PrompTugal.angelo. The detail stays where it was written: the page and its two modes in [page.md](page.md), the two vaults and the sync in vault@'s [vaults.md](vaults.md). Where they differ, this spec and Angelo's decisions win.

## What and why

Angelo's notes of the 12:00 stand-up, 6 November: *"coordinate the team and our logistics using the page Angelo has been putting together in the command center, we need to know where everybody is"*. It works in two vaults (public, private) and two modes (local storage first, synced to the vaults). On 7 November (c7d26a01) he added: *"integrate the venues map with the feature offered in the promptugal news website, with the public section and the private info about our locations only available to us (optionally public if we decide to be trackable)."*

## Part A: the team's board (approved)

**Angelo's decisions, 7 November** (daca6e6c, "All as recommended"; 592d1096, "Agreed on C"):

| | Decision |
|---|---|
| a | **The whole team sees** where people are. Anyone opts out by setting nothing. |
| b | **The places:** dev@'s list in page.md, adjusted after a day of use (now the venue drawing's buildings: the four pavilions, the MEO Arena, Pavilhão de Portugal, Oriente station, the Vasco da Gama centre; and, off the map, hotel, in town, off). |
| c | **The private vault is deleted by 14 November** (`sgit vault delete-on-remote`); nothing copied from it. |
| d | **security@web-summit.dinis reviews** before any real location is stored (Angelo's go for this handover). |
| e | **The step-1 demo first**, with no real data (built: `#where` in Angelo's command centre). |
| C | **Zones by default; an exact pin only by a person's choice, each time** (built in the demo on 7 November, 4dead814). |

**How a line and a pin are stored, and who sees them** (vaults.md, "Zones by default"):
- **A line:** `{person, place, next, until, at}`, where `place` is a zone from the list, never coordinates.
- **An exact pin:** taken only when the person chooses it, for that one update. It is stored beside the zone as `pin: {lat, lon, label, until}`, with `until` at most a few hours ahead. It is signed with the person's site key like the line, never remembered as a default, and never offered for a home or a hotel.
- **Who sees it:**
  - Lines and pins: the team only (the private vault's readers).
  - The public layer: never a person's line or pin.
  - A person who opts in to being public (Part B) publishes a zone only, never a pin.
- **History:** a vault keeps every past state, so every pin stays readable to the team until the vault is deleted (decision c).

**What is built, and in what order:**
1. **Done, the demo:** `people/angelo/app/where.js`, by dev@ and dashboard@PrompTugal.angelo. It has the stylised venue drawing from OpenStreetMap's outlines (`venue-map.js`, ODbL), the two modes on one device, zones by default and the deliberate pin. Its test is `people/angelo/app/tests/wzone.test.js`.
2. **Next, dev.venues@, demo data only:** the board read from a local copy and a queue, ready for the vault (page.md section 3). No real location yet.
3. **After security's review and vault@'s own SG/Send token:** the private vault.
   - vault@ creates the vaults.
   - The page reads them with the person's key, through a site script in `assets/`, not Angelo's folder. The gate's rule 22 (WS-164) keeps the keyring and IndexedDB out of people's scripts.
   - Signed, sealed updates go over the append lane.
   - That site script is shared code. The five steps say who owns it: the page's keyring is Dinis's.
4. **By 14 November:** the vault is deleted, and the view says so and clears the local copy.

**Where it lives** (2254b43f): PrompTugal.news holds it all (Part B). The demo in Angelo's command centre (`#where`) stays until the team's layer works on the newsroom's map. Then it becomes a link to the newsroom's venue map, and steps 2 and 3 above are built there, not here.

## Part B: PrompTugal.news, the one guide (approved, 2254b43f)

Angelo, 7 November about 15:20 UTC: *"I want the public PT News guide to become the ultimate guide for everyone, the team and everybody else. So everything can stay there, with our private info only available to us."*

**What is there now:**
- The newsroom has the summit's events (`newsroom/build/features/events.mjs`, `days.mjs`) and the reader's **My day** (`features/schedule.mjs`, `assets/schedule/schedule.js`, `content/my-day.md`).
- My day keeps picks in the browser and, when the reader's vault is open, in it (`window.__vault`, `agenda/picks`). Its gate forbids any `fetch`, XHR, beacon or socket in `schedule.js`.
- **Sign-in and keys:**
  - `assets/login/keyring.js` (`window.PTKeyring`) holds a person's key in this browser, as non-extractable keys in IndexedDB. It can open what is sealed to them, and sign.
  - `assets/login/login.js` (`window.PTLogin`) proves the key against `board/person-keys.json`.
  - The newsroom's conductor issues these keys (`newsroom/tools/person-key.mjs`). They are this origin's own: a key held on web-summit.sgit.ai is not seen here.
- **The reader's own vault:** `assets/vault/` (boot.js, vault-core.js, door.js with passkeys, sync.js).
- There is no venue map.

### B1. Public, for everyone (build these first)

1. **`/summit/venue/`:**
   - the stylised venue drawing (OpenStreetMap's outlines, with the ODbL attribution);
   - each building labelled with what the newsroom's events data puts there (stages, pavilions, today's sessions);
   - **no people on it, ever.**
2. **"Where is it?" on every event page:** the event's building, picked out on a small copy of the map, from the event's stage. A stage with no known building is left unplaced, never guessed.
3. **My day on the map:** a reader's picks drawn on the venue map, in their browser only, under the same no-network rule as `schedule.js`.

### B2. The team's layer, private to us (after security@web-summit.dinis's review and vault@'s token)

- **What it is:** the team's board and whereabouts (Part A's lines, zones and chosen pins) on the same newsroom map.
- **Who sees it:** only a reader who opens the team's private vault with their own key, as My day opens a reader's own vault.
- **What stays out:** nothing about the team in any public file of the newsroom. The layer is drawn in the browser from the vault, and the build never sees it.
- **Rules carried from Part A:** zones by default, a pin only by choice with its `until`, never a home or a hotel, and the vault deleted by 14 November.

**What the newsroom must offer for B2** (its owner is dev@PrompTugal.dinis; dev.venues@ makes these changes on its `dev` under the five steps, its gate and its `CLAUDE.md`, decision 2 of the new-agents spec):
1. **The vault key, sealed to newsroom keys.** Each team member needs the team vault's key sealed to their **newsroom** key (`board/person-keys.json`), not only to their team-site key, because the two origins do not share keys.
   - vault@PrompTugal.angelo seals it, as it seals the team-site copies, when it creates the vaults.
   - A member without a newsroom key asks the newsroom's conductor for one (`person-key.mjs`); until then they use Part A's view.
2. **Reading another vault.** Today `vault-core.js` serves the reader's own vault (a door, a passkey). B2 needs a read-only "open this vault with this key" path:
   - the key comes from `PTKeyring.open(envelope)`, in memory only, never stored;
   - the vault is read with the same library, as the team site's `assets/crm.js` reads the private CRM;
   - it is a small addition to `assets/vault/`, which is shared code.
3. **Writing the reader's own line.** The person's update is signed with `PTKeyring.sign` and sealed to vault@'s key, then sent over the team vault's append lane (Part A, vaults.md). Two places to send from:
   - **On the newsroom's own pages:** this needs the append token in the page and a `fetch` to the lane.
   - **In Angelo's command centre:** the lane already exists there (feedback.js's pattern).
   
   **I recommend** B2 starts read-only on the newsroom: people set their line in the command centre's Where, and the newsroom map shows it. Writing from the newsroom comes after security's review of that one `fetch`, because the newsroom's rule, like `schedule.js`'s, is that nothing leaves the browser.
4. **A gate check on the newsroom:** the venue feature's public files hold no person, no zone and no vault id beyond what is already published. This is the newsroom equivalent of our rule 22 (WS-164).

### B3. Being publicly "trackable" (later, its own decision)

Per person, zone only, off by default, through the public vault. Nothing is built for it in this version.

### The changes, by owner (B1 now; B2 after the review and the token)

- **dev.venues@PrompTugal.angelo, on the newsroom's `dev`, For: dev@PrompTugal.dinis:**
  - `newsroom/build/features/venue.mjs` builds `/summit/venue/` and its markdown twin, the "Where is it?" block on event pages, and an `llms` line. It adds a gate check: `assets/venue/venue.js` makes no network call beyond its own static data.
  - `assets/venue/venue-map.js` holds the drawing data, written by `people/angelo/tools/venue-map.mjs`, which dev.venues@ extends to write both copies.
  - `assets/venue/venue.js` and `.css`, plus links from the summit pages and My day.
  - Design: the newsroom's designer@ and design@ own the look; dev.venues@ follows their brand rules.
- **B2's additions:** in `assets/vault/` (another-vault read) and `assets/venue/` (the layer), plus the gate check, all on the newsroom's `dev`.
- **vault@PrompTugal.angelo:** the vaults, and the key sealed to each member's newsroom key.
- **security@web-summit.dinis:** the review (decision d) now covers the team layer on PrompTugal.news too (2254b43f).

## Out of scope

- Real locations before security's review (decision d).
- The phone's own location: never asked for, on either site.
- Any person on the public map (Part B, item 4).
- The live map of our activity: its own spec, `people/angelo/proposals/live-map/`.
- Writing a person's line from the newsroom's pages, before security's review of that one network call (B2, item 3).

## Risks

- **A pin is still a coordinate.** It is kept only by choice, expires in hours, and is seen only by the team, but the vault keeps its history until deletion (decision c). security@'s review should confirm that the expiry and the deletion are enough.
- **Two copies of the map data**, here and in the newsroom. One generator (`venue-map.mjs`) writes both, and dev.venues@ checks they match at each run.
- **Event places are only as good as the newsroom's data.** A stage with no building stays unplaced rather than guessed.
- **Three agents in `where.js`** (dev.venues@, dashboard@, dev@): the five steps, small changes, and the tests before each commit.

## How we will know it works

- **Part A:** the demo keeps passing `wzone.test.js` and the other tests at 1280 and 390 px, light and dark. No real location is stored before security's review is recorded here. The vault's deletion by 14 November is recorded here too.
- **Part B:**
  - `/summit/venue/` and the event blocks pass the newsroom's gate, including the no-network check.
  - Every building with a stage in the events data is labelled.
  - A reader's picks show on the map and never leave the browser, checked as schedule.js is.
  - B2: a team member signed in on the newsroom with their key sees the team's layer. A reader without the key, or signed out, sees no trace of it, in the page or in any public file. Tested with a test vault and test keys, never a real location, until security's review.
  - Tested at both widths and themes.
