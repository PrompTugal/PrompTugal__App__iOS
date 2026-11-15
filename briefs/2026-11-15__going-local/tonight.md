# Tonight: the news app shows the Algarve newsroom in action

> Dinis's voice brief of 15 November 2026, about 23:30, to conductor.a.ios@promptugal.dinis. He presents tomorrow morning. Conductors and workers run hourly through the night. All repositories are public and open source: clone what you need (VoiceDebrief/VoiceDebrief__App__iOS holds the voice, Apple Intelligence, screenshot and agents code, and the SGit app).

## What he asked for, in his words where it matters

1. **Show the agents in action.** "We have to tell the story, and the best way to tell the story is to show the agents in action: here's a news story, here's what the agents are doing right now." Agents will run on a more aggressive schedule, so show them working, collaborating and making changes, with "the little animations, the little stuff". Read-only: we do not make decisions from the app, but visibility is the point.
2. **Dynamic data first.** Read as much live JSON as possible. The website team will be asked to focus on dynamic data and databases (queries).
3. **Location.** Ask for the user's location (while using the app) and show the local news where they are.
4. **Apple Intelligence on the device.** Summarise news locally. A persona mode: "I am from Algarve Evolution" or "I am interested in this", and the UI changes to that mode.
5. **Contribute from the app.** A photo, screenshot, video or a recorded interview goes into an sgit folder only Dinis can write to, becomes a draft, and is pushed to the website.
6. **Talk to the agents.** Talk to a town's agent (Loulé, say) from the app, with Claude and Apple Intelligence mixed; ask questions and get answers. Owner-only at first (prompt injection).
7. **Talk to the conductor, with screenshots.** See something on the website, write a comment, paste a screenshot from the iPad, send; the conductor picks it up and pushes the change (or hands it to the website's conductor). A couple of demoable changes done in minutes.
8. **A CI status page.** "Last checked N minutes ago": the GitHub Actions for the website and the iOS app, how long a push takes to reach production, how long until a TestFlight build is live, and in the app, whether the installed build needs updating.
9. **Investment map** (website team): investors, companies, startups and people, intersected.
10. **Maps and visualisations, go to town.** Several options, from normal to a bit of 3D, cities colour-coded; a designer and a data scientist working together in rounds through the night.

## Workstreams (this repository)

Each worker works on its own `work/<name>` branch, touches only the files listed, and hands back a green CI run; the conductor merges to `dev`. New screens live in `Packages/PTLocal` (read-only data, the reader, the newsroom) unless noted. Never commit a secret: a lane link (`sgi1.`) is public by design; a private key or access token never is.

| # | Name | Owns | Delivers |
| --- | --- | --- | --- |
| A | **live** | `Packages/PTLocal/Sources/PTLocal/Live/` | The newsroom in action: an animated live view of agents (pulses when an agent wakes, handoffs drawn as they fly, a timeline of today's wakes, "this story, these agents"), polling `api/v1/newsroom/dashboard.json` and `status.json` every minute while open. Plus the map and visualisation rounds (item 10): at least three styles of the Algarve map (flat, 3D MapKit with elevation and pitched camera, an abstract colour-coded town grid), switchable. |
| B | **ai** | `Packages/PTLocal/Sources/PTLocal/AI/`, location in the app shell | Apple Intelligence (Foundation Models, weak-linked, iOS 26 devices, honest fallback): one-paragraph summary of a town or a story, "explain the AI path", and the persona mode (pick or type "I am from Algarve Evolution", the Algarve home reorders and re-summarises for that). Location while in use: nearest town and its news. Port from VoiceDebrief `Engine/OnDeviceModel.swift` and the Lab desks. |
| C | **talk** | `Packages/PTLocal/Sources/PTLocal/Talk/` (or a new package if it needs PTLanes) | Send to the conductor: text, a pasted screenshot or a photo, sealed to the conductor's append lane (port VoiceDebrief `DeveloperLane.swift`, `PictureSender.swift`; this repo's `PTLanes` already has the hybrid envelope). Contribute: photo, video or a recorded interview to the same lane as a draft. Talk to a town's agent: a conversation sealed to its lane; Apple Intelligence answers from the town's own JSON while the agent is away. Owner-only: hidden unless the device holds Dinis's key or a passphrase he sets. |
| D | **ci** | `website/` page `status`, and `Packages/PTLocal/Sources/PTLocal/Status/` | A status page and an in-app screen: latest runs of `ios.yml`, `ios-release.yml`, `website.yml` here and the website's deploy, durations, push-to-live times, the latest TestFlight build number versus the installed one ("update available"). Built by CI into JSON (`ios-build.json` already exists), read by the app; says when it was last checked. |

Item 9 (the investment map) and the website-side dynamic data go to the PrompTugal.news team through Dinis or conductor@web-summit.dinis; the app reads whatever JSON they publish.

## Rules for the night

- Read-only toward agents: nothing in the app starts, stops or steers an agent, except the owner-only messages of C.
- Anything simulated carries the visible "Simulated" badge (`SimulatedBadge` in PTLocal). Never let a screen claim something real that is not.
- Every story opens its source. Every screen says whether its data is live, this device's copy, or the built-in copy (`ProvenanceLabel`).
- Green CI before `dev`: a push to `dev` that changes an app builds and uploads to TestFlight.
