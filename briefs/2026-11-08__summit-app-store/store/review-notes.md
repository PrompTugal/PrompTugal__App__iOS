# Review notes and demo instructions

> The text for App Store Connect → App Review Information → Notes (App Store), and for TestFlight → Test Information → Beta App Review notes. Both paths use the same text. It replaces `scripts/testflight/review-notes.txt` once B1 and B2 are decided. Editor's public draft on `split/editor` was the starting point. Placeholders in angle brackets come from secrets, never from this public repository; `tf.py` drops a line whose placeholder is not set.

## Settings

| Field | Value |
| --- | --- |
| Sign-in required | No (`demoAccountRequired: false`) |
| Contact first name, last name, email, phone | Secrets `REVIEW_CONTACT_FIRST_NAME`, `REVIEW_CONTACT_LAST_NAME`, `REVIEW_CONTACT_EMAIL`, `REVIEW_CONTACT_PHONE` (Dinis) |
| Attachment | None needed. If Apple asks about the agenda's source, reply with the source link and the independence page (`FeedClient.disclosure`). |

## Notes (4000 characters)

The final text is [review-notes.txt](review-notes.txt), written to the conductor's rulings at 11:30 UTC. Ask ships with the review key (B1 option a) and moves to More; Vault is hidden (B2). On merge, testflight copies it over `scripts/testflight/review-notes.txt`, or points `notesFile` in `review-info.json` at it. Release pastes the same text into the App Store version's review notes.

Its only placeholder is `<DEMO_OPENROUTER_KEY>`; the secret exists. The contact address is not in the notes: Apple gets it from the contact fields (`REVIEW_CONTACT_*`), and the support page lists it. So no `CONTACT_ADDRESS`, `RESPONSE_TIME` or `CAP` placeholder is left for `tf.py` to report as missing.

## Checks before release and testflight paste this

- [ ] Each step names a screen that is in the build. Check against `Apps/PrompTugal/Shell/Destinations.swift`; the tab order on dev is Agenda, My day, News, Ask, More; after the B1 change, Ask is in More.
- [ ] The design branch's new screens (Now, Explore, decks) get a line here once they are merged and in the build.
- [ ] Step 1 says "the star" (`AgendaView.swift:109`, `star` / `star.fill`): if design changes the pick button, change the word.
- [ ] The secrets are set: `REVIEW_CONTACT_*` (the phone is still missing, Dinis) and `DEMO_OPENROUTER_KEY` (set).
- [ ] The review key works on the day of submission: one question in Ask on a device, and the cap leaves room for a few days of review.
- [ ] If ux keeps Ask as a tab, step 7 says "Ask (fourth tab)".
