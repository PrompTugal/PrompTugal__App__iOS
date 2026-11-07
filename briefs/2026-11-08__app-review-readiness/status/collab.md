# Status · Collaboration and AI (App Review readiness)

> All seven items are coded with tests. Build job green for all of them (runs 203, 209, 214); the iPhone and iPad unit tests are running by hand on night/collab. Nothing decided for Dinis.

Branch: `night/collab` (merged from `origin/dev` 2bc718a, no rebase) · Last update: 14:55 UTC

## Done (pushed, with tests)

1. **R2/S2 consent before Ask sends anything** (`AI/ChatStore.swift`, `AI/AskView.swift`, `AI/AIContext.swift`, `AI/AITools.swift`)
   - A sheet before the first question names **OpenRouter** (openrouter.ai) and the **model's provider** (from the model id, e.g. Anthropic), lists each kind of context with its own switch and what it sends, and offers **Allow** / **Don't allow**.
   - The choice is stored (`ai.consent.v1`). Ask settings show it and offer "Withdraw permission" or "Ask me again". "Don't allow" is not asked again on every question; Ask shows that it is off.
   - No request is built without consent: checked in `send`, `ask` and again in `run`.
   - Context defaults to the **public agenda only** (new key `ai.context.v2`, so earlier wider choices are not carried over).
   - **Teammates' plans** (`where_is_everyone`) and **Current page** are separate, explicit switches, off by default.
   - Prepared prompts cannot widen what is shared; tools are offered and run only for switched-on data.
   - Tests: no request without consent (an injected `HTTPLog` stays empty), decline is stored and not re-asked, withdraw goes back to asking, default context is `[.agenda]`, prompts cannot widen, tools gated, provider names.
2. **R4 report and block on Messages** (`Lanes/LaneReport.swift`, `Lanes/LanesStore.swift`, `Lanes/LanesView.swift`, `Lanes/TeamNotes.swift`)
   - **Block** a lane, or the sender of an inbox message or a teammate's note: hidden everywhere on this device, persisted, and undone in a "Blocked" section.
   - **Report…** opens a prefilled mail (subject, sender, date, the text). The address is one constant, `LaneReport.contactAddress`, empty until Dinis gives it; the mail then opens with no recipient.
   - Context menus, swipe actions and VoiceOver actions ("Report", "Block sender").
   - Tests: block persists across stores and unblocks; report URL is prefilled and header-safe; works before the address is set.
3. **Q4 crypto off the main actor**: RSA-4096 generation (`makeMyLane`) and inbox decryption (`LanesStore.decryptAll`) run in `Task.detached`; the website inbox key is imported inside that task. Test: messages open through `decryptAll`, a bad one gets a readable error.
4. **S5 key only from my own vault** (`Coordination/CollabHooks.swift`, `Coordination/CollabVaultGlue.swift`, `AI/AIKeyStore.swift`)
   - The vault seam has `ownVaultId`: the account's reader vault. An imported key (a teammate's) is never "mine".
   - `loadFromVault` reads only that vault; saving the key, sharing my plan and posting team notes write only to it, and fail with a plain message otherwise.
   - Tests with a fake vault: a teammate's vault is never read for the key; my own is.
5. **S7**
   - Links in Ask answers: tapping one shows the full URL and asks first; only `https` and `mailto` can be opened, other schemes (including `promptugal://`) only copied. Test.
   - Copy from Ask: local only (no Handoff) and expires after two minutes. Test.
   - Lane endpoints: only `https://dev.send.sgraph.ai` (no port, no user); checked when parsing, for the website inbox record, and on every request. Tests (other host, http, port, credentials, a changed address at send time).
   - Append tokens: lane addresses moved from UserDefaults to the Keychain; the old copy is migrated once and deleted. Test checks no token remains in UserDefaults.
6. **Smaller fixes**
   - `isSending` is set before the Task is created, so a double tap sends once.
   - Conversation capped at 200 turns; at most 30 sent back with a question. Test (messages builder).
   - Messages on iPad: two columns only when the window is at least 700 pt wide; one list in narrower Split View. The fixed 400 pt is gone.
   - One Lisbon-day helper: my copy is deleted and I call team's `DayPlanner.lisbonDay`.
   - One set of team models: Ask's team context and "Where is everyone"'s people list now read `TeamStore`'s `TeamPerson` and `CommandCentre` (no separate fetch or parse). Tests decode fixtures through those models.
   - Debug literals in `AskView` and `LanesView` use `DebugMode.key` / `DebugMode.defaultOn`.
7. **Readable errors (Q7)**: `CollabErrorText.short` for every error shown in `AI/`, `Lanes/` and `Coordination/`: network errors in plain words, no `Error Domain=…`, no object paths. Test.

## In progress

- Unit tests (iPhone and iPad) dispatched by hand on night/collab at 14:54 for 5afdf59. Build runs: 203 (consent, S5) green, 209 (report/block, hosts, tokens, Q4, Q7, Split View) green, 214 (one set of team models) green.
- After team is on dev: merge origin/dev and switch my three `DayPlanner.lisbonDay` calls to `Lisbon.day(_:)` (agreed with the conductor).

## Blocked

Nothing.

## Needs from others

- **Team:** please keep `DayPlanner.lisbonDay(_:)` (I now use it), or move it to `Lisbon` in `App/Content.swift` with platform and tell me. `TeamStore` still fetches with `URLSession.shared` (Q8); my team context now goes through `TeamStore`, so routing it through `HTTPClient` will put those requests in Debug → Network too.
- **Vault:** my `ownVaultId` treats the reader vault (by `readerVaultId` or role "reader") as mine and "imported" as never mine. If your S5 fix adds an explicit "mine" marker for a pasted own key, tell me and I will use it.
- **Design:** `DebugMode.defaultOn` false in Release is yours; my views follow it.

## For Dinis

- **Contact address** for reports: set `LaneReport.contactAddress` (one line) once decided (pack decision 3).
