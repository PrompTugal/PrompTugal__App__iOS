# Review notes and demo instructions

> The text for App Store Connect → App Review Information → Notes (App Store), and for TestFlight → Test Information → Beta App Review notes. Both paths use the same text. It replaces `scripts/testflight/review-notes.txt` once B1 and B2 are decided. Editor's public draft on `split/editor` was the starting point. Placeholders in angle brackets come from secrets, never from this public repository; `tf.py` drops a line whose placeholder is not set.

## Settings

| Field | Value |
| --- | --- |
| Sign-in required | No (`demoAccountRequired: false`) |
| Contact first name, last name, email, phone | Secrets `REVIEW_CONTACT_FIRST_NAME`, `REVIEW_CONTACT_LAST_NAME`, `REVIEW_CONTACT_EMAIL`, `REVIEW_CONTACT_PHONE` (Dinis) |
| Attachment | None needed. If Apple asks about the agenda's source, reply with the source link and the independence page (`FeedClient.disclosure`). |

## Notes (4000 characters)

Pick one of the two Ask paragraphs and one of the two Vault paragraphs once the conductor decides B1 and B2, and delete the others.

```
PrompTugal is an independent companion app for participants of Web Summit Lisbon (9 to 12 November 2026), made by PrompTugal.news, a newsroom covering AI in Portugal. It is not affiliated with, endorsed by or sponsored by Web Summit; the app says so in Settings > About, and the store name, icon and screenshots do not use the event's name or marks.

NO ACCOUNT IS NEEDED. There is no sign-up and no login. Every main screen works as soon as the app opens.

THINGS TO TRY
1. Agenda (first tab). The summit program in Lisbon time, built into the app and refreshed from promptugal.news. Search "AI" and tap the star on a session to pick it. Tapping a session opens its page.
2. My day (second tab). Your picks in one list. Plan my day (More > Summit) shows free slots and walking times.
3. Reminders. Settings > Reminders: turn them on. The notification permission is asked only then. A local notification is scheduled before each pick.
4. Add to Calendar, in My day. Write-only calendar access; the app cannot read the calendar.
5. News (third tab). Stories and newsletter editions from PrompTugal.news. Turn on airplane mode: the agenda, picks and cached news still work.
6. Widget and Siri. Add the PrompTugal widget for what is next; or ask Siri "What's next in PrompTugal".

[ASK, if shipped] 7. Ask (More > Ask). An AI assistant for the program. It uses the user's own OpenRouter key. For review, paste this key in Ask > Key and settings: <DEMO_OPENROUTER_KEY> (created for review, spending cap <CAP>). Before the first message, a consent sheet says what is sent (the question, plus only the context switched on; the public agenda by default) and where (OpenRouter and the model provider). Nothing is sent until you tap Allow. Hold the microphone button to dictate; the microphone and speech permissions are asked then.
[ASK, if hidden] Ask is not in this version.

[VAULT, if shipped] 8. Vault (More > Personal). Optional encrypted storage. Tap Import, paste <DEMO_VAULT_KEY>, then Import. Face ID opens it next time. The camera is used only to scan a vault key's QR code.
[VAULT, if hidden] (nothing: delete this line)

WHAT THE APP SENDS
- Public feeds are read from promptugal.news; nothing about the user is sent with them.
- Picks, plans and reminders stay on the device.
- Ask (if present) sends the question and chosen context to openrouter.ai with the user's own key, only after consent.
- No tracking, no analytics, no advertising, no third-party SDK.
Privacy policy: https://ios.app.promptugal.news/privacy.html (also Settings > About > Privacy). Support: https://ios.app.promptugal.news/support.html.

AGENDA SOURCE. The program is the summit's public schedule, republished on promptugal.news by our newsroom; each session opens its page there. We are an independent news site covering the event.

NO USER-GENERATED CONTENT. No posts, comments or messages between people. Contact for any report: <CONTACT_ADDRESS>.

NO PURCHASES. No in-app purchases or subscriptions; payment pages are not opened inside the app.

ENCRYPTION. Only Apple's encryption (CryptoKit, Keychain, HTTPS); ITSAppUsesNonExemptEncryption is NO.
```

Length: about 2,700 characters with both optional paragraphs in, well under 4,000.

## Checks before release and testflight paste this

- [ ] Each step names a screen that is in the build. Check against `Apps/PrompTugal/Shell/Destinations.swift`; the tab order there is Agenda, My day, News, Ask, More. If Ask moves to More, "More > Ask" is right; if Ask stays a tab, change step 7.
- [ ] The design branch's new screens (Now, Explore, decks) get a line here once they are merged and in the build.
- [ ] Step 1 says "the star" (`AgendaView.swift:109`, `star` / `star.fill`): if design changes the pick button, change the word.
- [ ] The secrets are set: `REVIEW_CONTACT_*`, `CONTACT_ADDRESS`, plus `DEMO_OPENROUTER_KEY` and `CAP` if Ask ships, and `DEMO_VAULT_KEY` if Vault ships.
