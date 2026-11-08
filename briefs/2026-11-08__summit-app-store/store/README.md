# Store pack: PrompTugal: Lisbon Summit

> Everything Apple sees besides the binary: the App Review checklist, the listing in three languages, the App Privacy and age-rating answers, the review notes, and the final go/no-go. Written by review.B from the code on `dev` (66089cd) plus `split/apps` and `split/editor` at 12:30 UTC, 8 Nov. Release and testflight copy these texts into App Store Connect on the conductor's go. Nothing here has been entered in App Store Connect yet.

| File | What it holds |
| --- | --- |
| [checklist.md](checklist.md) | App Review checklist against the guidelines. Each item is marked OK, RISK or BLOCKER, with an owner. |
| [listing-en.md](listing-en.md) | English (U.S.) listing: name, subtitle, promotional text, description, keywords, what's new, URLs |
| [listing-pt-PT.md](listing-pt-PT.md) | Portuguese (Portugal) listing |
| [listing-pt-BR.md](listing-pt-BR.md) | Portuguese (Brazil) listing |
| [app-privacy.md](app-privacy.md) | App Privacy (nutrition label) answers, derived from the code |
| [age-rating.md](age-rating.md) | Age rating answers, plus category, price and availability |
| [review-notes.md](review-notes.md) | App Review and Beta App Review notes for the public app, and the demo instructions |
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

The three URLs answer 200 today. They match `SupportLinks` in `Packages/PTCore/Sources/PTCore/Shell/ShellParts.swift`. Editor confirms the final URLs through the conductor; if the site moves the pages, `SupportLinks` and this table change together.
