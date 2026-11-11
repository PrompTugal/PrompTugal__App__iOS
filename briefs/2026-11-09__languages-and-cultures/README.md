# Languages and cultures for the news app (iOS and the web app)

> For the iOS conductor (and the team session that owns the app's strings), and for PrompTugal's team (the web app at promptugal.news `/app/` and the content). From conductor@web-summit.dinis, at Dinis's word (9 November 2026, about 19:25 UTC).

**Dinis:** *"Add all those languages and cultures (see for example what I did on sgraph.ai on the culture). Make the language selection very visible, and make the default always back to English."*

## The model: SG/Send's cultures

On send.sgraph.ai, a locale is **a language and a region (a culture)**, not just a language:

- each culture has its own folder: `/en-gb/`, `/pt-br/`, `/de-ch/`;
- `hreflang` links on every page, with `x-default` set to en-GB;
- the cultures are en-GB, en-US, pt-PT, pt-BR, de-DE, de-CH, es-ES, es-AR, es-MX, fr-FR, fr-CA, it-IT, nl-NL, pl-PL, hr-HR and ro-RO.

The region matters: it sets spelling, words, date and number formats, and the first day of the week.

## The cultures for the news app

| | Cultures |
|---|---|
| **Already there** | en (make it **en-GB**), pt-PT, pt-BR |
| **SG/Send's set** | en-US, de-DE, de-CH, es-ES, es-AR, es-MX, fr-FR, fr-CA, it-IT, nl-NL, pl-PL, hr-HR, ro-RO |
| **For the summit's delegations from Asia and the Middle East** | zh-Hans (Simplified Chinese), ja-JP, ko-KR, hi-IN, ar (right to left) |

That is 21 cultures. Use the region-specific catalogue entries (`es-AR`, `fr-CA` and so on) only where the text really differs; otherwise the language's base strings apply.

## The rules Dinis set

1. **The default is always English (en-GB).** The app does **not** follow the device's language on its own. A reader sees English until they choose otherwise.
2. **The language choice is very visible.** In the app and in the web app, a **globe button with the current culture's code** (for example "🌐 EN") sits at the top of every main screen, never buried in Settings.
   - Tapping it opens a list of all cultures, each written in its own language ("Deutsch (Schweiz)", "Português (Brasil)", "日本語"), with the current one ticked.
3. **"Back to English" is always one tap.** It is the first row of the list, and a small "EN" shortcut sits beside the globe whenever another culture is active.
4. The choice is remembered on that device only (local storage). It is never sent anywhere.

## How

- **iOS:** the String Catalogs (`*.xcstrings`; about 470 strings across the app and its packages) get the new cultures, translated by an agent and spot-checked. Add the regions to `knownRegions`.
  - Set the in-app language with the app's own picker (`Bundle` override or a `locale` environment value), so the device language does not take over.
  - Use SwiftUI's formatters for dates and times in the chosen culture. Test Arabic for right-to-left, especially the schedule grid and the map.
- **The web app:** the same strings as JSON per culture, the same globe button, `lang` and `dir` on the page, and `hreflang` like SG/Send.
- **The content** (events, articles, company pages), on PrompTugal's side: translations stored beside each original, marked "machine-translated, original in English". Event titles and people's names stay as they are. Start with the event pages.
- **The App Store and Play listings:** a description per culture comes later, with the next store update.

## Order

1. Tonight: the globe button with "back to English", and the app's own strings in all 21 cultures (iOS and the web app).
2. Then: Arabic's right-to-left fixes.
3. Then: content translation on promptugal.news, the event pages first.

Reply in `reply.md` here, or in a commit `For: conductor@web-summit.dinis`.
