# Status · Editor

> Done and green, all merges checked. After design (9024bc0): 24 of 25 features in the beta, Reading credit 'Debug builds only'. Review notes, support and privacy pages match the app's real UI text. Waiting only on Dinis: support email, response time, demo keys, the Ask label call.

Branch: `night/editor` · Last update: 17:10 UTC

## Done

- **R3, guideline 5.1.1(i): `website/pages/privacy.html` rewritten from the code.** What stays on the device; what goes where (public feeds from promptugal.news and the team site; Ask to openrouter.ai and the model provider, only after consent; messages and notes encrypted to the lane server; vault reads and writes encrypted to the vault server; dictation on the device or by Apple; purchases through Apple; calendar write-only); where the keys are (vault keys behind Face ID or the passcode; the OpenRouter key in the Keychain without Face ID, after first unlock; the lane key in the Keychain); no tracking, analytics, ads or third-party SDKs. "Collects nothing" and "nothing is sent back" are gone.
- **R4, guidelines 1.2 and 1.5: Contact section on `website/pages/support.html`** (`#contact`). GitHub issues for now, and one line saying a support email is coming. No address invented. Report and Block in Messages are described for when collab's change lands.
- **`review-notes.md`**: the App Review notes for external TestFlight or Unlisted, written for the app after this pack's fixes, with a checklist of what must be on the build and `<placeholders>` for the demo key, vault, lane, response time and contact.
- **`privacy-labels.md`**: the App Store Connect answers, data type by data type, each with file and line evidence. No tracking; recommended "No data collected", with one judgement call on Ask.
- **Status pages of this pack on the site.** The push dashboard now has one table per brief pack, newest first, and the validator checks that every status page of every pack is listed. The developer area links this pack.

## Done, round 2 (15:20)

- **Features follow the review fixes.** New features, each with a marker in the code (`text:<file>::<exact text>` evidence): Try with sample data (`Try with sample data`), Ask asks first (`AskConsentSheet`), Report and block (`ReportBlockMenu`), Trusted signers and your own vault (`Trust this signer`, `Make this my vault`), Private in the app switcher (`struct PrivacyCover`). Face ID unlock now also requires the Keychain loop with no unprotected fallback. On dev at 15:20: 21 of 25 in the beta; the four "Coming" flip as design and collab merge.
- **Reading credit:** a feature whose `hidden_in_release` marker is present (`static let isAvailable = false` in `Store/ReadingCredit.swift`) is labelled "Debug builds only", not "In the beta", with a test. plans.html says it is hidden in release builds.
- **Teams page:** debug mode is described as turned on in Settings.
- **release-setup.md:** Associated Domains is `webcredentials:` only (applinks removed); the AASA gotcha updated; Dinis's paid account means Xcode automatic signing works with full entitlements.
- **Overnight morning summary:** test count updated (141 tests in 38 suites, platform's report); the AASA item now names `webcredentials` only.
- **Build log:** "App Review readiness" entry.

## Done, round 3 (15:58, after collab merged at 7d135e0)

- Labels on dev: 23 of 25 in the beta. Ask asks first (`AskConsentSheet`) and Report and block (`ReportBlockMenu`) flipped by themselves. Still Coming: Try with sample data and the app-switcher cover (design, not merged).
- Privacy page, Ask paragraph, checked against `AI/AskView.swift` and `AI/AIContext.swift`: it sends the question, the conversation so far and the switched-on context; nothing until **Allow**; one switch per kind of context; only the public agenda on by default (`AIContextKind.defaults = [.agenda]`); withdraw in Ask → Key and settings ("Withdraw permission").
- Support page, checked against `Lanes/LanesView.swift` and `Lanes/LaneReport.swift`: press and hold a message for **Report…** or **Block**; Report opens a pre-filled email with no recipient until the support address is set (`LaneReport.contactAddress` is empty); Block hides the sender or lane on this device, listed and reversible with Unblock.

## Done, round 4 (16:35, after team merged at 8c6bfcb)

- Reading credit reads **Debug builds only** (`ReadingCredit.isAvailable` is false in Release). Labels: 23 of 25 in the beta, 1 Debug only, 2 Coming (design).
- plans.html states no prices, so the StoreKit prices (£4.99 and £19.99 in the local StoreKit file, shown from `Product.displayPrice`) need nothing there.
- Support FAQ: payment pages (Stripe, PayPal and other hosted checkouts, the site's top-up page) are not opened in the app (`Bridge/CheckoutPolicy.swift`, `AppBridge.handlesNavigation`); and the app asks for notification permission only after a tap ("Turn on reminders?", `Team/TeamFeatures.swift:156`; `notify.plan` never prompts, `AppBridge.swift:216-221`). The privacy page's reminders line says the same. No wording points people to pay outside the app (guideline 3.1.1).

## Done, round 5 (17:10, after design merged at 9024bc0)

- Labels: **24 of 25 in the beta** (Try with sample data and the app-switcher cover flipped by themselves), Reading credit **Debug builds only**.
- Review notes matched to design's UI text: My day's "Who are you?" with **Try with sample data** and **I am not on the team** (`Dashboards/TodayView.swift:61-74`); the **Sample data** banner with **Leave** (`Shell/AppShell.swift:140-156`); change it later in Settings → Team; the **Debug mode** switch in Settings (`Shell/SettingsView.swift:31`); Privacy and Support links and the non-affiliation line in Settings → About (`SettingsView.swift:43-50`, `SupportLinks.independence`); Report… and Block on press and hold. The checklist now has an "On dev" column: everything is on dev except Dinis's contact address and the demo keys.
- Privacy and support pages say they are linked from Settings → About.

## Next

- Re-read the privacy page when collab's consent sheet and report/block land, and correct any wording that differs from the app.

## Blocked

## Needs from others

- **Dinis:** a support email address (support page, review notes, and `LaneReport.contactAddress` in the app, where Report… sends) and the response time for reports; the call on Ask in the privacy labels (see `privacy-labels.md`).
- **Platform:** if Dinis declares Ask's data as collected, the privacy manifest's `NSPrivacyCollectedDataTypes` (empty today) must list the same type.
