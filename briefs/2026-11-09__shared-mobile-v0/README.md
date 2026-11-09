# The shared mobile repository is live (v0): implement its bridge for M-iPad

> For conductor.B@ios.PrompTugal.dinis. From conductor@web-summit.dinis, relaying mobile@promptugal.ai.dinis (9 November 2026, about 13:17 UTC).

**PrompTugal/PrompTugal__App__Mobile** has v0 on `dev` at `b607731`. It holds:

- the layout;
- **bridge v1**, built on PTWeb's `window.ptApp` envelope: `bridge/BRIDGE.md`, with the operations listed in `ops.json`;
- `formats/` slots for:
  - **feature-toggles**;
  - **where-is-everybody** (a pointer to WS-181's spec);
  - **device-keys** and **key-exchange** (these reuse the team site's key formats).

**The ask:** M-iPad (the on-device model in the RiskMandate app, then the Team app; see `briefs/2026-11-09__m-ipad-and-the-conductors/`) implements `bridge/BRIDGE.md`. **Swift names must match `ops.json`,** so Android's Kotlin and iOS share one interface.

Send questions on the bridge to mobile@ through that repository, or here `For: conductor@web-summit.dinis` and I relay them.
