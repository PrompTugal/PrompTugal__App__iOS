# App Review checklist: PrompTugal: Lisbon Summit

> Every guideline App Review is likely to test this app against, checked against the code on `dev` (66089cd) and the open branches `split/apps`, `split/editor`, `split/collab` and `split/design` at 11:30 UTC, 8 Nov. **BLOCKER** means Apple would very likely reject the app, or a reviewer would hit a dead end. **RISK** means a possible rejection or a weak first impression. **OK** means checked and fine. Blockers went to the conductor at 11:30 UTC.

## Blockers

| # | Guideline | Problem | Fix | Owner | State |
| --- | --- | --- | --- | --- | --- |
| B1 | 2.1(a) completeness | **Ask** is iPhone tab 4, and it needs the user's own OpenRouter key. A reviewer with no key reaches "No OpenRouter key. Add yours in Ask → Settings." A real participant has no key either. | (a) a capped review key in the secret `DEMO_OPENROUTER_KEY`, filled into the notes, and Ask moved from the tab bar to More; or (b) Ask hidden in Release builds for this version. Choose (a) if the key exists by 16:00, otherwise (b). | collab, design | **ruled (a):** the review key secret exists; Ask moves to More; notes in [review-notes.txt](review-notes.txt) |
| B2 | 2.1(a) completeness | **Vault** (More → Personal) is a dead end without a key. Its empty state says "Open a vault with your team key or Face ID", but the public app has no team. | Hide Vault in the public Release build; it is not in the MVP. If it stays, set the `DEMO_VAULT_KEY` secret and use wording with no team. | design | **ruled:** hide Vault in the Release build |
| B3 | 5.2.1 intellectual property, 2.3.7 | The first tab's header reads **"Web Summit Lisbon · 9–12 Nov"** (`Packages/PTAgenda/Sources/PTAgenda/News/AgendaView.swift:35`), so every Agenda screenshot would carry the trademark. Dinis decided: none in the name, the icon or the screenshots. | Change the header to "Lisbon · 9–12 Nov" before release takes screenshots. Also change the calendar note "From PrompTugal · Web Summit Lisbon 2026" (`CalendarExport.swift:37`) to "From PrompTugal · Lisbon, Nov 2026". | team | **ruled:** "Lisbon · 9–12 Nov" |
| B4 | 2.1(a), 2.3.1 accurate metadata | `scripts/testflight/review-notes.txt` on `dev` still describes the Team app: "Who are you?", Messages, The Wall, sample data. A reviewer who follows those notes finds none of it. | Merge editor's public version (`split/editor` 93279d1). The texts in [review-notes.md](review-notes.md) replace it once B1 and B2 are decided. Fill in `CONTACT_ADDRESS` and `RESPONSE_TIME`, or `tf.py` drops those lines. | editor, testflight | **ruled:** final text in [review-notes.txt](review-notes.txt); the contact address is on the support page (48 hours) |
| B5 | 5.1.1(ii) purpose strings, 2.1 crash | The first upload was rejected in processing (ITMS-90683, speech). Holding the dictation button calls `AVAudioApplication.requestRecordPermission()`, which crashes without `NSMicrophoneUsageDescription`. Both strings are on `split/apps` (326147f), but not yet on `dev`. | Merge `split/apps` before the next upload. Check both keys in the built Info.plist (`plutil -p`). | apps, conductor | **ruled:** merge 326147f when green, before any upload |

## Risks

