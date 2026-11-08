# Go / no-go before submission

> Checked by review.B against the exact build number to be submitted, once for the TestFlight public link (Beta App Review) and once for the App Store version. Every line must be **GO**, or the conductor writes down why it is accepted. Release and testflight do not submit until review sends "GO <build>" to the conductor.

**Build:** `0.4.x (n)` · **Commit:** `…` · **Checked at:** `hh:mm UTC` · **Result:** pending

## Binary

| # | Check | How | State |
| --- | --- | --- | --- |
| G1 | The upload passed processing: no ITMS-90683 (purpose strings) and no ITMS-91053 (privacy manifests) | App Store Connect build status "Ready to Submit"; testflight's `tf.py status` | pending |
| G2 | The built Info.plist has NSCameraUsageDescription, NSFaceIDUsageDescription, NSCalendarsWriteOnlyAccessUsageDescription, NSMicrophoneUsageDescription and NSSpeechRecognitionUsageDescription | `plutil -p` on the archive's Info.plist (release) | pending |
| G3 | Release build: no Debug screen, no debug switch, no launch arguments | `#if DEBUG` in Destinations, PublicSettingsView, PublicShell (checked at 11:30 on dev) | pending |
| G4 | Cold launch with no network: the agenda and My day show content within 10 s; no spinner forever and no raw error text | release, on a simulator in airplane mode | pending |
| G5 | Full CI run green on iPhone and iPad for this commit | the run's link | pending |
| G6 | Ask: a working demo key in the notes, **or** Ask is absent from the Release build (B1) | the screen list in the build, plus the secret set | pending |
| G7 | Vault: absent, **or** a working demo key (B2) | as above | pending |
| G8 | No "Web Summit" on any screen that screenshots show (B3), and no `ShortcutWebSummit` or `web-summit.sgit.ai` in the public app (R1) | `git grep -i "web summit"` in PTAgenda AgendaView, plus the screenshots themselves | pending |
| G9 | The Settings footer shows the non-affiliation note | the `pt.notAffiliated` screenshot or UI test | pending |

## Metadata

| # | Check | State |
| --- | --- | --- |
| M1 | Name "PrompTugal: Lisbon Summit"; subtitle, keywords and promotional text match [listing-en.md](listing-en.md), [listing-pt-PT.md](listing-pt-PT.md) and [listing-pt-BR.md](listing-pt-BR.md) | pending |
| M2 | Every line marked "only if merged" (Ask, Languages, Now, Explore) was removed unless that feature is in this build | pending |
| M3 | The pt-PT and pt-BR listings exist only if the app has those localizations. A Portuguese store page with an English-only app is allowed, but then delete the Languages line. | pending |
| M4 | Screenshots: 6.9", 6.5" and iPad 13". Native screens only, no event name or logo, no status bar with a carrier name, real content (not placeholder) | pending |
| M5 | The support, marketing and privacy URLs answer 200. The privacy page describes the public app (R3), and the support page has a contact method. | pending |
| M6 | The App Privacy answers match [app-privacy.md](app-privacy.md) for this build (with or without Ask), and agree with `PrivacyInfo.xcprivacy` | pending |
| M7 | Age rating answered as in [age-rating.md](age-rating.md) (4+). "Unrestricted web access" is No, and R1 is fixed. | pending |
| M8 | The review notes are [review-notes.md](review-notes.md), with only the paragraphs for this build. Contact name, email and phone are set. | pending |
| M9 | Price free; availability all regions; "Manually release"; Mac and Vision Pro availability unticked | pending |
| M10 | What's new and the TestFlight "what to test" texts are set in all three languages | pending |

## People

| # | Check | State |
| --- | --- | --- |
| P1 | No open finding with severity "stuck" from the persona walk-through of this build ([status/review.md](../../2026-11-08__three-apps/status/review.md)) | pending |
| P2 | The conductor's go recorded for this submission | pending |
