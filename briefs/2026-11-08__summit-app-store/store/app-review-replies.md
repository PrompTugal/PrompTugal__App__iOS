# Replies ready for App Review

> If App Review writes back about 0.4.24 (205), start from the matching reply below, and adjust it to their exact words. Each reply names the fix, if one is needed, and who makes it. Send replies in App Store Connect → App Review → Messages (Resolution Center). Keep them short, factual and polite. Never argue, and never promise a feature that is not in the build.

## 5.2.1 / 5.2.2: the event's name or content

**Likely wording:** "Your app includes content or features from a third party, Web Summit, without authorization."

**Reply:**
> PrompTugal is an independent news app made by PrompTugal.news, a newsroom covering the technology scene in Portugal. It is not affiliated with, endorsed by or sponsored by Web Summit, and says so in Settings > About. The app name, icon, subtitle, keywords and screenshots do not use the event's name or marks. The program shown in the app is the event's public schedule, which our newsroom republishes on promptugal.news as part of our coverage, with each session linking to its page on our site. The event's name appears only inside that program, in session titles written by the organisers, as factual references.

**Fix if they insist:** filter the event's name out of displayed titles in the app (ScreenshotFilter-style, but in Release), or ask the organisers for written permission and attach it. Owner: team (PTAgenda) for a filter; Dinis for permission.

## 4.2: minimum functionality ("just a website")

**Reply:**
> Every main screen is native and works offline: Now (what is on now and next, and your next pick), My program (your picks in time order, with clashes and free time, reminders, and Add to Calendar), Explore (search across talks, speakers, companies and places, plus a native graph), and News. The app also has a Home Screen widget and Siri shortcuts ("What's next in PrompTugal"). Web pages open only for a session's full page on our own site, and links to other sites open in Safari.

**Fix:** none expected.

## 2.1: performance (empty screens, crash, cannot test)

**Likely cause:** the reviewer's network, or the feeds being unreachable from Apple's network.

**Reply:**
> The full program is built into the app, so Now, Explore and My program show content even with no network; news needs a connection the first time. Could you share the device, the iOS version and the screen where it happened? We will fix it right away.

**Fix:** check `https://promptugal.news/api/v1/live/agenda.json` and the feed URLs from outside; check the crash logs Apple attaches. Owner: platform, collab.

## 5.1.1: permissions (microphone, speech, camera, Face ID)

**Likely wording:** "Your app's Info.plist contains purpose strings for features we could not find."

**Reply:**
> The App Store build asks for notifications (when you turn on reminders or pick your first talk) and write-only calendar access (Add to Calendar). The microphone, speech recognition, camera and Face ID strings belong to features that are compiled into the shared code but are not available in this version: dictation in an assistant, and an encrypted personal store. The app never asks for those permissions in this version.

**Fix if they ask:** remove those four strings from the PrompTugal target, and stop linking PTAsk and PTVaultUI in Release, or keep them out of the build. Owner: apps. Allow one build and resubmit.

## 5.1.2 / App Privacy: "Data Not Collected"

**Reply:**
> The app has no account, no analytics, no advertising, no tracking and no third-party SDK. It reads public files from promptugal.news and sends nothing about the user. Picks, reminders and settings stay on the device. The privacy policy is at https://ios.app.promptugal.news/privacy.html.

**Fix:** make sure privacy.html says the assistant is not in the App Store version (editor).

## 2.3: metadata (name, screenshots)

**Possible concern:** "Lisbon Summit" read as the official app.

**Reply:**
> "PrompTugal: Lisbon Summit" describes our coverage of the technology summit in Lisbon. The description starts with "independent companion app", and ends with the non-affiliation note.

**Fix if they insist:** rename to "PrompTugal: Lisbon Tech Week" or "PrompTugal: Summit Guide" (30 characters at most), and change the four listings. Owner: review (texts), release (apply).

## Guideline 4.0 / iPad

**Reply if they find an iPad layout issue:** ask for the screen and orientation; design fixes it. The app supports all four iPad orientations and Split View.
