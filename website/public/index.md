<!-- https://ios.promptugal.news/ · PrompTugal for iOS 0.3.1 -->

Private beta · iOS and iPadOS 17.0+

# The newsroom, in your pocket, even offline.

PrompTugal puts the live PrompTugal.news newsroom and the sites around it in one sidebar, 5 websites in all. A native reader keeps the Web Summit Lisbon agenda, your saved sessions and the latest stories on the device for when the venue Wi-Fi gives up.

[Join the TestFlight beta](support.html#beta) [Read the source](https://github.com/PrompTugal/PrompTugal__App__iOS)

- Version 0.3.1
- iPhone and iPad
- No account, no tracking
- No third-party packages

How it reads

## Two ways in, one app.

### 01 The live websites

Each website opens in its own tab with its own page and back history, so you can jump between the newsroom and the team’s sites without losing your place. Updates to the websites show up right away, with no app update needed.

Your theme, schedule picks and profile on PrompTugal.news are remembered on the device. Links to outside sources open in Safari.

### 02 The offline reader

Tap the book icon for a native reader built for spotty conference networks. Agenda times always stay in Lisbon time, whatever your phone says.

- **Now** What is on and what is next.
- **Agenda** Every session, searchable by title or venue.
- **Saved** Your sessions, kept when you are offline.
- **News** The latest stories from the newsroom.

The sidebar

## 5 websites, ready at launch.

The app comes with the newsroom and the sites around it. On iPad the list sits beside the page. On iPhone it opens as a sheet.

The list is a plain `Websites.json` file in **Files → On My iPhone → PrompTugal**. Reorder it, remove a site or add any HTTPS address, then reopen the app. A broken file falls back to the defaults and tells you so. [How to edit it](support.html#websites).

- [promptugal.news](https://promptugal.news/)
- [web-summit.sgit.ai](https://web-summit.sgit.ai/)
- [newsroom.sgit.ai](https://newsroom.sgit.ai/)
- [riskmandate.ai](https://riskmandate.ai/)
- [sgit.ai](https://sgit.ai/)

Built small, on purpose

## Only Apple’s frameworks, nothing else.

SwiftUI and WebKit, with no third-party packages, no analytics SDK and no server of its own. The app reads the same public agenda feed, event records and RSS feed that PrompTugal.news publishes for everyone. These numbers are counted from the source each time this site is built.

**1,164**
lines of Swift

**5**
Swift files

**0**
third-party packages

**5**
websites in the sidebar

Independent

## People and AI agents, reporting together.

PrompTugal.news maps the AI scene in Portugal. Its stories are written by AI agents, then checked and signed by human editors, and every fact is sourced and dated. The app shows that work as it is. PrompTugal’s coverage is independent of Web Summit.

[About this coverage](https://promptugal.news/about/participant.html) · [What the app keeps on your device](privacy.md)
