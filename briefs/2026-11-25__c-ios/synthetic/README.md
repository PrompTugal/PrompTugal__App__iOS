# Synthetic users (c.ios.synthetic)

Eight fictional readers walk the current build from its SwiftUI code and the live JSON it reads. No Mac, no screenshots yet.

| File | What |
| --- | --- |
| [personas.md](personas.md) | the eight cards |
| [walkthroughs.md](walkthroughs.md) | screen by screen per persona, shared findings S1 to S14, top fixes |
| [app-review-risk.md](app-review-risk.md) | the reviewer's one page: R1 to R11 with fixes |

## Runs

| Date | Build | Headline |
| --- | --- | --- |
| 25 Nov 2026 | work/candidate-c2 `5404498` (dev `ccddde5` + c2) | Privacy and support pages describe the summit beta; weather promised but never shown; CI status, Reading credit and summit screens still in the store build. |
| 25 Nov 2026 | work/candidate-c2c `962e8f9` | [changes-c2c.md](changes-c2c.md): More and iPad sidebar clean; still blocking: weather in the listing, support page beta half, privacy page not deployed, price chips on articles. |
| 26 Nov 2026 | work/candidate-c2d `a3db74f` | [changes-c2d.md](changes-c2d.md): one blocker left, the listing still promises "Now in", which never shows; "independent" still on the News tab and the Algarve board page. |
| 26 Nov 2026 | work/candidate-c2e `5cbf730` | [changes-c2e.md](changes-c2e.md): no blocker found; new: 21 languages declared, English only with no switch. |
| 26 Nov 2026 | work/candidate-c6 `2a58431` (next version) | [changes-c6.md](changes-c6.md), all personas: Home, freshness lines, events and council blocks are real gains; Portuguese reader now stuck (no language at all); rebuilt Explore unreachable; Home leads with placeless industry items. |
| 26 Nov 2026 | dev `2403d92` = c7, TestFlight 683 | [changes-c7.md](changes-c7.md): local-first Home, shorter Places, two of three "independent" lines gone; Work with us link lost; Portuguese reader still stuck; nothing blocks TestFlight. |
| 27 Nov 2026 | dev `6cc9ae2` = c8b, TestFlight 688 | [changes-c8b.md](changes-c8b.md): article reader and signature check verified live (14/14); offline edition not read by Home, Places or articles; mistake link goes to the contributor page. |

Later candidates: only what changed, appended here as new rows and a `changes-<candidate>.md`.
