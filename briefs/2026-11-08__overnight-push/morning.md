# Morning summary: the overnight push

> For Dinis and Silvio. What the seven sessions shipped overnight, what is still open, the decisions and Apple set-up only you can do, and what to test first on a phone and an iPad. Draft, updated through the night; final by 10:00 UTC.

**Last updated:** 07:55 UTC (draft) · **Build log:** [one page per checkpoint](https://ios.app.promptugal.news/admin/build-log/index.html) · **Live status:** [push dashboard](https://ios.app.promptugal.news/admin/push.html)

## In one paragraph

PrompTugal now opens on a native shell: a sidebar on iPad, four tabs on iPhone. Behind it are native dashboards for the team, the agents, the newsroom and your day, the news and its graph drawn natively, one schedule shared with the website, reminders, a Swift vault reader and writer with Face ID, a native top-up, and debug panels that show every request and decryption step. It targets iOS 18 and builds for iPhone and iPad on every push to `dev`. It is not signed yet: TestFlight is wired and waits only for your Apple set-up and keys, about 45 minutes of work (below). As of 05:40, all 20 features on the site are in the beta, including Ask (OpenRouter chat with your own key), Messages through vaults and Where is everyone.

## What shipped

To be completed at the end of the night. As of 05:40 UTC, on `dev`:

| Area | What is in the app | Session |
| --- | --- | --- |
| Shell | iPad sidebar with ten sections, iPhone tabs and More; 29 screens registered, no placeholders, and a Wall screen for an iPad on a stand | design |
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

## Dinis, first: the first internal TestFlight build (about 45 minutes)

Written by the release session. Nothing in the code changes. The detail behind each step is in the [release setup](release-setup.md).

1. **App IDs** (developer.apple.com → Certificates, IDs & Profiles → Identifiers). Make sure these three exist as explicit App IDs: `news.promptugal.reader`, `news.promptugal.reader.widgets`, `news.promptugal.reader.intents`. Create the App Group `group.news.promptugal.reader`. Enable on the app ID: **App Groups** (that group), **Associated Domains**, **Time Sensitive Notifications**. Enable on both extension IDs: **App Groups** (same group). (Step 1 of the release setup.)
2. **Certificate.** Certificates → + → **Apple Distribution**, or reuse one whose private key you have. Export it from Keychain Access as `distribution.p12` with a password.
3. **Profiles.** Profiles → + → **App Store Connect**, once for each of the three App IDs, all with that certificate. Download the three `.mobileprovision` files.
4. **App Store Connect** (appstoreconnect.apple.com). Create the app record for `news.promptugal.reader` if it does not exist. Users and Access → Integrations → App Store Connect API → Team Keys → + with role **App Manager**. Download `AuthKey_<KEYID>.p8` and note the **Key ID** and **Issuer ID**. (Step 2 of the release setup.)
5. **Testers.** TestFlight → Internal Testing → + group "Team", **automatic distribution** on. Add each teammate as an App Store Connect user (any role) and to the group.
6. **GitHub secrets** (repo → Settings → Secrets and variables → Actions → New repository secret). Paste `base64 -i <file> | pbcopy` output for files:
   `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64` (the .p8), `IOS_DIST_CERT_P12_BASE64` (the .p12), `IOS_DIST_CERT_PASSWORD`, `IOS_PROFILE_APP_BASE64`, `IOS_PROFILE_WIDGETS_BASE64`, `IOS_PROFILE_INTENTS_BASE64`. (Step 3 of the release setup.)
7. **Dry run.** Actions → **iOS release** → Run workflow → branch `dev` → tick **dry_run** → Run. In the run's summary, the **Profiles against entitlements** table must be all ✅. A ❌ row names the capability to enable; fix it in step 1, regenerate that profile, update its secret, run again.
8. **Upload.** Run workflow again on `dev` with **upload** ticked. When it is green (about 15–25 minutes, depending on the runner queue), App Store Connect processes the build in 5–30 minutes. The team gets it in the TestFlight app automatically. "What to Test" is filled from the night's status pages and commits.

After that, every upload is step 8 only, or a tag: `git tag ios-v0.4.0 && git push origin ios-v0.4.0`.

## Until TestFlight works: install from Xcode

The quickest route this morning, as Silvio did:

1. `git pull` on `dev` and open `PrompTugal.xcodeproj`.
2. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and put your team ID in it.
3. Pick your iPhone or iPad and press Run. Xcode makes the three development profiles (app, widgets, intents) itself.

With a free Apple ID, also set `PT_ENTITLEMENTS = Config/PrompTugal-Basic.entitlements` in that file. The app then runs without App Groups and associated domains, so widgets, the vault cache shared with widgets and passkeys will not work. Other routes (the simulator app from CI, re-signing the CI `.ipa`) are in the [release setup](release-setup.md).

## Also only you can do

- **promptugal.news:** serve `/.well-known/apple-app-site-association` listing `<TEAMID>.news.promptugal.reader` for `webcredentials` and `applinks`. It returns 404 today, so passkey unlock and universal links cannot work until it exists. This is a change in the website's repo.
- **App Store Connect:** create the two in-app purchase products for the reading meter, `news.promptugal.reader.credit.5` and `news.promptugal.reader.credit.20`. The local StoreKit file only covers testing; TestFlight purchases run in the sandbox and are not charged.
- **Silvio:** install a build from `dev` on an iPhone and an iPad and run the tests below.

## Decisions for Dinis

- **Removing a pick.** Sync with the vault is union-only, like the website: a pick removed in the app comes back from the vault and stays on other devices; only that device remembers the removal. Fine for the summit. The fix is a list of removals in `agenda/picks`, which the website must also honour.
- **A contact address** for "talk to us" on the product site's plans page. It links to GitHub issues for now.

## What to test first

In this order, on an iPad first and then an iPhone. Each step names what should happen; if it does not, a screenshot with the build number (Settings → Debug → Build) is the most useful report.

1. **Launch.** The app opens on the shell: a sidebar on iPad, four tabs and More on iPhone. Turn the iPad to landscape and back.
2. **Who am I.** My day asks who you are the first time. Pick yourself; My day then shows your stand-up, what only you can do, decisions and overdue items.
3. **One schedule.** On promptugal.news inside the app (Web → PrompTugal.news), add a session to your day. Open My schedule: it is there. Remove one in the app and check the website. (A removal does not yet sync through the vault; see the decision above.)
4. **Reminders.** Allow notifications when asked. A picked session gets a reminder 10 minutes before, by default; the time is set in Settings → Reminders.
5. **The team and the agents.** The team, Agents (the 24-hour wake grid), Briefed and Newsroom load, and say how old their data is. Turn on airplane mode, force quit, reopen: they still show, marked as stale.
6. **Vault.** Vault → paste a team key or scan its QR code → Import. It opens on its files. Close and reopen the app: Face ID opens it, with no typing. Debug → Vault traffic shows every request and decryption step, and no key.
7. **Ask.** Open Ask and paste your own OpenRouter key in its key settings (the key is kept in the Keychain; only a masked hint shows after). Ask "what is next for me?" with the agenda and picks switched on as context. On iPad, Ask opens beside any screen.
8. **Top-up.** Reading credit shows the website's meter. In a build from Xcode the purchase uses the local StoreKit file; in TestFlight it uses the sandbox. Nobody is charged.
9. **The wall.** On an iPad on a stand: Today → Wall. It should refresh by itself.
10. **Debug.** Network shows every request with its host, size and time; Keys lists which keys exist and where, never their values.

Known limits: passkey unlock needs the `apple-app-site-association` file on promptugal.news; sending a message to a teammate needs their lane, which the share button on Messages creates; writing to a vault needs the vault key, not only a read key.

## What is still in progress

Draft at 07:40; final by 10:00.

- **CI capacity.** The macOS runners were the bottleneck of the night; `dev` was frozen at 07:15 so queued runs could finish. They did: the unit tests on the integrated app passed on iPhone (121 tests in 31 suites, the iPhone job of run 150) and on iPad (the iPad job of run 154). The other jobs of those runs were cancelled to make room for newer commits. Session branches now run only the build; the unit tests and screenshots run on `dev`.
- **Screenshots.** The first runs had cut screen ids and rotated iPad images, and one failed on a slow screen; all three are fixed. Run 10 took all 13 iPhone screens with exact ids, and the site shows them. iPad is added once an upright image from a fixed run has been checked.
- **Vault writes on the live server.** Reading and writing are tested against vaults written by sgit 0.27 and sgit's in-memory server, and sgit reads back what the app writes. A live push to `dev.send.sgraph.ai` needs an access token nobody had tonight.
- **Passkey unlock.** Written and behind a flag; it needs the `apple-app-site-association` file on promptugal.news (above). Team keys and Face ID work without it.
- **Polish.** Design is going through every screen on iPhone at the largest text sizes; collab plans to let Ask remember the last conversation on the device (opt-in, never the key).
