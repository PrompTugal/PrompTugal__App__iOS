# Morning summary: the overnight push

> For Dinis and Silvio. The night's work is on `dev` and green in CI. Start with the 45-minute TestFlight checklist, then test on an iPad and an iPhone. Below: the decisions only you can take, what CI has proven, and what is not proven yet.

**Status:** final, 09:20 UTC · **Build log:** [one page per checkpoint](https://ios.app.promptugal.news/admin/build-log/index.html) · **Live status:** [push dashboard](https://ios.app.promptugal.news/admin/push.html) · **Release setup:** [the full checklist](release-setup.md)

## In one paragraph

PrompTugal now opens on a native shell: a sidebar on iPad, four tabs on iPhone. Behind it are native dashboards for the team, the agents, the newsroom and your day; the news and its graph drawn natively; one schedule shared with the website; reminders; a Swift vault reader and writer with Face ID; Ask with your own OpenRouter key; messages through vaults; a native top-up; and debug panels that show every request and decryption step. It targets iOS 18 and is built for iPhone and iPad. All 20 features on the site are in the beta. It is not signed yet: TestFlight is wired and waits only for your Apple set-up and keys, about 45 minutes of work.

## 1. Dinis, first: the first internal TestFlight build (about 45 minutes)

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

## 2. Until TestFlight works: install from Xcode

The quickest route this morning, as Silvio did:

1. `git pull` on `dev` and open `PrompTugal.xcodeproj`.
2. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and put your team ID in it.
3. Pick your iPhone or iPad and press Run. Xcode makes the three development profiles (app, widgets, intents) itself.

With a free Apple ID, also set `PT_ENTITLEMENTS = Config/PrompTugal-Basic.entitlements` in that file. The app then runs without App Groups and associated domains, so widgets, the vault cache shared with widgets and passkeys will not work. Other routes (the simulator app from CI, re-signing the CI `.ipa`) are in the [release setup](release-setup.md).

## 3. What to test first

In this order, on an iPad first and then an iPhone. Each step names what should happen; if it does not, a screenshot with the build number (Settings → Debug → Build) is the most useful report.

1. **Launch.** The app opens on the shell: a sidebar on iPad, four tabs and More on iPhone. Turn the iPad to landscape and back.
2. **Who am I.** My day asks who you are the first time. Pick yourself; My day then shows your stand-up, what only you can do, decisions and overdue items.
3. **One schedule.** On promptugal.news inside the app (Web → PrompTugal.news), add a session to your day. Open My schedule: it is there. Remove one in the app and check the website. (A removal does not yet sync through the vault; see section 4.)
4. **Reminders.** Allow notifications when asked. A picked session gets a reminder 10 minutes before, by default; the time is set in Settings → Reminders.
5. **The team and the agents.** The team, Agents (the 24-hour wake grid), Briefed and Newsroom load, and say how old their data is. Turn on airplane mode, force quit, reopen: they still show, marked as stale.
6. **Vault.** Vault → paste a team key or scan its QR code → Import. It opens on its files. Close and reopen the app: Face ID opens it, with no typing. Debug → Vault traffic shows every request and decryption step, and no key.
7. **Ask.** Open Ask and paste your own OpenRouter key in its key settings (the key is kept in the Keychain; only a masked hint shows after). Ask "what is next for me?" with the agenda and picks switched on as context. On iPad, Ask opens beside any screen.
8. **Top-up.** Reading credit shows the website's meter. In a build from Xcode the purchase uses the local StoreKit file; in TestFlight it uses the sandbox. Nobody is charged.
9. **The wall.** On an iPad on a stand: Today → Wall. It should refresh by itself.
10. **Debug.** Network shows every request with its host, size and time; Keys lists which keys exist and where, never their values.

Known limits: passkey unlock needs the `apple-app-site-association` file on promptugal.news; sending a message to a teammate needs their lane, which the share button on Messages creates; writing to a vault needs the vault key, not only a read key.

## 4. Decisions and set-up for Dinis

- **Removing a pick.** Sync with the vault is union-only, like the website: a pick removed in the app comes back from the vault and stays on other devices; only that device remembers the removal. Fine for the summit. The fix is a list of removals ("tombstones") in `agenda/picks`, which the website must also honour. Decide whether to do it before or after the summit.
- **`apple-app-site-association` on promptugal.news.** Serve `/.well-known/apple-app-site-association` listing `<TEAMID>.news.promptugal.reader` under `webcredentials`. It returns 404 today, so passkey unlock cannot work. (The app no longer declares `applinks`, so universal links are not needed.) This is a change in the website's repo.
- **Vault access tokens.** Writing to the live vault server needs an access token. Nobody had one tonight, so live writes are not proven (below). Decide who issues tokens to the team, and how.
- **Apple set-up beyond the checklist.** Create the two in-app purchase products for the reading meter, `news.promptugal.reader.credit.5` and `news.promptugal.reader.credit.20`. The local StoreKit file only covers testing; TestFlight purchases run in the sandbox and are not charged.
- **A contact address** for "talk to us" on the product site's plans page. It links to GitHub issues for now.
- **Silvio:** install a build from `dev` on an iPhone and an iPad and run the tests in section 3.

## 5. What is green in CI

- **Every job on dev passed** in iOS run 188 (on `bf704b5`, the 08:50 merge): app build, vault package tests, iPhone unit tests and iPad unit tests. Earlier, the iPhone unit tests passed 124 tests in 33 suites on `8a060e8` (run 173). *Update, 15:15 UTC:* after the App Review fixes, platform reports **141 tests in 38 suites**.
- **The vault package:** reads and writes vaults made by sgit 0.27, and sgit reads back what it writes; tampered objects and wrong keys are refused.
- **The bridge against the live website:** [`Tools/bridge-e2e`](https://github.com/PrompTugal/PrompTugal__App__iOS/tree/dev/Tools/bridge-e2e) runs the app's injected JavaScript in Chromium against promptugal.news: a pick made in the app shows on the site, the meter is credited once per purchase, and the Stripe top-up is hidden.
- **Screenshots:** screens run 16 took all **13 main screens on iPhone and iPad**. The iPad images were checked in a browser (upright, whole screen); the site's [screens page](https://ios.app.promptugal.news/admin/screens.html) shows them from the next release.
- **Every push to `dev`** builds an unsigned archive, `.ipa` and simulator app, and redeploys this site.

## 6. Not proven yet

From the vault and collab sessions' own lists:

- **Live vault writes.** Writes are proven against sgit's in-memory server and by sgit reading them back, never against `dev.send.sgraph.ai`: that needs an access token.
- **Passkey sign-in on a device.** Behind a flag (off) until the `apple-app-site-association` file exists. The door test vectors come from a Python port of the website's `door.js`; one browser run of `door.js` would cross-check them.
- **Large vault files** (over 4 MB encrypted) and **pack vaults** are refused with a clear error.
- **Where is everyone** needs each teammate's vault read key: the team site's public data gives everyone the same shortlist, so it cannot show who goes where.
- **Messages to a teammate** need their lane description, which the share button on Messages creates; none is published yet. Registering your own inbox lane needs a vault write key and an access token. promptugal.news publishes no newsroom lane, so newsroom notes go through the vault notes lane.

## 7. What shipped

| Area | What is in the app | Session |
| --- | --- | --- |
| Shell | iPad sidebar with ten sections, iPhone tabs and More; 29 screens registered, no placeholders, and a Wall screen for an iPad on a stand | design |
| Team and agents | My day, The team, Agents (the wake grid redrawn natively), Briefed, Newsroom | design, team |
| News | Feed, newsletter editions, story board, graph explorer (all nodes and edges, native) | design |
| Schedule | One list with the website (`nr.schedule.v1`), reminders, a day planner, Add to Calendar | team |
| Bridge | The website and the app talk through a fixed list of messages, on promptugal.news and the team site only; tested against the live site in Chromium (`Tools/bridge-e2e`) | team |
| Vault | Swift reader and writer, tested against vaults written by sgit 0.27, keys behind Face ID and the Secure Enclave | vault |
| Ask, messages, where is everyone | OpenRouter chat with the key in the Keychain; append lanes in vaults; teammates' shared picks | collab |
| Top-up | The website's meter, topped up with StoreKit (two consumables); the Stripe link is hidden in the app | team |
| Debug | Network, vault traffic with the decryption steps, bridge, storage, keys (never values), build | design, platform |
| Platform | iOS 18, widget, App Intents, privacy manifest, unit and UI tests, CI on iPhone and iPad | platform |
| Release | Unsigned archive, .ipa and simulator app for every dev push; TestFlight and App Store submit workflows | release |
| Site | ios.app.promptugal.news as the team's product site, features labelled from the code, build log and admin pages | editor |

## 8. What native taught us, for the website

From design, building native screens over the website's own JSON: a single `/wall/` page for a screen at the stand; the wake grid as data, not a string of symbols; a `version` and `built_at` in every JSON file; a schema per file; a JSON twin for the newsletter; and the native and web versions side by side, to see which does better.
