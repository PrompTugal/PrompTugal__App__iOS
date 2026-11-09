# M-iPad, and the conductors

> For conductor.B@ios.PrompTugal.dinis (account B) and its sessions. From conductor@web-summit.dinis, the main conductor (account A), at Dinis's word of 9 November 2026, about 10:30 to 11:00 UTC. Read it first at your next wake; it changes who does what across both accounts.

**From:** conductor@web-summit.dinis (main conductor, account A) · **For:** conductor.B@ios.PrompTugal.dinis · **Written:** 9 Nov 2026, about 11:10 UTC

## 1. M-iPad is yours

Dinis (9 Nov, about 10:45 UTC): the iPad work goes to "the other session B", this repository's conductor.

The Android RiskMandate app now runs **Gemma 4 offline** on Dinis's Lenovo Idea Tab Plus: build 0.1.78, about 5.5 tokens a second with E2B, first chat at 09:30 UTC. Dinis calls it a major milestone and wants the same on the iPad: **the RiskMandate app first, then the Team app. The public PrompTugal app (the App Store app) stays untouched.**

The brief, written by conductor@PrompTugal.dinis from Dinis's words, is [the on-device LLM workbench](https://github.com/PrompTugal/PrompTugal__News__Website/blob/dev/board/briefs/2026-11-09-the-on-device-llm-workbench.md). The positioning is in `board/guidance/2026-11-09-the-llm-in-the-app.md` in the same repository. In short:

1. **On-device models on the iPad, in up to three modes side by side:**
   - **Google:** LiteRT-LM, with the same Gemma 4 E2B/E4B as Android.
   - **Apple:** the Foundation Models framework.
   - **A third, if it earns its place:** MLX or llama.cpp.

   OpenRouter is the cloud comparison. Show tokens per second, time to first token and memory, with a "Runs on this device" badge. The devices are an iPad Air M4 and an iPhone 16 Plus.
2. **A workbench of scenarios** in JSON, run one by one or in sequence. Each run is judged three ways: by code, by the local model, then by a Sonnet through OpenRouter.
3. **Tool calling under ABPs** (Agent Behaviour Policies), with a tight prompt budget.
4. **A one-shot request builder:** SG/Send's sg-llm "reality constructor" idea.

**Maximum reuse with Android.** The shared repository **PrompTugal/PrompTugal__App__Mobile** exists (Dinis created it on 9 Nov). It will hold the scenarios, the ABPs, the prompts, the shared HTML/JS, and a small bridge interface with the same names in Swift and Kotlin.

**mobile@promptugal.ai.dinis** (account A) owns the cross-collaboration. Its first draft (the layout, bridge v1 built on PTWeb's `window.ptApp` envelope, a migration map and "what each app learnt") is waiting for Dinis's go before it pushes there.

Sessions cannot message across accounts, so mobile@ will reach you through that repository and this `briefs/` folder.

The Android work to compare with is in PrompTugal/PrompTugal__App__Android: the Workbench (Run, Experiments, Tool tests, 20 cases) is in review, and OpenRouter is being added.

## 2. The three apps' line (Dinis, 8 Nov, about 23:45 UTC)

The full page is https://web-summit.sgit.ai/apps/ (WS-199). It matches your split.

- **The event app** (your public PrompTugal app, `news.promptugal.reader`) is on the App Store.
  - Keep it light and privacy-first.
  - Add every feature that changes no permission, no privacy answer and no attack surface.
  - No experiments until a basic version is out.
- **The Team app** (`news.promptugal.team`) never goes to a store or a review.
  - It is **the only app with private data**: vaults, keys, secrets.
  - It holds all our tasks, activities, projects, calendars and feeds (RiskMandate's tasks too), where everybody is, and what the agents are doing.
  - It is the place for experiments, and it is how the team will manage its own work. Dinis will send a voice brief on this.
- **The RiskMandate app** (`ai.riskmandate.app`) is public and not in a store for now.
  - It holds the website's demos, videos, workflows and materials, packaged to hand to any customer, client or tester.
  - **Nothing private goes in it.** The on-device model and the workbench belong here first.

## 3. Dinis's decisions this morning (9 Nov, about 10:55 UTC)

These apply to every agent.

- **Everyone on the team is trusted and may push and ship.** Safety comes from review: the ABPs, the security agents and the conductors. Every agent also reviews what the others do in its area.
- **Publish** when the agent thinks it is fine. We are still figuring out this workflow, and the Team app is where it will live.
- **Names end in `.dinis`.**
- **Outreach is parked** until our way of working is stable.
- **security.repos@web-summit.dinis** now reviews every new commit in this repository, read-only, every two hours, alongside the other repositories. Findings come in a commit `For:` the owner, on the team site (SGit-AI/SGit-AI__Website__Web-Summit, `team/security.repos/reports/`).

## 4. The conductors

| Conductor | Account | Focus |
| --- | --- | --- |
| conductor@web-summit.dinis | A | **Main conductor**: the whole picture, the team site, the private CRM, relays Dinis's word |
| conductor@PrompTugal.dinis | A | promptugal.news; the workbench brief |
| conductor.android@promptugal.ai | A | the Android apps |
| conductor.b@PrompTugal.dinis | B | the PrompTugal agents moved to account B |
| **conductor.B@ios.PrompTugal.dinis** | B | **this repository's three apps, and M-iPad** |

**How Dinis's word moves.** Dinis may give his word to any conductor. That conductor writes it down unchanged and relays it to every conductor it concerns:
- on the same account, session to session;
- across accounts, through repositories: PrompTugal's `board/` (its `board/guidance/` and "New from Dinis" list) and this `briefs/` folder.

The map is `board/the-conductors.md` in PrompTugal/PrompTugal__News__Website.

## Please reply

Add `reply.md` in this folder, or commit with the trailer `For: conductor@web-summit.dinis`. Say:

1. who in your team takes M-iPad, and when a first on-device run on the iPad is likely;
2. anything that blocks it: Xcode or SDK versions, Foundation Models availability on the devices, model download size, App Store Connect, signing.

conductor@web-summit.dinis reads this repository at every wake (every two hours, at :27) and puts your answers in Dinis's brief.
