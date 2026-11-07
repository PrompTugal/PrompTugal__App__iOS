<!-- https://ios.promptugal.news/support.html · PrompTugal for iOS 0.3.1 -->

Support

# Using PrompTugal 0.3.1

Help for testers of the iPhone and iPad beta. The app needs iOS or iPadOS 17.0 or later.

## Join the beta

PrompTugal is in a private TestFlight beta. Testers are invited by email by the PrompTugal team. There is no public TestFlight link yet. When one exists, it will be posted here.

1. Install [TestFlight](https://apps.apple.com/app/testflight/id899247664) from the App Store.
2. Open the invitation email on your iPhone or iPad and tap **View in TestFlight**.
3. Tap **Install**. Updates arrive in TestFlight as new builds are approved.

Installing a new build over an older one keeps your saved sessions and your edited website list.

## Edit the website shortcuts

On iPad the sidebar sits beside the page, and the sidebar button hides or shows it. On iPhone, or in a narrow window, the same button opens the list in a sheet.

1. Open PrompTugal once so it copies its default list into Files.
2. In the Files app, open **On My iPhone** (or **On My iPad**) → **PrompTugal** → `Websites.json`.
3. Edit or replace the file, then quit and reopen PrompTugal.

The first entry opens at launch and the order of the list is the order of the sidebar. Each entry needs a unique `id`, a `name`, an HTTPS `url`, an SF Symbols `icon` and a `color` (red, orange, green, teal, blue, indigo or purple). For example:

```
{
  "id": "my-site",
  "name": "example.com",
  "url": "https://example.com/",
  "icon": "globe",
  "color": "green"
}
```

If the file cannot be read, the app shows the default list with a notice. Delete the file and reopen the app to get the defaults back.

## Read offline

Tap the book icon in the bottom bar to open the offline reader. Open it once while you are online so it can fill its cache. After that, Now, Agenda, Saved and News work without a connection. Full articles and the complete web agenda still need a connection. If a refresh fails, the cached content stays on screen with the time of the last good sync.

## Questions

**Why are agenda times not in my time zone?**
Web Summit runs in Lisbon, so the app shows every session in Lisbon time. A session that ends after midnight ends on the next day.

**A link opened in Safari instead of the app. Is that right?**
Yes. Pages on the same website stay in the app. Links to other sites, such as an article’s original source, open in Safari.

**Is the app affiliated with Web Summit?**
No. PrompTugal.news is an independent newsroom. [About this coverage](https://promptugal.news/about/participant.html).

**Where do I report a problem?**
Use **Send Beta Feedback** in TestFlight, or take a screenshot while the app is open. Both reach the team with your build number. You can also open an issue on [GitHub](https://github.com/PrompTugal/PrompTugal__App__iOS/issues).

## Build from source

Open `PrompTugal.xcodeproj` in Xcode 26 or later, choose the **PrompTugal** scheme and a simulator, then **Product → Run**. For a device, pick your team under **Signing & Capabilities** and change the bundle identifier `news.promptugal.reader` if needed. To build for the simulator from the command line:

```
xcodebuild -project PrompTugal.xcodeproj -scheme PrompTugal \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

The code is on [GitHub](https://github.com/PrompTugal/PrompTugal__App__iOS) under the Apache-2.0 licence.
