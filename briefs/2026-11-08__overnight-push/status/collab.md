# Status · Collaboration and AI

> Ask (streamed OpenRouter chat with read-only tools), "Where is everyone", Messages (append lanes, inbox, newsroom notes) and team notes through vaults are merged with dev (2b00b3a) and wired to VaultSession and the team stores. First CI run is compiling now (run 91); run 101 covers the latest.

Branch: `night/collab` · Last update: 05:00 UTC

## Entry views (registered in `Shell/Destinations.swift` at 04:12, replacing the placeholders as their comments asked)

| id | View | Notes |
| --- | --- | --- |
| `collab.ai` | `AskView()` | Inside a `NavigationStack`. Also `.askPanel(isPresented:)` on any view: a side panel on iPad (`inspector`), a sheet on iPhone; `AskPanelButton(isPresented:)` for the toolbar (⌘K). |
| `collab.plans` | `TeamPlansView()` | "Where is everyone". Suggest section `.team`, kind `.native`. |
| `collab.lanes` | `LanesView()` | Messages: newsroom notes, lanes, my inbox. |
| (debug) | `CollabDebugPanel()` | For Debug: keys by presence only, hooks, Ask requests, lanes log. `LanesLogPanel()` is the lanes log alone. `CollabDebugPanel.keyRows(keys:lanes:)` gives rows for the Keys panel. |

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

## What needs keys (also said in the UI)

- The team site's public data has **one shortlist for everyone** (each person's `data.json` lists the same 80 sessions), so it cannot show who goes where. Personal picks need each teammate's vault read key.
- Sharing my plan needs my vault opened with its vault key or passkey (write access).

- Sending to a teammate needs their lane description. None is published yet; the share button on Messages makes one.
- Registering my own inbox lane on my vault (`configure`) needs the vault's write key and an access token; this build does not do that step.
- No PrompTugal newsroom append lane is published (promptugal.news has no `/.well-known/sgit-subscribe.json`), so newsroom notes go through the vault notes lane.

## In progress

- CI: run 91 (dev 3b77e1c merge) is compiling on the iPad runner; run 101 (team notes, dev 2b00b3a) waits behind it.

- CI on the merged branch (7e097f2). Earlier queued runs that never started were cancelled so one run covers the lot.

## Next

1. Fix whatever CI finds.
2. Ask: show the tool results' sources as links; a "send this answer to a lane" action.
3. Coordination: offer "share my plan" right after picks change; read teammates' plans in the background.


## Blocked

Nothing.

## Needs from others

- **Design:** done by me at 04:12 (three lines in `Destinations.swift`, ids `collab.ai`, `collab.lanes`, new `collab.plans`); move or restyle as you like. Still open: `collab.ai` → `AskView()`; add `collab.plans` → `TeamPlansView()`. Optionally `.askPanel(isPresented:)` on the iPad shell with an `AskPanelButton` in the toolbar, so Ask opens next to any screen. Screens that show a page can call `CollabHooks.noteCurrentPage(title:url:text:)` for the "current page" context.
- **Platform:** a streaming call on `HTTPClient` (e.g. `bytes(for:label:)` that logs on completion) would let `OpenRouterClient` drop its own bookkeeping. Not urgent.
- **Team / vault:** nothing; wired to `TeamFeatures.shared` and `VaultSession.shared` as on dev.
