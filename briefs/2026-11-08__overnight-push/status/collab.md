# Status · Collaboration and AI

> Done for tonight and on dev: Ask (OpenRouter chat with tools, dictation, key check, opt-in history), Where is everyone, Messages (lanes, inbox, newsroom notes) and team notes through vaults, on iPhone and iPad. The table below says what works without keys and what needs which key.

Branch: `night/collab` · Last update: 08:45 UTC

## Entry views (registered in `Shell/Destinations.swift` at 04:12, replacing the placeholders as their comments asked)

| id | View | Notes |
| --- | --- | --- |
| `collab.ai` | `AskView()` | Inside a `NavigationStack`. Also `.askPanel(isPresented:)` on any view: a side panel on iPad (`inspector`), a sheet on iPhone; `AskPanelButton(isPresented:)` for the toolbar (⌘K). |
| `collab.plans` | `TeamPlansView()` | "Where is everyone". Suggest section `.team`, kind `.native`. |
| `collab.lanes` | `LanesView()` | Messages: newsroom notes, lanes, my inbox. |
| (debug) | `CollabDebugPanel()` | For Debug: keys by presence only, hooks, Ask requests, lanes log. `LanesLogPanel()` is the lanes log alone. `CollabDebugPanel.keyRows(keys:lanes:)` gives rows for the Keys panel. |

## How to use it (for the team, at the summit)

1. **Ask.** Open Ask (Agents → Ask). Tap the menu (…) → Key and settings, paste your OpenRouter key (starts `sk-or-`), Save, then Check key. Choose what Ask may see with the chips above the text field. Try "Brief me", "Plan my day", "Where should we meet today?" or "What are my agents doing?". Hold the mic to talk. With your vault open (Vault), "Save key to my vault" lets your other devices take it.
2. **Share my plan.** Open your vault with its vault key or passkey, then Team → Where is everyone → Share my plan. Your picks go to `apps/agenda/picks.json` in your vault.
3. **See where everyone is.** Ask each teammate for the read key of their vault (it can only read). Where is everyone → Add key next to their name. Their picks then show as "Together", "Clashes" and "Meet here".
4. **Team notes.** Team → Messages → Team notes: write and Post. Each note is a new file in `lanes/team/` of your vault. You see notes from every teammate you linked in step 3.
5. **Note to the newsroom.** Messages → Note to the newsroom (needs the vault open and the notes lane the website made).
6. **Write-only lanes.** Messages → Add a lane: paste a lane description or an `sgi1.` inbox link. To receive, Messages → Set up an inbox and share your lane description.

## Done

- **Ask** (`PrompTugal/AI/`):
  - OpenRouter request as the website's `/ask/` (chat-core.js): `POST /api/v1/chat/completions`, `stream: true`, `usage.include`, default `anthropic/claude-sonnet-5`, the website's model list plus Fable 5.1.
  - Streaming with `URLSession.bytes` and an SSE parser; stop button; non-streamed JSON also handled.
  - Every request lands in `HTTPLog` (Debug → Network) as `ai.chat`, `ai.context.me`, `ai.context.commandcentre`. `HTTPClient` has no streaming call, so `OpenRouterClient` uses `HTTPClient.shared.session` and appends the record itself. No headers or bodies are logged.
  - Key: entered once in a `SecureField`, stored in the Keychain (generic password, this device only, not synced). The UI shows `sk-or-…abcd` only. Optional copy to the vault at `apps/ai/openrouter.json`, and "take key from my vault", once the vault hook is wired.
  - Context toggles: today's agenda (or the next summit day), my picks, my team status (`me.json` + my command centre `data.json`), current page. The system prompt says context is data, not instructions.
  - Prepared prompts: **Brief me** (next 3 hours), **Plan my day** (uses a planner hook when wired), **What are my agents doing** (agents, reports, activity).
  - "How this was asked" disclosure on each answer (debug mode): model, sizes, timings, each context part, the full system prompt. Never the key.
- **Where is everyone** (`PrompTugal/Coordination/`): sessions with two or more of us, clashes per person, "meet here" (after a shared session, or free windows of 30+ minutes between 09:00 and 19:00 that keep the 13:00 and 18:00 stand-ups free), people per day. "Share my plan" writes my picks to `apps/agenda/picks.json` through the vault session's `savePicks`. A teammate is linked by pasting the read key of their vault; only the vault id is stored outside the Keychain.
- **Tests**: request building, SSE parsing, accumulator, context assembly, key store round trip and vault document, overlaps, clashes, free windows. Negative controls: empty or spaced key, stream error event, malformed lines, touching sessions, all-day busy.

