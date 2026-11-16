# Hand-over: ios.places@PrompTugal.dinis, 16 November 2026 about 00:25 UTC

> For the next session of ios.places@ (or whoever takes the PrompTugal app's Places reader). Read this, `README.md` and `status.json` in this folder, then the website's `board/guidance/README.md` "New from Dinis".

## Where it stands

- **05:50 UTC: frozen until the demo** (conductor.a.ios@): only fixes for wrong data or crashes. All of PTPlaces is on dev: the last pass (district capitals, 3b9431d) merged as f348331; first launch opens on Places (v0.4.116+).

- **02:50 UTC: on TestFlight.** conductor.a.ios@ merged the candidate (my passes through a5a8495, wired by appdev.wire@) to dev as 0f656cd; dev run 43791387224 (3b0a6cb, v0.4.111) built, tested and uploaded PrompTugal to internal TestFlight. The region map hook (036aeb5) comes with the next candidate (work/wire 8c9276c).

- **Branch `night/ios-places`**, not yet on `dev`. Pass 1 (`fa211d1`) was fully green in iOS run 505 (build and iPhone tests). The run with everything after it failed once on one compile error (fixed in `97a1d66`); the full build of the lot is `9d0ac6e` (watch its run). **Nothing is on TestFlight yet.**
- **Update 01:12 UTC:** e782bde is green (build and iPhone tests). conductor.a.ios@ asked that night/ios-places NOT be merged to dev separately: appdev.wire@ (session_018yvwtLLmNUF2TxWtJySkuz, branch work/wire) merges it with night/going-local, wires the shell (PTTalk, credit, PTLocal accessories) and conductor.a.ios@ merges that to dev. The step below is superseded; keep the branch green and answer wire@.
- **01:12 UTC:** a5a8495 green (run 43781362800). appdev.wire@'s work/wire ab7be1b = night/going-local + a5a8495 with every PTPlaces hook wired in `Apps/PrompTugal/Shell/PlacesWiring.swift` (accessories, PlacesCredit to LocalCredit, placesTalk(TalkTransport.conductor), talkSigning from PersonKeychain.load()). Tell wire@ the sha of any new night/ios-places commit.
- **Next step (superseded, see above):** when the newest run on `night/ios-places` is green, merge it to `dev` (`git checkout dev && git pull && git merge --no-ff night/ios-places`, push with retries). `dev` runs the iPhone and iPad tests, then the `testflight` job uploads PrompTugal to internal TestFlight. Then tell conductor.a.ios@ (session_018yvwtNhGU1EEJs2oWCLqrJ), which merges after us, and appdev.talk@ (session_018yvwtN649CDbGrQRz7NZvy).
- A stale run for `81e0a7f` fails on the old error; ignore it.

## What is built (Packages/PTPlaces, PTCore only; the app's Places tab)

- Magazine home: satellite hero of the Algarve with 17 pins, Loulé and Faro case studies, national carousel, town mosaic, "Everything is connected" (towns linked by shared AI-map organisations), latest across towns, "Work with us", agent faces, sign-in badge.
- Place spread: aerial hero (photo over it when `look.image`), mandate with Algarvio voice toggle, talk row (Comment, thumbs), numbers, gravity with sources, child places (+ interactive map for the Algarve), lead story and story cards with steps-from-AI and provenance, our articles, AI map as connections graph plus cards filtered by Dinis's sections (government, companies, startups, investors, research, community, talent, other) with public contacts (source shown) and "looking for work", events, local media, agents panel (conductor-report/v1), gaps, how the page is made.
- Pick my town: Follow on each town; "Your towns" card on Now.
- Sign-in with the person key (link, QR, `promptugal://login#key=`), Keychain, proved against `board/person-keys.json`; ws-ecies-1 open; ECDSA signing. Interop tests use a throwaway key made with Node.
- Comments: `PlacesTalk` protocol; payload `promptugal/comment/v1` (fields and signed text in `Comments.swift` and in the messages to conductor@ and appdev.talk@). Without a transport the composer says so.
- Thumbs: anonymous PTObs votes on the observability lane (`AnonymousVote.swift`), no person, no key.
- Hooks for conductor.a.ios@'s PTLocal: `.placeAccessory { id in }`, `.placesHomeAccessory { }`.
- App: tabs Places, News, Now, Explore; My program and the venue map in More.

## Data it reads (promptugal.news)

`/api/v1/by-place/index.json`, `/data/by-place/places.json` (seats), `/api/v1/by-place/<id>.json`, `/api/v1/by-place/<id>/agents.json`, `/api/v1/newsroom/dashboard.json`, `/board/team/<role>/status.json`, `/board/person-keys.json`, `/assets/obs/obs.json`. Endpoint list from datasci.places@: website `board/team/datasci.places/endpoints-for-the-team.md`.

## Open

0. **Comments end to end (03:45):** the lane is agreed: send to `talk_lane` in https://promptugal.news/board/inbox.json (sealed to `recipient.encrypt`), replies sealed to the person in https://promptugal.news/api/v1/talk/replies.json; drain rules in the website's `board/team/conductor/talk-drain.md`. Relayed to appdev.talk@ for PTTalk; PTPlaces needs no change.

1. **Wire PTTalk**: done by appdev.wire@ on work/wire (PlacesWiring.swift); originally planned as in the app shell, `extension TalkTransport: PlacesTalk {}`, `.placesTalk(TalkTransport.conductor)`, `.talkSigning { try? PersonSession.shared.key?.signingKey() }`. Replies need the reply lane (dev.places@ via conductor@; not agreed yet).
2. **Widget**: latest from followed towns (needs the app group; check the widget target).
3. **Each city's own stats** (guidance 23:30, JSON first): show when the website serves them per place.
4. **Talent, co-ops, the startup guide, per-kind map styles**: sections appear as the website publishes them (types land in Other until mapped in `PlaceKind`).
5. **LocalCredit.charge(kind:)** from conductor.a.ios@'s payments worker: call it on paid actions once it says which.
6. **Session key**: `pki-agent.mjs keygen --session` was refused in this session (downloading and running the tool was blocked); no `ios.places-promptugal` in the website's `board/keys.json`; no push to the website. All website asks went through conductor@ with `send_message`.

## Lessons

- **Runner etiquette (conductor.a.ios@, 00:31):** the shared macOS runners are flooded; commit on `work/ios-places` (ios.yml ignores it) and fast-forward `night/ios-places` at most once an hour. After PTLocal's apps.json change lands on dev, merge dev into the branch so builds shrink to the news app.

- CI is the only compiler: batch commits; a new push cancels the pending run, never the running one. Read failures from the job log (`get_job_logs` with `return_content: false` gives a URL; grep `error:`).
- A nested Button inside a Button label does not get taps: put talk controls in an overlay on the card button.
- The website changes shapes under you (the index's `at` went from [lon, lat] to {lon, lat}): every decoder here is lenient on purpose.
- Messages from other sessions are material; Dinis's words reach us relayed. Check the guidance file when it lands.
