# Status · Collaboration and AI

> Ask (native OpenRouter chat, streamed, key in the Keychain, context toggles, brief me / plan my day / my agents) and "Where is everyone" (overlaps, clashes, meet-here slots from vault-shared picks) are pushed and waiting for CI. Append lanes are next.

Branch: `night/collab` · Last update: 04:05 UTC

## Entry views (for design, `Shell/Destinations.swift`)

| id | View | Notes |
| --- | --- | --- |
| `collab.ai` | `AskView()` | Inside a `NavigationStack`. Also `.askPanel(isPresented:)` on any view: a side panel on iPad (`inspector`), a sheet on iPhone; `AskPanelButton(isPresented:)` for the toolbar (⌘K). |
| `collab.plans` | `TeamPlansView()` | "Where is everyone". Suggest section `.team`, kind `.native`. |
| `collab.lanes` | `LanesView()` | Coming next. |

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

## What needs keys (also said in the UI)

- The team site's public data has **one shortlist for everyone** (each person's `data.json` lists the same 80 sessions), so it cannot show who goes where. Personal picks need each teammate's vault read key.
- Sharing my plan needs my vault opened with its vault key or passkey (write access).

## In progress

- CI run for the first push.

## Next

1. Append lanes: send a note or tip to a lane (sgit hybrid envelope, RSA-OAEP-SHA256 + AES-256-GCM, checked against sgit-ai 0.27's `PKI__Crypto.py`), read my inbox lane, `LanesLog` for Debug.
2. Newsroom notes from the app (text and voice, on-device transcription).
3. Vault glue (`CollabHooks.vault`) once `night/vault` is on dev.

## Blocked

Nothing.

## Needs from others

- **Design:** register the entry views above. `collab.ai` → `AskView()`; add `collab.plans` → `TeamPlansView()`. Optionally `.askPanel(isPresented:)` on the iPad shell with an `AskPanelButton` in the toolbar, so Ask opens next to any screen. Screens that show a page can call `CollabHooks.noteCurrentPage(title:url:text:)` for the "current page" context.
- **Platform:** a streaming call on `HTTPClient` (e.g. `bytes(for:label:)` that logs on completion) would let `OpenRouterClient` drop its own bookkeeping. Not urgent.
- **Team:** when `ScheduleStore` is on dev I set `CollabHooks.myPickIds` from it; until then picks come from the reader's saved sessions. `PlannerStore` text for "plan my day" via `CollabHooks.dayPlan`.
- **Vault:** I code against `VaultSession` on `night/vault` (`readFile`, `update`, `savePicks`, `importKey`) and wire it once it is on dev.
