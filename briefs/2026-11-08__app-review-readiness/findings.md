# Findings, with file and line

> The three reviews of v0.1.44 (`d4f4292`) condensed, with the file and line for each finding, so each session can go straight to the code. Read-only reviews; nothing was compiled.

Line numbers are from `d4f4292`. They move as fixes land.

## Security

- **S1 signatures not enforced (vault).** `Packages/SGitVault/Sources/SGitVault/SGitVault.swift:33` has `requireSignatures = false`, and nothing sets it to true. Lines 307–315 accept `.unsigned`, `.legacy`, `.keyMissing` and `.invalid`, and only log the result. Lines 438–452 read the public key from `bare/keys/<id>` in the same vault. **Fix:** always refuse `.invalid`. Set `requireSignatures = true` in `VaultSession.makeReader` (`PrompTugal/Vault/VaultSession.swift:79-81`) and `openAccount` (`:133-135`). Pin the allowed author key ids per vault.
- **S2 data sent to the AI without consent (collab).** `PrompTugal/AI/ChatStore.swift:89` turns on agenda, picks and team context by default. "Current page" sends page text (`AIContext.swift:141-148, 273-274`). The only disclosure is about the key (`AskView.swift:79, 347`). `where_is_everyone` shares teammates' plans (`AITools.swift:25-27`).
- **S3 silent Keychain fallback (vault).** `PrompTugal/Vault/VaultKeychain.swift:110-125` tries `.faceID`, then `.userPresence`, then `.deviceUnlocked`. The last option has no access control (`:121`). The Secure Enclave wrap also fails without a passcode (`VaultKeyWrap.swift:258`). The screen still says "behind Face ID" (`VaultViews.swift` ~211).
- **S4 debug in release (design, platform).** `PrompTugal/Design/Components.swift:252` has `DebugMode.defaultOn = true`. `AskView.swift:13` and `LanesView.swift:9` hard-code `true`. `AppShell.swift:73-79` ignores `debugOnly`. `PrompTugal/Shell/WebPage.swift:92` sets `isInspectable = true`.
- **S5 imported vault treated as yours (vault, collab).** `VaultSession.swift:73-75` falls back to `vaults.first`. Imported keys get the role "imported" (`:87`, `CollabVaultGlue.swift:20-21`). `AIKeyStore.loadFromVault` (`AIKeyStore.swift:246-251`) can then read an OpenRouter key from a teammate's vault.
- **S6 app-switcher snapshot (design, vault).** Nothing hides sensitive screens when the app goes inactive. The key field is a `TextField` (`VaultViews.swift:144`); `TeamPlansView.swift:222` shows how to do it with a `SecureField`.
- **S7 low.**
  - Inflate has no output cap (`Zlib.swift:21`). Neither `VaultTransport.swift:132` nor `HTTPClient.swift:96` caps the body size.
  - The key stays on the pasteboard after paste-import (`VaultViews.swift:169`). Ask's Copy uses the general pasteboard (`AskView.swift:145`).
  - `notify.plan` can show the permission prompt without a tap (`AppBridge.swift:174-177`). `schedule.get` is open to both hosts (`:159-160`). The meter's "already" answer is trusted (`:264-277`).
  - Lane endpoints can be any https host (`LaneAddress.swift:72, 80`). Append tokens are stored in UserDefaults (`LanesStore.swift:66-68`).
  - Links in Ask output are tappable (`AskView.swift:470-472`).
  - Refunds are not reversed (`CreditStore.swift:95`).

## App Review

- **R1 demo access (design, team).**
  - Who are you? lists real team names (`Dashboards/TodayView.swift:12-14, 33-49`).
  - "Not on the team" ends on an empty Today tab (`TodayView.swift:15`, `Components.swift:336-338`).
  - Sample data only turns on with a launch argument (`Shell/LaunchOptions.swift:20`).
- **R3 privacy policy (editor, design).**
  - `website/pages/privacy.html:11` and `:17` say nothing is collected or sent back. Lanes send data (`Lanes/LaneClient.swift:26-58`), and so do vault writes.
  - `:27` says the OpenRouter key is behind Face ID, but it is stored `AfterFirstUnlockThisDeviceOnly` (`AI/AIKeyStore.swift:56`).
  - Speech may go to Apple (`Lanes/SpeechDictation.swift:37`).
  - There is no privacy link in `Shell/SettingsView.swift`.
- **R4 user content (collab, editor).** Nothing in `Lanes/` lets a person report or block. `website/pages/support.html:53-60` has no contact address.
- **R5 purchases (team).**
  - `Store/ReadingCreditView.swift:78` says every page opens at any balance.
  - The pack `credit.5` is 500 pence in the app (`CreditStore.swift:19-20`) but 0.99 in `Store/PrompTugal.storekit`.
  - Credit is only written into the website's local storage (`Bridge/AppBridge.swift:278-295`, `BridgeScripts.swift:172-193`).
