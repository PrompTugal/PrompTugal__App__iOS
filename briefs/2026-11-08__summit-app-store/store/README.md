# Store pack: PrompTugal: Lisbon Summit

> Everything Apple sees besides the binary: the App Review checklist, the listing in three languages, the App Privacy and age-rating answers, the review notes, and the final go/no-go. Written by review.B from the code on `dev` (66089cd) plus `split/apps` and `split/editor` at 11:30 UTC, 8 Nov. Release and testflight copy these texts into App Store Connect on the conductor's go. Nothing here has been entered in App Store Connect yet.

| File | What it holds |
| --- | --- |
| [checklist.md](checklist.md) | App Review checklist against the guidelines. Each item is marked OK, RISK or BLOCKER, with an owner. |
| [listing-en.md](listing-en.md) | English (U.S.) listing: name, subtitle, promotional text, description, keywords, what's new, URLs |
| [listing-pt-PT.md](listing-pt-PT.md) | Portuguese (Portugal) listing |
| [listing-pt-BR.md](listing-pt-BR.md) | Portuguese (Brazil) listing |
| [app-privacy.md](app-privacy.md) | App Privacy (nutrition label) answers, derived from the code |
| [age-rating.md](age-rating.md) | Age rating answers, plus category, price and availability |
| [review-notes.md](review-notes.md), [review-notes.txt](review-notes.txt) | App Review and Beta App Review notes for the public app: settings and checks, and the final text |
| [go-no-go.md](go-no-go.md) | The final list, checked before each submission |

The persona walk-throughs (synthetic users) are in [status/review.md](../../2026-11-08__three-apps/status/review.md).

## Fields shared by every language

| Field | Value |
| --- | --- |
| App name | PrompTugal: Lisbon Summit (25 of 30 characters) |
| Home-screen name | PrompTugal (`CFBundleDisplayName`; unchanged) |
| Bundle ID | news.promptugal.reader (existing record "PrompTugal.news"; the name changes in App Store Connect) |
| Primary category | News |
| Secondary category | Business |
| Price | Free, no in-app purchases |
| Copyright | 2026 PrompTugal |
| Support URL | https://ios.app.promptugal.news/support.html |
| Marketing URL | https://ios.app.promptugal.news/ |
| Privacy policy URL | https://ios.app.promptugal.news/privacy.html |

The three English URLs answer 200 today, and they match `SupportLinks` in `Packages/PTCore/Sources/PTCore/Shell/ShellParts.swift`. Editor confirmed them through the conductor at 11:25 UTC. The Portuguese listings use `/pt/`, `/pt/support.html` and `/pt/privacy.html`, which go live when `split/editor` merges. The pt listings go in only if i18n merges by 16:00 (conductor); otherwise the store has English only.
