# PrompTugal news app redesign

> From conductor-newsapp@web-summit.indi, at Indi's and Dinis's word (10 November 2026, about 12:00 UTC). For: conductor@ios.PrompTugal.dinis, devops.ios@web-summit.dinis, conductor@web-summit.dinis, indi.

The app is good but still clunky. This redesign cuts the taps to the things people do most, keeps the look (paper, ink, red, the serif headlines) and fixes the places where one talk looks different depending on where you opened it.

## The workflows, taps today and after

Counted on iPhone from a cold launch on Now. A tap that only scrolls is not counted.

| # | Workflow | Today | After | How |
|---|---|---|---|---|
| 1 | See what is on now and next | 0 | 0 | Unchanged. Now stays the first screen. |
| 2 | Find a talk | 3 (Explore, search, result) | 3 | Unchanged in round 1. Round 3 adds search to Now. |
| 3 | Open a talk from Now | 1, but it opens the web page with no pick or calendar | 1, the native talk | Round 1: Now opens the same talk sheet as Explore and My program. |
| 4 | Pick a talk and add it to the phone's calendar | 3 (open, pick, Add to Calendar) | 1 (the star) | Round 2: "Also add picks to my calendar", asked once. |
| 5 | See my day | 1 (My program) | 1 | Round 3: the day as one timeline with walks and gaps. |
| 6 | Find where a talk is | 3 plus a long scroll (Now, scroll to Practical, Venue map, find the hall) | 2 (open the talk, Show on the map) | Round 1: Map is a tab; the talk has "Show on the map". |
| 7 | Read the news | 2 (News, story) | 2 | Round 3: reading time and the story's talk linked. |
| 8 | Meet RiskMandate at the stand | not in the app | 2 (More, Meet RiskMandate) | Round 4, with the line Dinis approved for the stand. |
| 9 | Settings and reminders | 1 on two tabs, missing on the other two | 1 on every tab | Round 1: the round More button on every tab opens a sheet. |

## The screens and the order

1. **Round 1, navigation.** Five tabs on iPhone: Now, My program, Explore, Map, News (from the Team app's redesign). More opens as a sheet from the round button at the top right of every tab. Now opens the native talk. The talk sheet gets "Show on the map". The iPad sidebar keeps the same five, then More.
2. **Round 2, pick and calendar in one tap.** The first star asks once whether picks should go to the phone's calendar too; after that the star does both, and unpicking removes it.
3. **Round 3, My day and the news.** My program as one timeline per day, with the walk between halls and the free time; search on Now; reading time on stories.
4. **Round 4, RiskMandate at the stand.** A card in More and on Thursday's Now: where and when, and the public meet page.
5. **Round 5, words and type.** Every string read again: no em-dashes, no filler, British spelling, text at least 15 points, tap targets at least 44 points.

Each round: the change, its unit and UI tests, Screens for iPhone and iPad, and the taps saved, then merged to dev. A round that a beta user would notice goes to the external group through `testflight-ops.yml` (set-whats-new, submit-beta-review, add-to-group), as the brief `2026-11-10__beta-users-and-one-story` asks.

## The look

Unchanged: Palette.paper, ink, red, muted and amber, the serif display face, the cards. No new colour in rounds 1 to 4.

## Reviews

- security.repos@web-summit.dinis: rounds 2 (calendar access) and 4 (an outside link).
- The web version on pt.news is told of each round in PrompTugal__News__Website `board/team/` through a commit For: its owner.
