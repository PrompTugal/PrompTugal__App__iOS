# Status · Editor

> All four items are done and green: the privacy page matches the code, the support page has a Contact section, the App Review notes and the privacy-label sheet are in this pack, and the push dashboard shows this pack's status pages.

Branch: `night/editor` · Last update: 14:55 UTC

## Done

- **R3, guideline 5.1.1(i): `website/pages/privacy.html` rewritten from the code.** What stays on the device; what goes where (public feeds from promptugal.news and the team site; Ask to openrouter.ai and the model provider, only after consent; messages and notes encrypted to the lane server; vault reads and writes encrypted to the vault server; dictation on the device or by Apple; purchases through Apple; calendar write-only); where the keys are (vault keys behind Face ID or the passcode; the OpenRouter key in the Keychain without Face ID, after first unlock; the lane key in the Keychain); no tracking, analytics, ads or third-party SDKs. "Collects nothing" and "nothing is sent back" are gone.
- **R4, guidelines 1.2 and 1.5: Contact section on `website/pages/support.html`** (`#contact`). GitHub issues for now, and one line saying a support email is coming. No address invented. Report and Block in Messages are described for when collab's change lands.
- **`review-notes.md`**: the App Review notes for external TestFlight or Unlisted, written for the app after this pack's fixes, with a checklist of what must be on the build and `<placeholders>` for the demo key, vault, lane, response time and contact.
- **`privacy-labels.md`**: the App Store Connect answers, data type by data type, each with file and line evidence. No tracking; recommended "No data collected", with one judgement call on Ask.
- **Status pages of this pack on the site.** The push dashboard now has one table per brief pack, newest first, and the validator checks that every status page of every pack is listed. The developer area links this pack.

## Next

- Re-read the privacy page when collab's consent sheet and report/block land, and correct any wording that differs from the app.

## Blocked

## Needs from others

- **Dinis:** a support email address (support page, review notes) and the response time for reports; the call on Ask in the privacy labels (see `privacy-labels.md`).
- **Collab:** the privacy page and the support page say the app asks for consent before the first Ask message, and that Messages has Report and Block. Both are true once your R2 and R4 changes are merged; tell me the exact button names if they differ from "Report" and "Block".
- **Platform:** if Dinis declares Ask's data as collected, the privacy manifest's `NSPrivacyCollectedDataTypes` (empty today) must list the same type.
