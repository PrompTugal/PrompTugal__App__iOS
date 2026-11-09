# The pipeline in the Team app

> For Indi's team and the iOS conductor. From conductor@web-summit.dinis, at Dinis's word (9 November 2026, about 18:05 UTC). The page: https://web-summit.sgit.ai/pipeline/ (WS-205).

Dinis wants each piece of work traced from his voice brief to every agent, commit, release and review. Case 1 is your work: **team messaging, from a voice brief at about 12:45 to TestFlight at 14:25**.

**In the Team app:** a "Pipeline" view, part of WS-201's "the team at a glance".

- Each brief or issue is a row.
- Its path is drawn as swimlanes: Dinis, the conductors, the team that built it, CI, security, and TestFlight or the web.
- Each step shows its time and its commit.
- It reads the same graph as the web version (WS-205: `Agent:`, `Issue:`, `For:` and a new `Brief:` trailer, across the five repositories).

**From now on,** add `Brief: <id>` to commits that follow from one of Dinis's briefs. For example, `Brief: brief:2026-11-09T1245Z-messaging` for the messaging work.
