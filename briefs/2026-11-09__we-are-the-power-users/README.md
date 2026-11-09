# We are the power users: the Team app runs our own summit first

> For conductor.B@ios.PrompTugal.dinis and its sessions. Dinis's voice brief of 9 November 2026 (about 11:10 UTC), relayed by conductor@web-summit.dinis, the main conductor. Board issue: WS-201 on the team site.

**Full text:** https://web-summit.sgit.ai/power-users/ (WS-201) · **Follows:** the three apps' line, https://web-summit.sgit.ai/apps/ (WS-199)

**Names:** "the Team app" is the private app (`news.promptugal.team`). "The news app" is the public one on the App Store (`news.promptugal.reader`).

## Why

Dinis: *"We already have a problem of management ... we don't know which sessions we're going to go. We don't know where everybody is ... We are a team of 6. Imagine teams of 10, 20, 50, 100 ... if we make it work for ourselves, it will work for others, and that's kind of what we're going to sell."*

We dogfood our own apps. **The Team app, the RiskMandate app (this repository) and the Android RiskMandate app are where we experiment as much as possible.** Anything that helps the team coordinate is fair game. The news app stays light.

## The first feature: where is everybody

*"Ridiculously powerful."* Like Snapchat's map of friends, built from change control, location, vaults and our devices:

- a live, collaborative map of the team;
- **back in time and forward:** where each person has been, and where they are going next (their sessions);
- who is seeing what, and who is going where;
- animations, infographics and maps.

**Start from what exists:** WS-181 on the team site (Angelo, approved 7 Nov). It has the specs in `people/angelo/proposals/WS-181/`:

- eight zones;
- an exact pin only by a person's choice, nothing shared by default;
- a summit-only private vault, deleted by 14 Nov;
- a security review before any real location is stored;
- a demo with no real data first.

The Team app adds phone location, the vault sync and the history. Your PTVaultUI, SGitVault and PTLanes packages are the natural base.

## The model

- **A team is a person, plus a conductor, plus agents.** Each team has its own lane, and any agent may push to its team's lane.
- **Each person gets their own customised version of the app.** Use **feature toggles** and change management, with many variants live at once, some wired on and some off. *"A Darwinian evolution"*, decided by use and votes.
- **"Make a decision, coordinate here, map that out" are core primitives.** Decisions, votes and management live in the app.

## First features (proposed; your call on order)

1. Where is everybody, live (from WS-181).
2. My summit plan: each person's sessions, on the same map.
3. Make a decision: a question, its options, votes, the result.
4. Feature toggles per person.
5. The team at a glance: each person, their conductor and agents, and today's work.

## Ask

Experiment, and propose. Everyone on the team will be asking for features. Reply in `reply.md` here, or in a commit `For: conductor@web-summit.dinis`: say what you take, and what blocks it.
