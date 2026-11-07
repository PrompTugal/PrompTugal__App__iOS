# Morning summary: the overnight push

> For Dinis and Silvio. What the seven sessions shipped overnight, what is still open, the decisions and Apple set-up only you can do, and what to test first on a phone and an iPad. Draft, updated through the night; final by 10:00 UTC.

**Last updated:** 05:15 UTC (draft) · **Build log:** [one page per checkpoint](https://ios.app.promptugal.news/admin/build-log/index.html) · **Live status:** [push dashboard](https://ios.app.promptugal.news/admin/push.html)

## In one paragraph

PrompTugal now opens on a native shell: a sidebar on iPad, four tabs on iPhone. Behind it are native dashboards for the team, the agents, the newsroom and your day, the news and its graph drawn natively, one schedule shared with the website, reminders, a Swift vault reader and writer with Face ID, a native top-up, and debug panels that show every request and decryption step. It targets iOS 18 and builds for iPhone and iPad on every push to `dev`. It is not signed yet: TestFlight is wired and waits only for your App Store Connect keys. As of 05:15, all 19 planned features are in the beta, including Ask (OpenRouter chat with your own key), Messages through vaults and Where is everyone.

## What shipped

To be completed at the end of the night. As of 05:15 UTC, on `dev`:

| Area | What is in the app | Session |
| --- | --- | --- |
| Shell | iPad sidebar with ten sections, iPhone tabs and More; 28 screens registered, no placeholders | design |
| Team and agents | My day, The team, Agents (the wake grid redrawn natively), Briefed, Newsroom | design, team |
| News | Feed, newsletter editions, story board, graph explorer (all nodes and edges, native) | design |
| Schedule | One list with the website (`nr.schedule.v1`), reminders, a day planner, Add to Calendar | team |
| Bridge | The website and the app talk through a fixed list of messages, on promptugal.news and the team site only | team |
| Vault | Swift reader and writer, tested against vaults written by sgit 0.27, keys behind Face ID and the Secure Enclave | vault |
| Ask, messages, where is everyone | OpenRouter chat with the key in the Keychain; append lanes in vaults; teammates' shared picks | collab |
| Top-up | The website's meter, topped up with StoreKit (two consumables); the Stripe link is hidden in the app | team |
| Debug | Network, vault traffic with the decryption steps, bridge, storage, keys (never values), build | design, platform |
| Platform | iOS 18, widget, App Intents, privacy manifest, unit and UI tests, CI on iPhone and iPad | platform |
| Release | Unsigned archive, .ipa and simulator app for every dev push; TestFlight and App Store submit workflows | release |
| Site | ios.app.promptugal.news as the team's product site, features labelled from the code, build log and admin pages | editor |

## What only you can do

### Dinis: Apple and GitHub (release's [setup checklist](release-setup.md) has every step)

1. **Apple Developer portal:** explicit App IDs for `news.promptugal.reader`, `.widgets` and `.intents`, with App Groups (`group.news.promptugal.reader`), Associated Domains and the other capabilities in the checklist; an Apple Distribution certificate; three App Store profiles.
2. **App Store Connect:** the app record, an API key, an internal TestFlight group with automatic distribution, and the two in-app purchase products `news.promptugal.reader.credit.5` and `news.promptugal.reader.credit.20` (the local StoreKit file is for testing only).
3. **GitHub secrets:** `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`, and for manual signing the certificate and three profiles. Then run **iOS release** with **upload** ticked.
4. **promptugal.news:** serve `/.well-known/apple-app-site-association` listing `<TEAMID>.news.promptugal.reader` for `webcredentials` and `applinks`. It returns 404 today, so passkey unlock and universal links cannot work until it exists.

### Silvio

- Install a build from `dev` on an iPhone and an iPad (Xcode, or the archive from CI re-signed in Organizer) and run the tests below.

## Decisions for Dinis

- **Removing a pick.** Sync with the vault is union-only, like the website: a pick removed in the app comes back from the vault and stays on other devices; only that device remembers the removal. Fine for the summit. The fix is a list of removals in `agenda/picks`, which the website must also honour.
- **A contact address** for "talk to us" on the product site's plans page. It links to GitHub issues for now.

## What to test first

To be completed at the end of the night.

## What is still in progress

To be completed at the end of the night.
