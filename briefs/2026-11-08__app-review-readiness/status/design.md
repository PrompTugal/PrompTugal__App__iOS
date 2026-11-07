# Status · Design (App Review readiness)

> All design items are done and night/design builds green (run 224, with team's fixes merged). The unit-test run (229, by hand) is queued.

Branch: `night/design` (merged from `origin/dev`, no rebase) · Last update: 15:22 UTC

## Done

| # | Item | What changed | Test |
| --- | --- | --- | --- |
| R1 | Demo access | **Try with sample data** on Who are you? (always shown, also offline): fills the app with made-up people, agents and stories (`PreviewSamples`), shows a **Sample data** banner on every screen with **Leave**. Sample feeds are pinned and never replaced from the network. Works in release builds (no launch arguments). **I am not on the team** now opens the reader's Today: the agenda, with News one tab away; Settings offers "Not on the team (reader)". Sample people have no command centre, so that card is hidden in sample mode. | `SampleDataTests` |
| S4 | Debug in release | `DebugMode.defaultOn` is `true` only under `#if DEBUG`. `Destinations.openable(_:debug:)` refuses debug-only screens unless debug mode is on; used by `promptugal://open/…`, launch arguments and restored selections. `WebPage.isInspectable` only under `#if DEBUG`. My `LaunchOptions` read as absent in release builds. | `DebugLinkTests` |
| Q2 | Graph crash | Replacing the graph index resets `selected`, `path`, `pathStart` and the sheet. Every use of a node index is checked (`GraphIndex.contains`), and `path(from:to:)` refuses nodes outside the graph. JSON numbers become indices only through `GraphIndex.slot` (finite, whole via `Int(exactly:)`, in range). | `GraphIndexSafetyTests` |
| S6 | App-switcher snapshot | `PrivacyCover` covers the whole app whenever `scenePhase` is not `.active`. | UI only |
| R3 | Privacy and support | Settings → About: **Privacy** (`ios.app.promptugal.news/privacy.html`), **Support** (`…/support.html`), and a visible note: "PrompTugal is independent. It is not affiliated with, endorsed by or sponsored by Web Summit." | `SupportLinkTests` |
| Q9 | Split View widths | Wall: two columns only from 760 pt of real width, the side column 280–380 pt. Graph: the node detail sits beside the graph from 700 pt (260–340 pt wide), otherwise opens as a sheet. Both measure the space they have, not the device. | `SplitViewLayoutTests` |
| — | Header tap | A tap on the wake grid's hour header no longer selects row 0 (`WakeGrid.row(at:…)`). | `WakeGridTapTests` |
| — | Dynamic Type | The Wall's stand-up time and the avatar initials use `@ScaledMetric`. | — |
| — | Colour-only dot | The sidebar's native/web/hybrid dot is now a symbol (shape and colour) with a text label and tooltip. | — |

Also done after team's and platform's notes:

| Item | What changed | Test |
| --- | --- | --- |
| R5 | Reading credit is in the shell only when `ReadingCredit.isAvailable` (debug builds). | `TeamNotesTests.readingCredit` |
| 3.1.1 | `WebPage` refuses every navigation, in every frame, and every new-window link to a checkout (`CheckoutPolicy.isBlocked`) or a page the bridge handles. | `TeamNotesTests.checkout` |
| Q6 | `promptugal://open/team.schedule?session=<slug>` opens that session's page; `?url=` opens a briefing, only on promptugal.news and web-summit.sgit.ai. | `TeamNotesTests.links` |
| Q8 | `TeamEndpoints.base` replaces design's `TeamSite`. | — |
| Platform | No `-PTMe` persistence; `PreviewSamples.data()` no longer writes "who am I"; sample mode saves and restores the previous choice. | `SampleDataTests` |

## CI

| Run | Commit | Result |
| --- | --- | --- |
| 205 | 3b9b099 (all eight items) | build green |
| 211 | 4cb7122 (sample identity) | build green |
| 217 | 920ad9e (after merging night/team 9471fa9) | red, only in team's `Bridge/AppBridge.swift:164-166`; team fixed it (c6a7719, a39b136) |
| 220 | 94aa2ef (night/team c6a7719 merged) | build green |
| 224 | a0b940c (night/team a39b136 merged) | build green |
| 229 | a0b940c, unit tests by hand (workflow_dispatch) | queued |

## In progress

- Run 229: the iPhone and iPad unit tests, including `PrompTugalTests/DesignReviewTests.swift`.

## Blocked / needs from others

- **Team (Q8), agreed, next after review:** team's `TeamModels` become the only models for me.json and data.json (`TeamPerson` has every field design uses); design moves My day, Team, Briefed, Wall and Command centre to `TeamStore` and deletes `Wire.Me`/`Person`/`CommandCentre`. `Wire.*` stays for the newsroom JSON. Left until after review, at the conductor's preference.
- **Collab:** use `DebugMode.defaultOn` in `AskView.swift:13` and `LanesView.swift:9` (sent).
- **Platform:** keep `PreviewSamples` out of `#if DEBUG` (the R1 button uses it in release); the other fixed font sizes are in `Team/TeamHomeView.swift:174` and `App/Web/WebsiteShortcuts.swift:143, 150`.

## Questions for Dinis

- None from design. The reviewer path is: launch → Who are you? → **Try with sample data**, or **I am not on the team** for the reader experience.
