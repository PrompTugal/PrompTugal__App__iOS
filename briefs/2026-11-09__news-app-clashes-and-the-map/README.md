# The news app: busy and free events, clashes you can see, the venue map, and "where I need to be"

> For conductor.B@ios.PrompTugal.dinis. Dinis tried the public news app (`news.promptugal.reader`) on 9 November 2026, about 14:30 UTC, and reported this to conductor@web-summit.dinis. He was pleased: *"it's actually really cool, really great, the new features"*, and **Add to Calendar "worked really, really well."** These are the first real bugs from using it.

## Bug 1: clashes are hard to find

*"I had to hunt down on the schedule where the clash was."*

- **Fix:** show the clash where it is. Mark both sessions in the day view (a red edge, or overlapping bars side by side) with "clashes with <session>, 10:30 to 10:45", and put a tap-to-jump list of clashes at the top of the day.
- **Code:** `Packages/PTAgenda/Sources/PTAgenda/Schedule/DayPlanner.swift` (`Clash`, with overlap and travel) and `MyProgramView.swift`.

## Bug 2: not every pick should make you busy

Dinis picked **Registration** (to keep it in his pipeline) and an all-evening **start-of-the-show** event (about 18:00 to 20:00). As soon as he picked a session inside that window, he got a clash.

- **Fix:** borrow the calendar's idea: an event is either **busy** or **free** (a reference: *"I'm in Portugal this week" doesn't mean I'm busy for the whole week*).
- **Default free:** registration, opening nights, all-day or multi-hour "presence" events, venue opening hours.
- **Default busy:** talks, panels, workshops and meetings.
- **The person can toggle it** on any pick. Only busy against busy is a clash.

## Feature: allow two sessions at once, on purpose

*"I might want to go to two sessions ... to be able to go from one session to the other."*

- Let the person mark a clash as **"I'll split my time"**. It stays visible as a planned overlap, not as an error.
- The planner then shows when to leave the first session to catch the second, using the walking time it already computes.

## Feature: the venue map and "where I need to be"

- **A map of the venue,** with each pick placed on it.
- **"Where I need to be"** in the next 10 and 20 minutes, with the walk between them.
- **Reuse:** Angelo's venue drawing, from OpenStreetMap outlines under the ODbL licence. It is in the team site's `people/angelo/app/venue-map.js` and the spec `people/angelo/proposals/WS-181/spec-venues.md`. PrompTugal.news's venues work (WS-181 part B) is the public version.

## The question: location in the news app?

Dinis: *"If we add [location] only while using the app, is that going to make it more complicated to get approved? If not, I think it makes sense on that app to have it."*

The main conductor's view, for you to confirm against App Review:

- **"While using the app" location** (`NSLocationWhenInUseUsageDescription`, ideally **approximate** precision unless the person allows precise) is routine. Apple reviews it like any update. It is not a special entitlement.
- **The privacy label can stay "Data Not Collected"** if the location **never leaves the device**: it is used only to draw "you are here" and the path. Sending it anywhere changes the label and the privacy page.
- **The risk is timing.** Do not add it to the build in review. Add it in the next update, behind a clear explanation, off until the person taps "show me on the map".
- **The three apps' line said** no new permission in the news app. Dinis is now open to this one exception, on-device and while in use. If App Review makes it hard, it goes to the Team app, which needs location anyway (with history, and the team's whereabouts).

## Please

Fix bugs 1 and 2 first: they are small, and people are picking sessions from tonight. Then the split-my-time option. Then the map, with your answer on location. Reply `For: conductor@web-summit.dinis`.

## Update, 14:25 UTC: the data side

From conductor@PrompTugal.dinis:

- **`shows_as` is coming.** ontologist@ (account B) is adding `"shows_as": "free" | "busy"` to the event schema. It defaults to busy, and is free for presence events (registration, opening nights, all-day or multi-hour events, venue hours). It will be derived for all 249 events and published in PrompTugal.news's events JSON. Read it when it appears, and fall back to your own rule until then.
- **Places are already data.** Each event has `"place"` (for example `"place:masterclass-1"`) and `"where"` (for example `"Masterclass 1 (Masterclasses), MEO Arena and FIL"`). The map can use them now.

## Update, 14:45 UTC: the same app on the web

Dinis wants the news app on promptugal.news as a web app too, because App Store and TestFlight review is too slow. It would sit in a phone-shaped pane beside the news, be resizable to iPad size, be installable to the home screen, and include a beta list. PrompTugal's team builds it: `board/briefs/2026-11-09-the-app-on-the-web.md` in PrompTugal/PrompTugal__News__Website.

The schedule rules (busy and free, clashes with walking time, split my time, .ics) go into PrompTugal__App__Mobile as one reference that web, iOS and Android all match. Please keep `DayPlanner.swift`'s behaviour documented there.

## Update, 14:50 UTC: the shared schedule rules are ready

mobile@promptugal.ai.dinis put `formats/schedule-rules/` on PrompTugal__App__Mobile `dev` at `7433286`:

- **`rules.json`:** walking minutes, venue keywords, and the busy/free fallback.
- **`schedule-rules.mjs`:** `travelMinutes`, `showsAs`, `clashes` (busy items only, with split and leave_at), `splitKey`, and `toICS` (free picks map to `TRANSP:TRANSPARENT`).
- **`cases.json`:** shared test vectors.

Walking time and clashes match `DayPlanner.swift` at `2e0c5ac`, including Swift's Int truncation. Busy/free and split are new: **the person's toggle wins, then `shows_as`, then the fallback rule; only busy against busy is a clash.**

**Please make the iOS tests run `cases.json`**, so iOS, Android and the web give the same answers.
