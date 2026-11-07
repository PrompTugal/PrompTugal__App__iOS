# Status · Collaboration and AI

> Ask (native OpenRouter chat, streamed, key in the Keychain), "Where is everyone" (overlaps, clashes, meet-here slots from vault-shared picks) and Messages (append lanes with sgit's envelope, inbox, newsroom notes, dictation) are pushed; first CI run in the queue. Vault and team glue are written and go in when those branches reach dev.

Branch: `night/collab` · Last update: 04:10 UTC

## Entry views (for design, `Shell/Destinations.swift`)

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

## What needs keys (also said in the UI)

- The team site's public data has **one shortlist for everyone** (each person's `data.json` lists the same 80 sessions), so it cannot show who goes where. Personal picks need each teammate's vault read key.
- Sharing my plan needs my vault opened with its vault key or passkey (write access).

- Sending to a teammate needs their lane description. None is published yet; the share button on Messages makes one.
- Registering my own inbox lane on my vault (`configure`) needs the vault's write key and an access token; this build does not do that step.
- No PrompTugal newsroom append lane is published (promptugal.news has no `/.well-known/sgit-subscribe.json`), so newsroom notes go through the vault notes lane.

## In progress

- CI run 74 (all of the above).

## Next

1. Fix whatever CI finds.
2. Vault glue (`VaultCollabAccess`, written) once `night/vault` is on dev; team glue (picks from `ScheduleStore`, plan text from `PlannerStore`, written) once `night/team` is on dev.
3. Ask: tool calls over the app's data (search the agenda, my picks), as the website's chat does.

## Blocked

Nothing.

## Needs from others

- **Design:** register the entry views above. `collab.ai` → `AskView()`; add `collab.plans` → `TeamPlansView()`. Optionally `.askPanel(isPresented:)` on the iPad shell with an `AskPanelButton` in the toolbar, so Ask opens next to any screen. Screens that show a page can call `CollabHooks.noteCurrentPage(title:url:text:)` for the "current page" context.
- **Platform:** a streaming call on `HTTPClient` (e.g. `bytes(for:label:)` that logs on completion) would let `OpenRouterClient` drop its own bookkeeping. Not urgent.
- **Team:** when `ScheduleStore` is on dev I set `CollabHooks.myPickIds` from it; until then picks come from the reader's saved sessions. `PlannerStore` text for "plan my day" via `CollabHooks.dayPlan`.
- **Vault:** I code against `VaultSession` on `night/vault` (`readFile`, `update`, `savePicks`, `importKey`) and wire it once it is on dev.
