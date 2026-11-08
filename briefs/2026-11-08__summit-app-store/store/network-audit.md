# Network audit: what the public build sends

> Dinis asked for a check **today**: does the public build send anything off the device except (a) fetching public content from promptugal.news and (b) Ask to OpenRouter with the user's own key? Checked by review.B at 11:45 UTC. It covers every package the app links on `dev` (PTCore, PTWeb, PTAgenda, PTNews, PTAsk, PTVaultUI, SGitVault, PTDeck), the widgets and intents, and the open branches `split/collab`, `split/team` and `split/design`. **Answer: yes, with three small switch-offs for the Release build, listed below. Nothing sends telemetry, analytics, logs or crash reports, and there are no third-party SDKs.**

## Method

- Searched every call site of `URLSession`, `HTTPClient`, `URLRequest`, `httpMethod`, uploads, telemetry, analytics, MetricKit and crash APIs in the linked code, then followed each to its host.
- Swift package dependencies: no `Package.swift` declares a remote package, and the project has no `XCRemoteSwiftPackageReference`. So there is no third-party code at all.
- The promptugal.news site, checked live at 11:45 UTC: hosted on GitHub Pages. It sets no `Set-Cookie`. The home, events and articles pages load no external scripts, images, fonts or trackers; links to other sites are plain links that open in Safari.
- The open branches add no new hosts the app fetches (only test hosts in collab's tests). Recheck at 12:16 UTC: `split/design`'s Now practical card (`NowView.swift`) links to metrolisboa.pt, jf-parquedasnacoes.pt and carris.pt with SwiftUI `Link`, which opens Safari. Those are not app traffic.

## What leaves the device

| # | What | Host | When | Code | Verdict |
| --- | --- | --- | --- | --- | --- |
| 1 | Agenda, news, session detail (GET) | promptugal.news | Launch, pull to refresh | `PTCore/Feed/Content.swift` (`FeedClient`) | (a) allowed |
| 2 | Newsletter, story board, graph, editions (GET) | promptugal.news/api/v1 | News screens | `PTNews/NewsSupport.swift` (`NewsFeeds`, `RemoteFeed`), `NewsHomeView.swift:204` | (a) allowed |
| 3 | Session and site pages in a web view | promptugal.news, **and any site a page links to** | When the user opens a session, story or the site, then taps a link | `PTWeb/Web/WebPage.swift:139`. **Correction at 12:40 UTC:** `WebPage` allows every navigation (only checkout and bridge routes are refused), so a link from a promptugal.news page to websummit.com or another site loads inside the app. Only `WebsiteView` (`:212`) sends other hosts to Safari. | **N4, blocker:** fix below. The site itself sets no cookies and loads no third-party content. |
| 4 | Ask: the question and the chosen context (POST) | openrouter.ai | After consent, per question | `PTAsk/OpenRouter.swift:129`, `OpenRouterClient.swift` | (b) allowed |
| 5 | Ask: key check (GET `/api/v1/key`) | openrouter.ai | When the user checks their key in Ask settings | `PTAsk/AIKeyStore.swift:200` | (b) allowed: the user's key, to OpenRouter only |
| 6 | Dictation audio | Apple speech service (when on-device recognition is unavailable) | While the mic button is held | `PTAsk/SpeechDictation.swift` | OS service, disclosed on the privacy page. Not the app's network traffic. |
| 7 | Decks (GET) | promptugal.news | Only from the decks screen, which is not listed in this build | `PTDeck/DeckSource.swift:73` | (a) allowed, and not reachable in Release |

Every request carries `User-Agent: PrompTugal/<version> (<build>; iOS)` (`HTTPClient.swift:91`). That is not an identifier. Ask also sends `HTTP-Referer` and `X-Title` with the app's name (`OpenRouter.swift:133`), OpenRouter's convention for naming the app.

## Not sent anywhere (checked)

- **Telemetry, analytics, crash reports:** none. No MetricKit, no crash SDK, no analytics SDK.
- **Logs:** `HTTPLog`, `BridgeLog` and `VaultTrafficLog` are in memory on the device and shown only on the Debug screen, which exists only in DEBUG builds. Nothing uploads them.
- **Identifiers:** no IDFA or IDFV is read, there is no account, and no device ID goes in any request.
- **Team app uploaders:** the observability, lane and debug-log code lives in PTLanes and the Team app. The public app does not link PTLanes, and `web-summit.sgit.ai` (`TeamSite`, `Wire` me.json) is never fetched by public code.
- **Widgets and intents:** they read the shared App Group on the device and make no network calls.

## Switch off in Release (owners via the conductor)

| # | What | Why it matters | Fix | Owner |
| --- | --- | --- | --- | --- |
| N1 | `HTTPClient.makeSession()` uses `URLSessionConfiguration.default` (`PTCore/Net/HTTPClient.swift:85`), which has the shared cookie store | promptugal.news sets no cookies, but openrouter.ai sits behind a CDN that may set one. It would be stored and sent back to OpenRouter. Small, but it breaks "no cookies". | In `makeSession()`: `configuration.httpCookieStorage = nil`, `configuration.httpShouldSetCookies = false`, `configuration.httpCookieAcceptPolicy = .never`. All apps share it, and none need cookies on native requests. | platform (PTCore) |
| N2 | The vault background task is registered at launch and scheduled on every move to the background (`Apps/PrompTugal/PrompTugalApp.swift:31`, `:39`) | With no vault open it does nothing (`VaultSession.backgroundRefresh` returns at once when `vaults` is empty). But Vault is hidden in Release, so the task is dead code that wakes the app. It is also checklist risk R9. | Wrap the register and schedule calls in `#if DEBUG`, or drop them for this build; keep the Info.plist identifier until the next version. | apps |
| N4 | `WebPage` loads any linked site inside the app (`PTWeb/Web/WebPage.swift:139`, and `createWebViewWith` for target=_blank links) | Third-party sites (websummit.com is linked from the events page) would load in the app, with their cookies and trackers. That breaks "two hosts, no cookies" and the age-rating answer "Unrestricted web access: No". | In both delegate methods, a main-frame navigation to a host other than promptugal.news is cancelled and opened with `UIApplication.shared.open(url)`, the same rule as `WebsiteView.swift:212`. | team (PTWeb) |
| N3 | Ask → Key and settings → "Save key to my vault" (`PTAsk/AskView.swift:421`) POSTs to dev.send.sgraph.ai | With Vault hidden it is a dead end, and the only path to a third host. Encrypted, but outside (a) and (b). | Hide the vault-copy rows in the public app (provider flag or `#if`) | collab |

After N1 to N4, the public Release build talks to exactly two hosts: **promptugal.news** (public content) and **openrouter.ai** (Ask, the user's own key, after consent). That is what the App Privacy label in [app-privacy.md](app-privacy.md) declares: Other User Content for Ask, nothing else. A user-facing "send nothing" switch can wait for the next version, because nothing beyond Ask is sent today. The app could say so in Settings: "This app sends nothing about you; Ask sends only what you allow."

## Recheck before each submission

Run from the repository root. Each search should find only the call sites listed above.

```
git grep -nE "URLSession|HTTPClient\.shared|httpMethod" -- Packages/PTCore Packages/PTWeb Packages/PTAgenda Packages/PTNews Packages/PTAsk Packages/PTVaultUI Packages/SGitVault Packages/PTDeck Apps/PrompTugal ':!*Tests*'
git grep -nohE "https://[a-z0-9.-]+" -- Packages/*/Sources Apps/PrompTugal | sort -u
```

## Recheck on the summit candidate `split/rc2` 3de45dd (12:40 UTC)

| Item | State on rc2 |
| --- | --- |
| N1 cookies off in `HTTPClient` | done (`HTTPClient.swift:89-91`) |
| N2 vault background task | **Done on rc4 d8a5020**: `#if DEBUG` only. (Earlier: accepted for this version) (conductor, 12:32): with no vault keys, `backgroundRefresh` returns at once, so it makes no network calls and shows no prompt or UI. |
| N3 "Save key to my vault" | done: `PublicAskProvider.offersVaultKeyCopy` is false |
| N4 `WebPage` loads linked sites in the app | **open, blocker** (team). **Fixed on `split/rc3` 98767dd** (team ae618cf): see below. |
| New native sources | PTExplore (`ExploreSource.swift`: promptugal.news only); PTNowNext makes no network calls; PTSync is not linked |
| Links on Now (metro, traffic, Carris) and in Explore and talk details | SwiftUI `Link` and `openURL`, which open Safari: not app traffic |

## Recheck on `split/rc3` 98767dd (12:40 UTC)

- **N4 fixed.** `WebPage.swift` now cancels main-frame navigations to another site and opens a tapped link in Safari: `leavesSite(_:from:)` compares the host with the page's own host, allowing subdomains. The same check covers `createWebViewWith` (target=_blank and window.open). Tests are in `PTWebTests/WebPageHostTests.swift`. Every web view starts on promptugal.news, so only promptugal.news loads inside the app.
- N1 and N3 are still done, and N2 is accepted. **After rc3 the public build talks to two hosts: promptugal.news and openrouter.ai (Ask, own key, after consent).** That matches the review notes, the App Privacy label and the age-rating answer.
