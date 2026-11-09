# schedule-rules/1: busy and free, clashes with walking time, "split my time", .ics

One reference for the news app's schedule rules, matched by the web app (promptugal.news), iOS and Android.
Asked for in PrompTugal__News__Website `board/briefs/2026-11-09-the-app-on-the-web.md` ("share the rules, not
the Swift") and PrompTugal__App__iOS `briefs/2026-11-09__news-app-clashes-and-the-map/`.

| file | what |
|---|---|
| `rules.json` | the numbers and word lists (walking minutes, summit-venue keywords, the busy/free fallback) |
| `schedule-rules.mjs` | the reference implementation: plain ES module, no dependencies; the web app imports it as is |
| `cases.json` | shared test vectors; JS, Swift and Kotlin tests all run this file |
| `schedule-rules.test.mjs` | `node --test formats/schedule-rules/` |

## The rules

**Walking time** (as `DayPlanner.travelMinutes`, iOS dev 2e0c5ac): 0 if either place is empty or both are the
same (ignoring case); 5 minutes if both are in the summit venue (the name contains one of the keywords: stage,
masterclass, meetup, lounge, meo arena, fil, pitch, summit, booth, hall, pavilion); otherwise 25. These are
estimates, and the UI says so.

**Busy or free** (new; the iOS brief's bug 2): an item is busy or free, decided in this order: the person's toggle,
the event's `shows_as` (being added to the events JSON by ontologist@), then a fallback: free if the title names
registration, an opening night, the start of the show, doors or venue hours, or all day, or if it lasts 3 hours or
more; busy otherwise. **Only busy against busy is a clash.**

**Clashes** (as `DayPlanner.clashes`, on busy items only): items sorted by start, then id. For each later item b
that starts before a's end plus the walk from a to b: if they overlap, a clash of that many minutes; if not, a
"travel" clash of the minutes short of the walk. Minutes are truncated as Swift's `Int()` does. A missing end is
start + 30 minutes.

**Split my time** (new): the person can mark a clash with `splitKey(a, b)` (the two ids sorted, joined by `|`).
It stays listed with `split: true`, as a planned overlap and not an error, with `leave_at`: the second item's
start minus the walk, when to leave the first.

**.ics**: one VCALENDAR per pick or for the whole programme; UTC times, CRLF, lines folded at 75 octets, text
escaped; free items are `TRANSP:TRANSPARENT` so calendars do not show the person as busy.

## Not here yet

`DayPlanner.plan` (gaps and proposals) stays in Swift for now: it depends on the agenda, picks and stand-ups
models. Port it here when the web app needs the planner.

## Changing a rule

Change `rules.json`, the module and `cases.json` together, bump `version`, and tell both app teams: the iOS and
Android tests run `cases.json`, so a change shows up as a failing test there until they match.
