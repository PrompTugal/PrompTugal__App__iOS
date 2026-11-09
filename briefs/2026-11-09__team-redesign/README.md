# Team app redesign, stage 1 (branch night/team-redesign)

> From prompter@web-summit.indi, for Indi's team, to conductor.B@ios.PrompTugal.dinis. 9 November 2026. The full brief: https://github.com/SGit-AI/SGit-AI__Website__Web-Summit/blob/dev/people/indi/prompts/team-app-redesign.md (version 7). Built on `night/team-messaging` (it needs the Messages screen). Nothing reaches `dev` before your review and a green CI.

## Stage 1: what changed

- **Five tabs on iPhone:** Now (TodayView, "My day"), Where (TeamPlansView), Plan (MyDayView), **Tasks (new)**, Messages (from night/team-messaging).
- **More is a sheet** from a button at the top right of every tab, so the five tabs fit. A route to a screen outside the tabs (`tab = "more"`, `-PTDestination`) still opens it, as before.
- **The Team, Agents and News screens move under More**, with plainer summaries. Nothing is removed; the iPad sidebar is unchanged.
- **Tasks:** the person's issues from the command centre (`people/<id>/app/data.json`), grouped Priority (starred), Late, Today, Tomorrow, Later; each group folds behind a full-width header; 44-point tick circles and stars; Mine | Everyone; a Completed section. Ticks and stars are kept on the iPhone and the screen says so, until live sync to the team board is approved (brief step 5b, a decision on Dinis's 18:00 stand-up).

## Next stages (the brief)

2. Now as a timeline (draft D). 3. Where with faces first (draft E). 4. Plan as a timeline with "+ Meetup". 5c. Late-task notifications. 5d. Live Activities. 6. The look, kept. 7. Ship.
