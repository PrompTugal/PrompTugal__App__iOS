# conductor-report/v1: the file the command centre reads

> The shared format between conductors and the apps (VoiceDebrief today, PrompTugal's Team app next), as the VoiceDebrief conductor gave it on 15 November 2026 from `Apps/VoiceDebrief/Sources/Model/AgentsReport.swift`. Proposed additions for the city newsroom are marked; readers ignore unknown fields, so they are safe to add.

## Where it lives

A conductor writes `agents/agents.json` (and `agents/overview.png`) into a vault the user handed it. The app reads it with the vault's read key. Dates are ISO 8601 UTC.

```
{ "v": 1, "made": date, "conductor": "<agent id of the writer>", "latestBuild": "0.1.107"?,
  "agents":   [ { "id", "name", "kind": "conductor"|"session"|"subagent", "role",
                  "status": "working"|"waiting"|"blocked"|"idle"|"done", "doing",
                  "waitingFor"?, "parent"? (agent id), "lastActive"? date, "lane"? ("sgi1." link) } ],
  "links":    [ { "from", "to", "label" } ],
  "messages": [ { "id", "agent", "from" ("you" | agent id), "at", "text", "replyTo"?, "quote"? } ],
  "decisions":[ { "id", "title", "detail"?, "options": [string], "from", "at" } ]?,
  "nextSteps":[ string ]? }
```

## Back to the conductor

Over the conductor's append lane, sealed to its lane key:

- `voicedebrief/agent-message/v1`: JSON `{id, agent, at, text}`. A decision answer uses text `Decision <id> (<title>): <choice>`.
- `voicedebrief/vault-key/v1`: body `<vault name>\n<key>`, how the user hands the report vault to the conductor.

## Proposed additions (PrompTugal, not yet agreed)

| Field | On | Why |
| --- | --- | --- |
| `account` | agent | Group Dinis's 50 to 120 sessions by account |
| `newsroom` | agent | City id (`faro`, `lagos`, …) for the per-city view |
| `newsroomRole` | agent | `researcher` \| `outreach` \| `reporter` \| `editor` \| `regional` |
| `policy` | agent | Path of the policy file it runs under, e.g. `policy/editor.json` in the city vault |
| `events` | top level | `[ { "agent", "at", "rule", "outcome": "allowed"\|"blocked", "detail" } ]`: the policy trail the app draws |

The message kinds would stay `voicedebrief/...` for now; renaming to a neutral `sgit/agent-message/v1` later needs both apps to accept both.
