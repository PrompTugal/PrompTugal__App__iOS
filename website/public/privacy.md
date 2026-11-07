<!-- https://ios.promptugal.news/privacy.html · PrompTugal for iOS 0.3.1 -->

Privacy

# What the app keeps, and where

PrompTugal 0.3.1 has no account, no analytics, no advertising and no server of its own. It collects nothing about you.

## What the app requests

- The offline reader downloads three public feeds from [promptugal.news](https://promptugal.news/): the live agenda, individual event records and the news RSS feed. They are the same files anyone can open in a browser.
- The website tabs load the websites in your sidebar, like any browser would. Each website’s own privacy policy covers what it does.
- Links that leave a website open in Safari, not in the app.

## What stays on your device

- **Saved sessions and cached feeds.** Stored in the app’s private storage so the reader works offline. They are never uploaded.
- **Website data.** Cookies and local storage used by the websites you open, such as your theme and schedule picks on PrompTugal.news. This is kept apart from Safari.
- **Your website list.** The `Websites.json` file you can see and edit in the Files app.

Deleting the app removes all of it.

## TestFlight

While PrompTugal is in beta, Apple’s TestFlight shares your email address, device model, OS version and any feedback or crash reports you send with the team. [Apple’s TestFlight privacy notice](https://www.apple.com/legal/privacy/data/en/testflight/) has the details.

## Checking this

The whole app is open source. The network requests are in `Content.swift` and the website tabs are in `WebsiteView.swift`, both on [GitHub](https://github.com/PrompTugal/PrompTugal__App__iOS).
