# App Privacy answers (the nutrition label)

> The answers Dinis enters by hand in App Store Connect → App Privacy. They are derived from the code the public app links (PTCore, PTWeb, PTAgenda, PTNews, PTAsk, PTVaultUI, SGitVault; no PTLanes). They must agree with `Apps/PrompTugal/Resources/PrivacyInfo.xcprivacy` and with the privacy page. **Ruling at 11:30 UTC:** Ask ships (B1 option a) and Vault is hidden (B2). The answers below are the ones to enter.

## Where data goes, from the code

| Feature | What leaves the device | To whom | Code |
| --- | --- | --- | --- |
| Agenda and news | Nothing about the user: plain GET requests for public files | promptugal.news | `PTCore/Feed/Content.swift` (`FeedClient`) |
| Websites | Pages load as in a browser; one separate data store per site | promptugal.news (more if R1 is not fixed) | `PTWeb/Web/WebPage.swift`, `SiteDataStores.swift` |
| Picks, planner, reminders | Nothing: stored on the device; reminders are local notifications | none | `PTAgenda/Schedule`, `ReminderScheduler.swift` |
| Calendar | One event written on request; write-only access, no read | the user's own calendar (on device) | `CalendarExport.swift` |
| Ask | The question, the conversation and the context the user switches on (the public agenda by default; picks and the current page optional). Sent with the user's own key, only after consent | openrouter.ai and the model maker | `PTAsk/OpenRouter.swift`, `PublicAskProvider.swift` |
| Dictation in Ask | Audio, only while the button is held. On device when the language allows it, otherwise to Apple's speech service; not kept | Apple | `PTAsk/SpeechDictation.swift` |
| Vault (hidden in this build, B2) | Files encrypted on the device; the server stores ciphertext and opaque names | dev.send.sgraph.ai | `SGitVault`, `PTVaultUI` |
| Analytics, crash reporting, ads | None. No third-party SDK | none | the privacy manifest: `NSPrivacyTracking` false, no tracking domains |

## Answers

**Do you or your third-party partners collect data from this app?** Yes. Ask sends the user's questions to a third party that processes them.

| Data type | Collected | Used for | Linked to the user | Used for tracking |
| --- | --- | --- | --- | --- |
| User Content → Other User Content (Ask questions and the context the user chooses) | Yes | App Functionality | No | No |

Every other data type is **not collected**. That covers contact info, health and fitness, financial info, location, sensitive info, contacts, emails or text messages, photos or videos, audio data, gameplay content, customer support, browsing history, search history, identifiers, purchases, usage data, diagnostics and other data. Notes on the ones a reviewer may ask about:

- **Audio Data: not collected.** Dictation audio goes only to Apple's speech service, as part of the OS. The app does not send or keep it. Apple does not count processing by Apple's own frameworks as the developer's collection.
- **Search History: not collected.** Agenda and graph searches run on the device.
- **Identifiers: not collected.** No device ID, no advertising ID and no account. The OpenRouter key is the user's own credential, sent only to OpenRouter.
- **Vault files: not declared.** They are end-to-end encrypted. The server holds ciphertext it cannot read, under opaque names, and nobody can link them to a person. If Dinis prefers the stricter reading, add **Other User Content** again under the same answers (App Functionality, not linked, no tracking). The label does not change.
- **Ask: "not linked".** No account, no name and no device identifier is sent. The key is the user's, with their own OpenRouter account. OpenRouter's own terms apply to that account, and the privacy page says so.

**Tracking:** No. The app does not track users across apps or websites, and has no tracking domains.

## If Ask is ever hidden

In a build without Ask (and without Vault), nothing leaves the device except reads of public files. Then the answer is **"No, we do not collect data from this app"** (Data Not Collected). That is not the case for this submission.

## Consistency checks before submitting

- [ ] The privacy page lists the same features and hosts as the table above. Editor's `split/editor` privacy page; R3.
- [ ] `PrivacyInfo.xcprivacy`: `NSPrivacyCollectedDataTypes` is empty on dev, and Ask ships. **Apps adds** `NSPrivacyCollectedDataTypeOtherUserContent` (not linked, not tracking, purpose `NSPrivacyCollectedDataTypePurposeAppFunctionality`), so the manifest and the label agree.
- [ ] The widget and intents manifests (`split/apps` bc65b90) are merged.
