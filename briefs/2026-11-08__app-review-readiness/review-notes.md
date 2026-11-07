# App Review notes for PrompTugal

> The text to paste into App Store Connect → App Review Information → Notes, for an external TestFlight build or an Unlisted App Store submission. Written for the app as it will be once this pack's fixes land. Placeholders in <angle brackets> are filled by Dinis just before submitting.

**Written by:** the editor, 8 November 2026 · **Pack:** [App Review readiness](README.md) · **Check before pasting:** every item marked *(needs fix X)* must be on the build you submit.

## Before you paste: what must be true of the build

| Item | Fix | Owner |
| --- | --- | --- |
| "Try with sample data" on the "Who are you?" screen, and "not on the team" opens the reader view | R1 | design, team |
| A consent sheet before the first Ask message, with context off by default | R2 | collab |
| Report and Block in Messages | R4 | collab |
| Debug mode off by default in Release builds | S4, Q5 | design, platform |
| Reading credit hidden in Release builds | R5 | team |
| A privacy link and a support link in Settings | R3 | design |
| The privacy page on the site matches the code | R3 | editor (done) |
| A contact address on the support page | R4 | editor (GitHub issues for now; email to come) |
| Demo OpenRouter key with a spending cap, demo vault and demo lane, made for the reviewer only | decision 6 | Dinis, vault |

## The notes (paste from here)

PrompTugal is the companion app of PrompTugal.news, an independent newsroom covering the AI scene in Portugal, for the people working at Web Summit Lisbon (9 to 12 November 2026). It is mainly used by our own team, and by attendees who read our coverage. PrompTugal is not affiliated with Web Summit.

**No account is needed.** The app has no sign-up and no login.

**How to see every screen without our team's keys.** On first launch the app asks "Who are you?". Tap **Try with sample data**. The app then fills every screen (My day, The team, Agents, Briefed, Newsroom, Wall) with made-up people and data that ship with the app. You can switch back in Settings. If you tap **I'm not on the team**, the app opens the reader view: the news, the agenda and your own schedule, which need no keys at all.

**Things to try**

1. **Today → Agenda.** The Web Summit Lisbon agenda in Lisbon time. Open a session and add it to your schedule; **Today → My schedule** shows it, and a reminder is scheduled 10 minutes before (if you allow notifications).
2. **News.** The PrompTugal.news feed, newsletter editions and a native graph of companies, people and events.
3. **Ask.** An AI assistant. It needs an OpenRouter key: paste `<DEMO_OPENROUTER_KEY>` (a key we created for review, with a spending cap of `<CAP>`). Before the first message the app shows a consent sheet that says what is sent (your question and only the context you switch on) and where (OpenRouter and the model provider). Nothing is sent until you agree.
4. **Vault.** An encrypted personal store, opened on the device with Apple's cryptography. Tap **Vault → Import**, paste `<DEMO_VAULT_KEY>`, then **Import**. The vault opens on its files. Next time, Face ID opens it.
5. **Messages.** Encrypted notes between teammates. With the demo vault open, **Messages** shows the demo lane `<DEMO_LANE_NAME>`. Each message has **Report** and **Block**.
6. **The Wall** (iPad): **Today → Wall**, a screen meant for an iPad on a stand.

**What the app sends, and where** (also on our privacy page, `https://ios.app.promptugal.news/privacy.html`):

- Public feeds are read from promptugal.news and our team's website. No personal data is sent with them.
- Ask sends the question and the chosen context to openrouter.ai, with the user's own key, only after consent.
- Messages and notes are encrypted on the device and stored as ciphertext on our vault server. The server cannot read them.
- Vault files are encrypted on the device; the server stores only ciphertext.
- Voice notes are transcribed on the device when the language allows; otherwise by Apple's speech service.
- There is no tracking, no analytics, no advertising and no third-party SDK.

**User-generated content (guideline 1.2).** Messages go only between people who hold each other's encrypted lane address; there is no public feed of user posts. Each message can be reported or its sender blocked from the message itself. Reports reach us through `<CONTACT_ADDRESS>` and GitHub issues, and we act on them within `<RESPONSE_TIME>`.

**In-app purchases.** Reading credit is hidden in this build. *(If Dinis decides to ship it: describe what it unlocks here, and make sure the price in the app matches App Store Connect.)*

**Encryption.** The app uses only encryption provided by Apple (CryptoKit, the Keychain, the Secure Enclave and HTTPS), so `ITSAppUsesNonExemptEncryption` is set to NO.

**Debug panels.** The app can show its network requests and vault traffic for developers. This is off by default in this build, and turned on in Settings → Debug.

**Contact during review:** `<REVIEW_CONTACT_NAME>`, `<REVIEW_CONTACT_EMAIL>`, `<REVIEW_CONTACT_PHONE>`.

## After pasting

- Fill **Sign-in required: No** in App Review Information (there is no login; the demo keys are optional features).
- Put the demo key, vault key and lane name only in the Notes field, never in the build or in this repository.
- Revoke the demo OpenRouter key and delete the demo vault and lane after review.
