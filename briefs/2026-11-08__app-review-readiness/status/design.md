# Status · Design (App Review readiness)

> All eight design items are written, with unit tests. Waiting for the build job on night/design. The payment-host block list waits for team's shared constant; WebsiteView's fixed width is platform's file.

Branch: `night/design` (merged from `origin/dev`, no rebase) · Last update: 14:50 UTC

## Done (pushed, waiting for CI)

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

## In progress

- CI on the push below.

## Blocked / needs from others

- **Team (3.1.1):** the shared payment-host block list in `Bridge/` is not on dev yet. I asked for its name; I will call it from `WebPage`'s navigation policy as soon as it lands. Until then `WebPage` routes every navigation through `TeamFeatures.shared.bridge.handlesNavigation(to:)`, which already stops `buy.stripe.com` and the top-up page.
- **Team (Q8):** one copy of the team models. Proposed: team's `TeamMe`/`TeamPerson`/`CommandCentre` become the only models for me.json and data.json; design moves its screens to them and deletes `Wire.Me`/`Person`/`CommandCentre`. Waiting for team's answer on which fields `TeamPerson` has.
- **Collab:** use `DebugMode.defaultOn` in `AskView.swift:13` and `LanesView.swift:9` (sent).
- **Platform:** keep `PreviewSamples` out of `#if DEBUG` (the R1 button uses it in release); `WebsiteView.swift:20` (App/Web) still has the fixed 250 pt sidebar from Q9; the other fixed font sizes are in `Team/TeamHomeView.swift:174` and `App/Web/WebsiteShortcuts.swift:143, 150`.

## Questions for Dinis

- None from design. The reviewer path is: launch → Who are you? → **Try with sample data**, or **I am not on the team** for the reader experience.
