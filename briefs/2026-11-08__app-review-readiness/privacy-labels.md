# App Store Connect privacy labels: answers with evidence

> The answers for App Privacy in App Store Connect, data type by data type, each with the code that justifies it. Short version: no tracking, and nothing the team can read is collected. One judgement call remains for Dinis: whether Ask's prompts, which go to OpenRouter with the user's own key, count as "collected".

**Written by:** the editor, 8 November 2026, against `dev` at the start of the App Review push. Line numbers are as of that commit; check them again if the code moves. · **Pack:** [App Review readiness](README.md)

## How Apple decides what counts

App Store Connect asks about data that is **collected**: sent off the device in a way that the developer or its third-party partners can read it for longer than it takes to serve the request in real time. Data processed only on the device is not collected. Data that leaves the device encrypted so that the developer cannot read it is not collected either. **Tracking** means linking data with other companies' data for advertising, or sharing it with data brokers.

## The answers

### 1. Does the app or its partners use data for tracking?

**No.** There is no advertising, no analytics and no third-party SDK.

- The privacy manifest says `NSPrivacyTracking` false, with no tracking domains (`PrompTugal/App/Resources/PrivacyInfo.xcprivacy:28-31`).
- The app never reads the advertising identifier or `identifierForVendor` (no matches in the source).
- The app uses Apple frameworks only; there are no third-party packages.

### 2. Data collected: the recommended answer is "No data collected", with one judgement call

| Data type (Apple's name) | Leaves the device? | Readable by the team or its partners? | Answer | Evidence |
| --- | --- | --- | --- | --- |
| Contact info (name, email, phone, address) | No | No | Not collected | The "Who are you?" choice is stored in UserDefaults on the device (`Team/TeamIdentityStore.swift:26-29`). A message's sender name travels only inside an encrypted lane message (below). |
| Health, fitness, financial info | No | No | Not collected | No such APIs are used. Purchases go through Apple (`Store/CreditStore.swift:70`); the app never sees card details. |
| Location | No | No | Not collected | No Core Location code. |
| Sensitive info | No | No | Not collected | None. |
| Contacts | No | No | Not collected | No Contacts framework code. |
| User content: messages and notes | Yes, to `dev.send.sgraph.ai` (or the server in the lane's address) | **No.** Encrypted on the device to the lane's recipient key; the server stores ciphertext and answers blind | Not collected | `Lanes/LaneClient.swift:35-54` (encrypt, then append), `Lanes/LaneAddress.swift:25` |
| User content: vault files (picks, day plan, notes, OpenRouter key if the user saves it there) | Yes, to `dev.send.sgraph.ai` | **No.** Encrypted on the device; the server holds ciphertext and opaque file names | Not collected | `Packages/SGitVault/Sources/SGitVault/VaultModels.swift:8`, `VaultCrypto.swift` |
| User content: Ask prompts and the chosen context | Yes, to `openrouter.ai`, then to the model provider the user picked | **Not by the team.** Sent with the user's own OpenRouter key, to the user's own OpenRouter account. OpenRouter and the model provider may keep it under their own terms. | **Judgement call**, see below | `AI/OpenRouter.swift:9` (endpoint), `:121` (the user's key as bearer), `AI/AIContext.swift` (the context kinds) |
| User content: voice | Only when on-device recognition is not available for the language, and then to Apple's speech service | No | Not collected (processed by Apple as part of iOS) | `Lanes/SpeechDictation.swift:37-38`; the app shows which applies (`Lanes/LanesView.swift:234`) |
| Browsing history | No | No | Not collected | Websites open in web views with one data store per site, on the device (`Bridge/SiteDataStores.swift:5-19`) |
| Search history | No | No | Not collected | Agenda search runs on the device. |
| Identifiers (user ID, device ID) | Only a random 8-character label, inside encrypted note records | No | Not collected | `Lanes/LanesStore.swift:320-329` |
| Purchases | Handled by Apple | No | Not collected | StoreKit 2, `Store/CreditStore.swift:70` |
| Usage data, diagnostics | No | No | Not collected | The debug panels' logs stay on the device. TestFlight crash reports and feedback are Apple's, not the app's. |

### The judgement call: Ask

Ask sends the user's question and the context they switch on (today's agenda, their picks, their team's status, the current page, their day plan, their agents) to `openrouter.ai`. The key is the user's own: they create it, they pay for it, and the request goes to their OpenRouter account. The team never receives the prompt.

- **Recommended answer: not collected**, because neither the developer nor a partner of the developer can read it; OpenRouter is the user's own provider. The in-app consent sheet before the first message (collab, R2) and the privacy page say exactly where it goes.
- **If Dinis prefers to be conservative:** declare **User Content → Other User Content**, used for **App Functionality**, **not linked** to the user's identity, **not used for tracking**. If so, the privacy manifest's `NSPrivacyCollectedDataTypes` (empty today, `PrivacyInfo.xcprivacy:32-33`) must list the same type, or the two disagree. That is a change for platform.

Either way, App Review guideline 5.1.2(i) needs the consent step in the app; the label does not replace it.

## Privacy policy URL

`https://ios.app.promptugal.news/privacy.html`. It lists what stays on the device, what is sent where, where the keys are kept, and what the app never does. It must stay true to the code: if a feature starts sending something new, the page changes in the same release.
