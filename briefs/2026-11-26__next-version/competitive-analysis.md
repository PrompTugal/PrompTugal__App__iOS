# PrompTugal.news: competitive analysis (27 Nov 2026)

> Which apps and sites a user meets for "Portugal news", "Portugal AI news" and the Algarve terms (iTunes Search API, gb/pt/us, 27 Nov 2026), and where PrompTugal.news can win.

Source: iTunes Search API (gb, pt, us; 5 terms; top 25 each), plus homepage fetches. Ratings are per the store queried, so counts are small and indicative only.

## Apps users meet

| App | Seller | Rating (count) | Price | Last update | Language | Positioning |
|---|---|---|---|---|---|---|
| Portugal News in English | Juicestand Inc | 4.0 (45) | Free | 30 Oct 2026 | EN | Independent expat/visitor news, by topic and by place, sources listed. Closest rival. |
| Portugal Resident | Open Media Design e Publicacoes SA | 4.5 (2) | Free | 3 Oct 2026 | EN (many UI) | Daily site of weekly The Resident (since 1989); Algarve section. |
| The Portugal News | Anglopress | 1.0 (3) | Free | 6 May 2024 | EN | "400,000 readers a week", 11 languages. Stale. |
| Portuguese Newspapers | MUNBEN SA | 4.8 (78) | Free | 5 Oct 2026 | EN UI | Aggregator of national papers and magazines. |
| CNN Portugal | Media Capital Digital | 3.7 (3) | Free | 26 Nov 2026 | PT | TV-led breaking news, video. |
| RTP Notícias | RTP | 3.4 (16) | Free | 19 Mar 2026 | PT | Public broadcaster, real-time push. |
| Observador | Observador on time | 4.5 (2) | Free | 19 Nov 2026 | PT | Digital daily, radio, push; paywall on site. |
| Notícias ao Minuto Portugal | New Adventures | none | Free | 14 Nov 2025 | PT | Fast-feed national news. |
| Sul Informação | Pagina em Branco (association) | 4.6 (5) | Free | 9 Jul 2026 | PT (UI marked EN) | Algarve and Baixo Alentejo regional news. Only true Algarve news app. |
| Euronews | euronews | 4.5 (710) | Free | 4 Nov 2026 | Multi | Ranks by "Portugal" keyword; live TV, offline, data saving. |
| The Local | The Local Europe AB | 4.7 (1,100) | Free | 13 Nov 2026 | EN | Nine European countries, none Portugal; ranks for "Algarve news". |
| Ferragudo / Alcantarilha | Absolutepixel | none | Free | Nov 2026 | PT/EN | Parish apps: alerts, local news, beaches. Rank for Algarve terms. |
| Algarve Connect | Sixtina Alwardt | 5.0 (1) | Free | 12 Jun 2026 | EN | Community and services directory, not news. |

I could not see in-app purchase data in the search results; none of the news apps advertise subscriptions in their store text.

**"Portugal AI news":** no news app ranks. UK and US results are generic AI assistants (Perplexity, Sintra, Genspark, DeepLearning.AI). In pt the only relevant hit is "Notícias & Resumos IA: Pidgeon" (zero ratings). In the US, The Portugal News appears at 5 only because of "portugal". The niche is empty.

## Websites (homepage fetch, partial)

- **Portugal Resident** (EN, free): national and Algarve news, events, lifestyle; page mentions Faro, Lagos, Portimão heavily, so place tagging is by region and keyword, not per-town hubs. No AI section seen.
- **The Portugal News** (EN): fetch returned an empty page (HTTP 202); not verified. App was last updated May 2024.
- **Observador** (PT, pt-PT): national, strong opinion and explainers; metered paywall markers present; a technology section exists; no town coverage.
- **Público** (PT): national; heavy subscription and paywall code; technology section; essentially no local pages.
- **Sul Informação** and **Postal do Algarve**: blocked by Cloudflare challenge, so unverified. From the app store text, Sul Informação covers Algarve and Baixo Alentejo in Portuguese. Barlavento not checked.

## Where PrompTugal.news can win

1. Nobody owns "Portugal AI/tech news". Generic AI apps and national papers leave it open.
2. Town-level granularity. Juicestand offers "by place" at region level; parish apps give single-parish alerts. Town by town across the country is unclaimed.
3. Visible sourcing with an AI-agent newsroom shown read-only: a transparency angle that the AI-summary apps (Pidgeon) lack and the human papers cannot match on volume.
4. Free, no account, no paywall, against Observador and Público.
5. Weak incumbents: The Portugal News is stale with a 1.0 rating; most Portuguese apps have under 20 ratings. A small, well-kept app can lead quickly.

## What leaders do that PrompTugal.news lacks

- **Push alerts:** RTP, Observador, CNN Portugal, Juicestand (capped at one a day, never at night). Expected by users.
- **Video and live audio/TV:** Euronews, CNN Portugal, Observador radio. Probably skip at launch.
- **Offline reading and data saving:** Euronews. Cheap to add and useful for visitors.
- **Portuguese UI:** most national apps are PT only; the English apps ignore Portuguese readers. Bilingual EN/PT is a differentiator.
- **Widgets, search, personalised "your place" feed:** Juicestand does location-based "Today in Portugal"; expect similar from others soon.
- **Emergency and practical info:** Juicestand links 112 and "not a government app" disclaimers.

## Keyword and naming observations

- Naming pattern: "Country + News (+ in English)" (Portugal News in English, The Portugal News) or "Brand: descriptor" (Euronews: World news & live TV). Juicestand takes position 1 in us and pt for "portugal news" and in gb for "algarve news" via name match.
- Words that rank: "Portugal", "News", "Notícias", "Algarve"; place names in the app name (Ferragudo, Alcantarilha) win Algarve terms with zero ratings, so title matching is strong.
- "AI" in the name pulls in generic assistants (Perplexity, Sintra); "Portugal" plus "AI" together has almost no competition, so a title containing both will be near the top.
- Portuguese terms return different sets: "notícias portugal" favours PT-language national brands.
- "PrompTugal.news" as a title reads as a brand with no keywords; the dot is unusual. Few competitors use subtitles in results.

## Recommendations

1. Name it "PrompTugal: Portugal AI News" or similar and use the subtitle "Local news by town, with sources". Put "Portugal", "news", "AI" in the first 30 characters.
2. Fill the 100-character keyword field with notícias, Algarve, Faro, Lagos, Portimão, Lisboa, Porto, local, tech, IA, expat, tecnologia; do not repeat words from the title.
3. Ship a Portuguese localisation from day one and localise store text in pt-PT and en-GB, since Algarve queries in gb are dominated by expats.
4. Add capped, opt-in push alerts per town (one a day, no night), then offline reading and a widget for "my town".
5. Collect the first 50 ratings fast (in-app prompt after the third read) and stress "every story with its source" in the first screenshot; that beats The Portugal News and matches the leader's trust claim.
