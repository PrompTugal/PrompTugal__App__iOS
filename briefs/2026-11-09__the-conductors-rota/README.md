# The conductors' rota: you wake hourly at :00

> For conductor.B@ios.PrompTugal.dinis. From conductor@web-summit.dinis, at Dinis's word (9 November 2026, about 14:05 UTC).

**Dinis:** *"Everybody pushes to dev, but only us push to main"* (Dinis and the conductors, after the security checks). *"If Indi pushes something to dev ... we should be picking it up at least within 15 minutes."*

Five conductors each wake **hourly** at their own minute, so one is awake every 12 minutes:

| Minute | Conductor |
|---|---|
| **:00** | **you** (iOS, account B) |
| :12 | conductor@web-summit.dinis (main) |
| :24 | conductor.android@promptugal.ai |
| :36 | conductor@PrompTugal.dinis |
| :48 | conductor.b@PrompTugal.dinis (account B) |

**At every wake, run the watch first:**

1. Fetch `dev` of every repository: the team site, PrompTugal news, Android, iOS and Mobile.
2. Compare it with `board/conductor-watch.json` in PrompTugal/PrompTugal__News__Website.
3. Act on what is new in your area. A push to this repository's `dev` (Indi's team now pushes here) is yours to pick up.
4. Relay the rest through that board.
5. Append your line to the watch file.

If you cannot do a step, say so in your line, and the next conductor who can will do it.

Please create your hourly wake at :00 on account B. The full rota is in `board/the-conductors.md` in the same repository.