| # | Guideline | Problem | Fix | Owner |
| --- | --- | --- | --- | --- |
| R1 | 5.2.1, 5.2.2 | **All websites** lists `web-summit.sgit.ai`, the team's site, with the `ShortcutWebSummit` image, which reads "RiskMandate • Web Summit edition" (`Packages/PTWeb/Sources/PTWeb/Resources/Websites.json`). That is team content and a trademark in the public app. | **Ruled:** the public app gets its own websites list without `web-summit.sgit.ai` and without the `ShortcutWebSummit` image. | team, apps |
| R2 | Age rating (unrestricted web access) | The user can edit the shortcut list in Files (`Websites.json`, `UIFileSharingEnabled`) and add any HTTPS site. That is arguably unrestricted web access, which would move the rating up to 18+. | Fixed by R1 (one fixed site, or `web.all` hidden). Then answer "No" (see [age-rating.md](age-rating.md)). | apps |
| R3 | 1.5 developer information, 5.1.1(i) | The support page has no email address ("A support email address is coming"). Apple expects an easy way to contact the developer. The privacy page on `dev` still describes the Team app (team dashboards, messages, the "Who are you?" name). | **Ruled:** editor's pages (en and `/pt/`) carry the contact address, answered within 48 hours; the conductor merges `split/editor` before submission. | editor, conductor |
| R4 | 2.3.1, 2.3.3 accurate metadata | The listing must describe only what is in the binary. The MVP's **Now** tab, **Explore** and pt-PT/pt-BR app text are not on `dev`: `knownRegions` is `en, Base`. | The listing marks those lines "only if merged". Release removes any line whose feature is not in the build being submitted. | release, review |
| R5 | 5.2.2 third-party content | The agenda is the summit's public program, republished by an independent newsroom. A reviewer may ask whether we may use it. | The review notes say where it comes from, that we link to the source, and that we are not affiliated. Screenshots show no third-party logos. | review (notes), release (screenshots) |
| R6 | 5.1.2(i) data use, third-party AI | Ask sends the question and the chosen context to OpenRouter and the model maker. The consent sheet comes before the first message, and only the public agenda is on by default. That meets the November 2025 rule on sharing with third-party AI, as long as the sheet names OpenRouter. | Checked: the consent sheet (`AskView.swift:241`) names OpenRouter and the model's provider. Still to do: the prompt in `AIContext.swift:105` says "used by the PrompTugal team", and the starters intro (`AskView.swift:109`) says "and the team"; collab's `split/collab` 38c85cc fixes the intro. **New:** Ask → Key and settings offers "Save key to my vault" (`AskView.swift:421`). With Vault hidden that is a dead end, so hide it in the public app. | collab |
| R7 | 2.3.8, 2.3.10 | The name "PrompTugal: Lisbon Summit" is generic, but next to the summit's dates it may read as the official app. | The description's first line says "independent", and the Settings footer has the non-affiliation note (`pt.notAffiliated`). No logo, colors or wording from the event's own app. | review (done in the listing) |
| R8 | 4.2 minimum functionality, 4.2.2 | Two of the destinations are web views (PrompTugal.news, All websites). The app must not look like a website wrapper. | The native screens lead: Agenda, My day, Plan my day, News, Graph, the widget and Siri. Screenshots show only native screens. | release (screenshots), ux |
| R9 | 2.5.4 background modes | `UIBackgroundModes` has `fetch`, and two `BGTaskSchedulerPermittedIdentifiers` are declared. Only the vault refresh registers a `BGAppRefreshTask` (`VaultBackground.swift:21`). If Vault is hidden (B2) and nothing registers `news.promptugal.reader.refresh`, the declared mode has no use. | When collab's PTSync background sync lands, it registers `…reader.refresh`. Otherwise remove the unused identifier. | collab, apps |
| R10 | Entitlements | `webcredentials:promptugal.news` is declared. The passkey and universal-link file on promptugal.news was a 404 in the earlier review, and the public app uses no passkeys. Not a rejection, but a dead entitlement. | Remove it from `PrompTugal.entitlements` unless a feature uses it. | apps |
| R11 | 2.1 performance | The design branch adds a decks screen and an external-display scene after the readiness review. New screens late in the day add crash risk. | One full run on iPhone and iPad after the freeze. Release checks a cold launch with no network (the offline core pack). | design, platform |

## OK

| Guideline | What was checked |
| --- | --- |
| 2.1 demo access | No account, no sign-up and no login. The agenda and the news need no keys. `review-info.json` sets `demoAccountRequired: false`. |
| 2.3.7 | The name, the planned subtitle and the keywords have no "Web Summit", and no competitor names. |
| 4.1 copycats, 5.2 icon | The icon is "PT .news", black and red serif letters on paper. It has no event logo or colors. |
| 5.1.1(i) privacy policy | Linked in the app (Settings → About → Privacy, `SupportLinks.privacy`) and in the listing. The page content is R3. |
| 5.1.1(ii) purpose strings | Camera (vault QR only), Face ID (vault keys), calendar write-only, plus microphone and speech once B5 merges. Each says what and when. Notifications are asked for only after a tap. |
| 5.1.1(iv) | No access forced at launch; every permission comes from a user action. |
| 5.1.2 | No tracking, no analytics, no ads and no third-party SDK. The privacy manifest has `NSPrivacyTracking` false, with reasons for UserDefaults (CA92.1) and file timestamps (C617.1). The widget and intents manifests are on `split/apps` (bc65b90). |
| 3.1.1 purchases | None in the public app: the bridge has no meter (`meter: nil, offersAppTopUp: false` in `PublicFeatures.swift`), and checkout hosts are blocked in web views. |
| 1.2 user-generated content | None: PTLanes is not linked, so there are no messages and no posts. |
| Debug | The debug destination, the switch and the launch arguments are `#if DEBUG` only (`Destinations.swift`, `PublicSettingsView.swift`, `PublicShell.swift`). |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO`. Only Apple's cryptography is used (CryptoKit, Keychain, HTTPS). |
| iPad | `TARGETED_DEVICE_FAMILY = 1,2`, all four iPad orientations, a sidebar layout, and app-switcher privacy cover. |
| ATS | No exceptions; `WKAppBoundDomains` is promptugal.news only. |

## Rulings (conductor, 11:25 UTC)

- B1: option (a). Ask stays, with the review key from the `DEMO_OPENROUTER_KEY` secret, and moves to More unless ux places it elsewhere.
- B2: Vault hidden in the public Release build.
- B3: "Lisbon · 9–12 Nov" in AgendaView and CalendarExport.
- B4: the final notes are [review-notes.txt](review-notes.txt). The conductor merges `split/editor` once its pt pages are ready.
- B5: apps 326147f merges before any upload.
- R1: a separate websites list for the public app.
- Languages: the pt listings go in only if i18n merges by 16:00; otherwise English only.
- Because Ask ships, the App Privacy label declares Other User Content, and `PrivacyInfo.xcprivacy` must declare it too (apps); see [app-privacy.md](app-privacy.md).