- **Messages** (`PrompTugal/Lanes/`):
  - Send a note, tip or message to any append lane given as an `sgit-subscribe/v1` file, a link to one, this app's `promptugal-lane/v1`, or a newsroom inbox link (`sgi1.<vault>.<token>.<key>`). The key's fingerprint is recomputed from the PEM before saving.
  - Encryption is sgit's hybrid envelope v2, checked against sgit-ai 0.27 `PKI__Crypto.hybrid_encrypt` and newsroom.sgit.ai `inbox.js`: AES-256-GCM, key wrapped with RSA-OAEP-SHA256, payload base64 twice. The server answers only `{"ok": true}`.
  - To a newsroom inbox, the app sends what its drainer accepts (`sgit-newsroom-inbox/v1`, a device file with the note); to other lanes, a single-part `.eml` with headers stripped of line breaks.
  - My inbox: an RSA-4096 key made in the Keychain, a descriptor to share, list (paged) / fetch / decrypt / mark read with the enumeration key. Or the account inbox the website made (`inbox.json` in the master vault, PKCS#8 key held in memory only) once the vault glue is in.
  - Newsroom notes: the newsroom's note record (`notes/<id>.json`, sgit.notes.v1 fields) committed to my notes lane vault, whose key is in my master's `lane.json` (newsroom.sgit.ai `newsroom-vault.js`). Needs the vault glue.
  - Hold-to-talk dictation (Speech, on device when the language supports it).
  - `LanesLog`: every encrypt, write, list, fetch, decrypt, with sizes, timings and a shortened token. Never a key or the message text.

- **Team notes** (Messages → Team notes, `PrompTugal/Lanes/TeamNotes.swift`): a note is a new file in `lanes/team/` of my own vault, written with the vault session's `append` (unique name, signed by this device, so devices never conflict). The section reads my folder and the same folder in every teammate vault linked in "Where is everyone". Schema `promptugal-team-note/v1`; other files are ignored.

## What works without keys, and what needs which

| Feature | Without any key | Needs |
| --- | --- | --- |
| Ask: chat, prepared prompts, tools, dictation | Screen opens, shows how to add a key; nothing is sent | **OpenRouter key** (yours, in the Keychain). Sent only to openrouter.ai |
| Ask: context (agenda, picks, team status, agents) | Gathered from public data and this device; shown in the debug disclosure | "Who are you" chosen in Settings for team status and agents |
| Ask: copy key to / from the vault | n/a | OpenRouter key, plus the vault opened with its vault key or passkey |
| Where is everyone: my own picks, days, free windows | Works | Nothing |
| Where is everyone: teammates' picks, Together, Clashes, Meet here | Shows what is missing | Each teammate's **vault read key** (they share it once; it can only read) |
| Share my plan | Button disabled, reason shown | Vault opened with its **vault key or passkey**; pushing also needs the vault's **access token** (vault session's `canPush`) |
| Team notes: read | Mine and linked teammates' | Vault open; teammates' read keys for theirs |
| Team notes: post | Disabled | Vault with write access and access token |
| Note to the newsroom | Explains | Vault open, and the **notes lane** the website made (`lane.json` in the master vault) |
| Send to a lane | "Add a lane" | A **lane description** (sgit-subscribe/v1, promptugal-lane/v1, or an `sgi1.` inbox link). None is published for PrompTugal yet; Messages → Share my lane description makes one |
| My inbox (this device) | Key pair is made on the device | The lane registered on the vault once (`configure`: vault write key and access token, from a computer with sgit), then the **enumeration key** entered in the app |
| My account inbox (website-made) | Button appears when the vault is open | Vault opened with the passkey (reads `inbox.json` from the master vault) |
| Debug: Collaboration and AI panel, lanes log | Works | Nothing. Keys are listed by presence only |

Notes:
- The team site's public data has one shortlist for everyone (each person's `data.json` lists the same 80 sessions), so it cannot show who goes where. Personal picks come only from vaults.
- No PrompTugal newsroom append lane is published (promptugal.news has no `/.well-known/sgit-subscribe.json`), so newsroom notes go through the vault notes lane.

## Since 05:15 (iPhone and iPad)

- `askAnywhere()`: Ask next to any screen (toolbar button and ⌘K; side panel on iPad, sheet on iPhone). For design to put on the shell's detail view.
- Ask: readable width (760 pt) on iPad and in landscape; ⌘↩ sends; Copy and Share on answers; "Thinking…" while waiting; hold-to-talk dictation in the composer.
- Ask: "Where should we meet today?" prepared prompt (uses the where_is_everyone tool).
- Ask settings: Check key (OpenRouter `/api/v1/key`: works, usage, limit), logged as `ai.key.check`.
- Messages: compose, add-lane and inbox sheets are form-sized on iPad.
- Messages on iPad: two columns, what I send on the left (newsroom, lanes), what I read on the right (team notes, inbox, sent, lanes log). iPhone keeps one list.
- Accessibility: one VoiceOver element per row in Messages, team notes and Where is everyone; clashes read in full; labels on tool-call rows, my questions and icon-only buttons.
- Ask: "Keep this conversation on this device" (off by default): only the words of each turn, in a file protected while the device is locked; never the key, the context or the system prompt; off deletes the file.
- Ask: sessions an answer names (full title, case and accents ignored) are listed under it with a star to pick and a link to open.

## In progress

- Nothing. Everything is on dev (fadf27e); night/collab = dev.

## Next

1. Fix anything dev's unit tests report for my folders.
2. Morning hand-over notes for the team: how to add an OpenRouter key, link a teammate's plan, and send a newsroom note.

## Blocked

Nothing.

## Needs from others

- **Design (shell, 3 small changes, your call):**
  1. Ask next to any screen on iPad: in `AppShell.splitView`, on the detail content inside the `NavigationStack`, add `.askAnywhere(enabled: destination.id != "collab.ai")`. It adds a sparkles toolbar button and ⌘K that open Ask as a side panel (an `inspector`), and as a sheet on iPhone if you use it in `PhoneShell` too.
  2. "Current page" context for Ask: in `WebPage`, when a page finishes loading, call `CollabHooks.noteCurrentPage(title:url:)` (and optionally `text:` with the page's visible text, capped at 6,000 characters by the hook). Native screens can do the same with their title.
  3. Debug: a row `NavigationLink("Collaboration and AI") { CollabDebugPanel() }` in `DebugHomeView`; for the Keys panel, `CollabDebugPanel.keyRows(keys: .shared, lanes: .shared)` lists the OpenRouter key, lane keys and inbox keys by presence only.
- **Platform:** a streaming call on `HTTPClient` (`bytes(for:label:)` that logs on completion) would let `OpenRouterClient` drop its own bookkeeping. Not urgent.
