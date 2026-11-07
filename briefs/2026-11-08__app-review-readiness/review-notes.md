# App Review notes for PrompTugal

> The text to paste into App Store Connect → App Review Information → Notes, for an external TestFlight build or an Unlisted App Store submission of the public PrompTugal app (bundle `news.promptugal.reader`). After the split into three apps the reviewer needs no sample data and no team keys, because the app holds no team features. Placeholders in <angle brackets> are filled by Dinis just before submitting.

**Written by the editor, 8 November 2026 · Pack:** [App Review readiness](README.md) · **Plan:** [three apps](../2026-11-08__three-apps/README.md) · **Check before pasting:** every item in the table below must be true of the build you submit. The Team app is not reviewed: it goes to the team's own TestFlight.

## Before you paste: what must be true of the build

| Item | Source | Owner | State |
| --- | --- | --- | --- |
| The build is the **PrompTugal** app (`Apps/PrompTugal`), not the Team app | three apps, phase 4 | platform, design | pending phase 4 |
| It links PTCore, PTWeb, PTAgenda, PTNews, PTAsk, PTVaultUI and SGitVault, and **not** PTLanes | contracts §1, §3 | platform | pending phase 4 |
| No "Who are you?" screen, no team dashboards, no sample-data mode, no Messages, no Report or Block | contracts §3 | design | pending phase 4 |
| No debug panels in Release builds | contracts §3 | design | pending phase 4 |
| No reading credit and no in-app purchase (`Store/` stays in the Team app) | contracts §2 | team | pending phase 4 |
| A consent sheet before the first Ask message, with context off by default except the public agenda | R2 | collab | on dev (`AI/AskView.swift`, `AI/AIContext.swift`); check it after PTAsk moves |
| Ask offers no team, teammate or agent context | contracts §1 (PTAsk does not depend on the team) | collab | **to confirm** |
| Privacy and Support links, and the non-affiliation line, in Settings → About of the PrompTugal app | R3 | design | to confirm in `Apps/PrompTugal` |
| The privacy page on the site matches the code | R3 | editor | page written for the public app; re-check against `Apps/PrompTugal` when it lands |
| A contact address on the support page | R4 | Dinis | **no**: GitHub issues for now |
| Demo OpenRouter key with a spending cap, made for the reviewer only (optional) | decision 6 | Dinis | the key is Dinis's |
| Demo vault, made for the reviewer only (optional) | decision 6 | Dinis, vault | vault's script is on dev; the vault is Dinis's |

Why some rows of the earlier notes are gone: the sample-data mode, the Messages and Report or Block text, the reading-credit note and the debug-panel note all described the one app that held team features. They do not apply to the public app. They stay in the [Team app privacy page](https://ios.app.promptugal.news/admin/team-privacy.html) and in the earlier version of this file in git history.

## The notes (paste from here)

PrompTugal is the companion app of PrompTugal.news, an independent newsroom covering the AI scene in Portugal, for readers and for the people at Web Summit Lisbon (9 to 12 November 2026). PrompTugal is independent; it is not affiliated with, endorsed by or sponsored by Web Summit (the app says so in Settings → About).

**No account is needed.** The app has no sign-up and no login.

**No keys are needed to see the app.** Install it and open it: the summit agenda and the news load from the public site, and you can use every part of the app that does not send your own data to a service. The two optional features that use a key or a vault have demo keys below.

**Things to try**

1. **Agenda.** The Web Summit Lisbon agenda in Lisbon time. Open a session and add it to your schedule. **My schedule** shows it, and a reminder is scheduled 10 minutes before (if you allow notifications).
2. **News.** The PrompTugal.news feed, newsletter editions and a native graph of companies, people and events.
3. **Websites.** The PrompTugal.news website opens inside the app, with the app's own page and back history. Links that leave the site open in Safari.
4. **Ask (optional).** An AI assistant. It needs an OpenRouter key: paste `<DEMO_OPENROUTER_KEY>` (a key we created for review, with a spending cap of `<CAP>`). Before the first message the app shows a consent sheet that says what is sent (your question and only the context you switch on) and where (OpenRouter and the model provider). Nothing is sent until you agree.
5. **Vault (optional).** An encrypted personal store, opened on the device with Apple's cryptography. Tap **Vault → Import**, paste `<DEMO_VAULT_KEY>`, then **Import**. The vault opens on its files. Next time, Face ID opens it.

**What the app sends, and where** (also on our privacy page, `https://ios.app.promptugal.news/privacy.html`, linked from Settings → About → Privacy; support is at Settings → About → Support):

- Public feeds are read from promptugal.news. No personal data is sent with them.
- Ask sends the question and the chosen context to openrouter.ai, with the user's own key, only after consent.
- Vault files are encrypted on the device; the server stores only ciphertext.
- "Add to Calendar" writes one session to the calendar when the user asks, with write-only access.
- There is no tracking, no analytics, no advertising and no third-party SDK.

**User-generated content (guideline 1.2).** The app has no user-generated content: no posts, no messages between people, no comments. Everything it shows comes from PrompTugal.news or from the websites it opens. Reports about the content reach us through `<CONTACT_ADDRESS>` and GitHub issues, and we act on them within `<RESPONSE_TIME>`.

**In-app purchases.** None. The app has no purchase, no subscription and no credit. Payment pages on websites are not opened inside the app.

**Encryption.** The app uses only encryption provided by Apple (CryptoKit, the Keychain, the Secure Enclave and HTTPS), so `ITSAppUsesNonExemptEncryption` is set to NO.

**Contact during review:** `<REVIEW_CONTACT_NAME>`, `<REVIEW_CONTACT_EMAIL>`, `<REVIEW_CONTACT_PHONE>`.

## After pasting

- Fill **Sign-in required: No** in App Review Information (there is no login; the demo keys are optional features).
- Put the demo key and vault key only in the Notes field, never in the build or in this repository.
- Revoke the demo OpenRouter key and delete the demo vault after review.
- If the build you submit still shows the sample-data screen, Messages or debug panels, it is the Team app or an unsplit build. Do not submit it. Stop and ask the conductor.