- **Purpose strings (platform).**
  - `NFCReaderUsageDescription` exists, but there is no Core NFC code (`project.pbxproj:603`).
  - The camera is used only for QR codes (`Vault/VaultViews.swift:336`).
  - The speech string should say that audio may go to Apple.
- **Background modes (platform).** `processing` is in `Config/PrompTugal-Info.plist:26`, but only `BGAppRefreshTask` is used.
- **External payment (team).**
  - Only `buy.stripe.com` and `/account/top-up.html` are intercepted (`AppBridge.swift:107`).
  - `WebPage.swift:129-135` allows every other navigation.
- **Trademark (Dinis).**
  - The `ShortcutWebSummit` image set is the problem asset.
  - "Web Summit Lisbon" appears in `News/AgendaView.swift:31`, `App/PrompTugalApp.swift:198` and `Schedule/ScheduleIntents.swift:55`.
- **AASA.** `https://promptugal.news/.well-known/apple-app-site-association` returns 404, so `applinks:` and `webcredentials:` do nothing.
- **Fine.**
  - The privacy manifest reasons (CA92.1, C617.1, DDA9.1) match the code.
  - No downloaded code.
  - The native work is well beyond a web wrapper.
  - The Time Sensitive entitlement is justified.
  - `ITSAppUsesNonExemptEncryption = NO` is defensible.

## Stability

- **Q1 (team).** `ScheduleDocument.swift:35-36` accepts any `at` value, and `:135` then runs `Int64((t * 1000).rounded())`, which traps on huge values. This is reachable through the bridge's `schedule.set` (`AppBridge.swift:163-168`) and through vault picks.
- **Q2 (design).**
  - `GraphExplorerView.swift:61-68` replaces the index but keeps `selected`, `path` and `pathStart`, which are then used at lines 55, 196, 233 and 308.
  - `GraphModel.swift:78-80` runs `Int(Double)` on JSON values.
- **Q3 (team).** `CreditStore.swift:96-101` calls `finish()` even though `MeterStore.save()` (`MeterStore.swift:130-138`) swallows errors.
- **Q4 (collab).** `LanesStore` is `@MainActor` (`:6`). `makeMyLane` (`:141`) generates the RSA-4096 key on it (`LaneClient.swift:191-205`). The inbox is also decrypted on it (`:229-237`).
- **Q5 (platform).**
  - There is no `#if DEBUG` anywhere.
  - `LaunchOptions.swift:11-20` is honoured in release.
  - `AppShell.swift:35` persists `-PTMe`.
  - `PreviewSamples.swift` ships in the release build.
  - `.github/workflows/ios.yml:83` builds Debug only.
  - The app targets use Swift 5 mode with complete concurrency checking, so data races are only warnings.
- **Q6 (team).** `ReminderScheduler.swift:64-71` sets the delegate late, and the `openedURL` it sets (`:67`) is never read.
- **Q7 (vault, collab).**
  - `String(describing: error)` is shown to users (`VaultViews.swift:231, 282, 319`; `VaultSession.swift:103, 116, 164`).
  - `VaultError` is not a `LocalizedError` (`VaultError.swift:4`).
- **Q8.**
  - The team models exist three times: `TeamModels.swift:139`, `WireModels.swift:170` and `AIContext.swift:305-313`.
  - TeamStore uses `URLSession.shared` (`TeamStore.swift:158-167`).
  - Lisbon-day code is in `DayPlanner.swift:210`, `AIContext.swift:100` and `PrompTugalApp.swift:313`.
  - The base URL is defined three times.
- **Q9.** Fixed widths: `LanesView.swift:30` (400), `WallView.swift:19` (360), `GraphExplorerView.swift:89` (340) and `WebsiteView.swift:20` (250).
- **Smaller.**
  - Ask can double-send (`ChatStore.swift:164, 187`).
  - A tap on the agent grid's header selects row 0 (`DashboardParts.swift:66`).
  - Five fixed font sizes ignore Dynamic Type (`WallView.swift:79`, among others).
  - The chat history is unbounded (`ChatStore.swift:133`).
  - `VaultCommitBuilder.swift:184` uses `parts.last!`.
  - `walkTree` has no depth cap.
- **Tests missing.** AppBridge origin checks, CreditStore and MeterStore, VaultSession and VaultKeychain, GraphIndex, PlannerStore, ReminderScheduler, RemoteFeed, TeamStore.
- **Fine.**
  - Few force unwraps, all guarded or on constants.
  - No `print`, no open markers and no `try!` in app code.
  - Logs are capped.
  - Timers stop with their views.
  - Heavy decoding, PBKDF2 and the graph layout already run off the main thread.
