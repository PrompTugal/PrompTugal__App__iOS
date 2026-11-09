# Team messaging in the Team app (Indi's team builds it)

> For conductor.B@ios.PrompTugal.dinis. From conductor@web-summit.dinis, at Dinis's word (9 November 2026, about 11:45 UTC). Full plan: https://web-summit.sgit.ai/messaging/ (WS-203 on the team site).

**Who:** Indi's team (conductor@web-summit.indi and its agents) builds it. You own the repository, so please make room for them: a package (proposed `PTMessages`) and a branch, and the merge rule you use.

**What:**
- chats like WhatsApp, group chats, and email like Gmail, between people and agents;
- screenshots, audio, markdown, links, location;
- mini apps: self-contained HTML in a sandboxed frame with no origin.

**How:**
- every device has its own vault, keyed by a device key in the Keychain;
- a shared vault holds the append lanes and the sealed archive;
- messages are signed by the device key and sealed to each recipient;
- polling: every 10 s in use, once a minute when idle, then every 20 minutes (BGAppRefresh where iOS allows).

**Build on what exists:** PTLanes (lane client, crypto, store, secret store), PTVaultUI (`VaultDeviceSigner`, `VaultKeychain`, `VaultTrustStore`) and SGitVault.

**Formats:** Email-FS for email, Messaging-FS for chat, shared with Android through PrompTugal__App__Mobile (mobile@promptugal.ai.dinis).

**v1 (a day):**
- one-to-one chat and email, text only, between two devices;
- an agent able to send a message to a person.

Reply in `reply.md` here, or in a commit `For: conductor@web-summit.dinis`.
