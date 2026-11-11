# RiskMandate app: the command centre, full screen

ios@web-summit.silvio, for dashboard@web-summit.silvio (Dinis asked tonight, stand on 12 November).

## What changed

- The RiskMandate app now opens straight into the command centre at
  `https://web-summit.sgit.ai/people/silvio/app/index.html#xray` in a full-screen WKWebView, with no browser chrome.
  Code: `Apps/RiskMandate/Sources/CommandCentre/`.
- The web view stays inside the safe areas. The bands under the status bar and home indicator use the page's
  `theme-color`, or its background colour when it has none. No CSS is injected. It works in every orientation the
  target already allowed, on iPhone and iPad.
- It uses the persistent `WKWebsiteDataStore.default()`, so localStorage survives restarts. The X-Ray's OpenRouter
  key, pasted on the device with CHAVE, stays on that device. No key is in the app or the repository.
- CHAVE can also open a sealed key with three words: the page fetches `data/xray/key.sealed.json` and
  unseals it with Web Crypto (PBKDF2 + AES-GCM). `crypto.subtle` works in WKWebView on https, so the app needs no change.
- Links to other sites, `target=_blank` and `window.open` open in Safari. Links on the same host stay in the app.
  JavaScript `alert`, `confirm` and `prompt` show native dialogs (the X-Ray uses `confirm`). Pull down to reload.
- The small gear button (bottom right) opens Settings. Settings has the address, which is saved per device and has a
  "Use the default" button, plus Reload, the Workbench (the on-device model, unchanged) and the ABP link.

## Not done or not verified

- No Mac in the cloud container, so CI's `ios.yml` on `dev` was the only compile check. Nothing was run on a device.
- Blob downloads, such as the X-Ray's "brain" JSON export, are cancelled rather than saved.

## Priority 2: Apple Intelligence (Foundation Models)

The app already uses it. The Workbench (`Sources/Workbench/OnDeviceModel.swift`) streams from
`LanguageModelSession` on iOS 26 devices with Apple Intelligence on, and the framework is weak-linked so iOS 18
still launches. Two small workflows would fit, though neither was built tonight because priority 1 came first:

1. **One-paragraph summary of an X-Ray result.** Add a `WKScriptMessageHandler` named `riskmandate`. The page posts
   `{kind: "summarise", text}`, and the app runs `LanguageModelSession(instructions: "Summarise in one paragraph…")`
   and returns the answer with `callAsyncJavaScript`. The page has to opt in by checking for
   `window.webkit?.messageHandlers?.riskmandate` and showing a button only then, so the website keeps working in
   Safari. This needs about 60 lines in the app and a small change on the page.
2. **Native Share / Summarise on selected text.** Add a `UIMenu` item through `buildMenu` on the web view that
   summarises the selection on the device. It needs no change to the page, but the result shows in a native sheet,
   not in the page.

Limits: the on-device model has a context of about 4K tokens, so a long X-Ray result must be cut first. It works only
on Apple Intelligence devices (iPhone 15 Pro and later, iPads with M1 or A17 Pro and later). It returns English
reliably and Portuguese less reliably. It is fast (first token in well under a second) and free, and the text never
leaves the device.
