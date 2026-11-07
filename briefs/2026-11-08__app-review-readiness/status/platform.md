# Status · platform · App Review readiness

> Items 1–5, 7, 8 and design's Q9 request are pushed on `night/platform`; CI results below. Swift 6 mode is not switched (inventory below). Item 6 waits for team. applinks: removed until the site serves its AASA file.

Branch: `night/platform` · Last update: 14:45 UTC

## Done (pushed, CI result below)

1. **Q5 release builds**
   - Launch options and `isInspectable`: **design gated both on `night/design`** (`Shell/LaunchOptions.swift`: every option absent in Release; `Shell/WebPage.swift`: inspector Debug only). I had done the same; I put my copies back to dev's version (`aaa6a34`), and a trial merge of `night/design` into `night/platform` is clean.
   - `-PTMe`: the persisting line is `Shell/AppShell.swift:35`, design's file (see "For other sessions"). My screens test no longer passes `-PTMe`: it passes `-team.me ana`, a UserDefaults argument that overrides `team.me` for that launch only and is never saved.
   - `PreviewSamples` untouched (design's "Try with sample data" needs it in Release).
   - `ios.yml`: new job **Release build (device, unsigned)** (`66081e3`): `-configuration Release`, `generic/platform=iOS`, and a check that `PrompTugalWidgets.appex` and `PrompTugalIntents.appex` are embedded. Runs wherever the build job runs.
   - Tests: `LaunchOptionsTests` (Debug reads the process arguments, Release none).
2. **Purpose strings** (`a0147e8`)
   - `NFCReaderUsageDescription` removed (no Core NFC code).
   - Camera: "only to scan the QR code of a vault key, when you choose to scan one."
   - Microphone: "while you hold the dictation button … The audio is not kept." (hold-to-dictate in Ask and Lanes.)
   - Speech: "on your device when your language allows it; otherwise your audio is sent to Apple to be transcribed."
   - Kept and checked against code: Face ID (vault keys), calendar write-only (`Schedule/CalendarExport.swift`).
   - Tests: `InfoPlistTests` (no NFC, camera says QR code, speech says Apple, exactly these five purpose strings).
3. **Background modes** (`a0147e8`): `UIBackgroundModes` is `fetch` only. Both tasks (`TeamBackground`, `VaultBackground`) are `BGAppRefreshTask`. Tested in `InfoPlistTests`.
4. **HTTP response cap** (`c5ccde7`): `HTTPClient.data(for:)`, `get` and `decode` take `maxBytes`, default `HTTPClient.defaultMaxBytes` = 10 MB. A Content-Length over the cap is refused before reading; otherwise the body streams and the request is cancelled at the cap. Debug → Network shows "Too large". Tests: `HTTPClientSizeCapTests` (URLProtocol stub, no network).
5. **Universal links: applinks: removed** (`1827ccd`). promptugal.news answers 404 for the AASA file and nothing in the app handles `NSUserActivityTypeBrowsingWeb`, so `applinks:` did nothing. Links into the app keep using `promptugal://`. **`webcredentials:promptugal.news` stays**: passkey vault unlock is still behind `VaultConfig.passkeyPRFEnabled`.
   - For the site, when passkeys go live (editor/Dinis): serve `https://promptugal.news/.well-known/apple-app-site-association`, `Content-Type: application/json`, no redirect, with `{"webcredentials": {"apps": ["<TeamID>.news.promptugal.reader"]}}`. To bring universal links back later, add `"applinks": {"details": [{"appIDs": ["<TeamID>.news.promptugal.reader"], "components": [{"/": "/*"}]}]}`, put `applinks:promptugal.news` back in `Config/PrompTugal.entitlements`, and add an `onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` handler that routes the URL.
7. **ReaderStore** (`f3eb41d`): `content.json` is decoded in a detached task at launch, not in `init` on the main thread, and adopted unless a refresh already brought newer content. Cached session details are capped at 300 (today's agenda and the picks kept first), on load and after each fetch. Tests: `ReaderStoreTests`.
9. **Q9 Websites column** (`aaa6a34`, design's request): `App/Web/WebsiteView.swift` sizes the shortcuts column to min(250 pt, 32% of the width) and hides it below 600 pt (Split View, Slide Over), where the toolbar button opens the shortcuts sheet. Tests: `WebsiteSidebarWidthTests`.
8. **Privacy manifest re-checked** after these changes: the app's reasons still match. UserDefaults → CA92.1. File dates inside the container (`TeamStore`, `ScheduleStore`, `RemoteFeed`) → C617.1. Shown to the user (Debug → `SystemPanels`) → DDA9.1. No system boot time, disk space or keyboard APIs anywhere. The widget, intents and `Shared/` code use no required-reason API, so the extensions need no manifest of their own.

## Swift 6 mode: not switched

The app targets stay in Swift 5 mode with complete concurrency checking. Switching now turns every remaining warning across six sessions' folders into an error, a day before review; I'd do it in a quiet week, folder by folder. The unchecked escapes, each with why it is safe:

| Where | What | Why it is safe |
|---|---|---|
| `AI/AIKeyStore.swift:83` `MemorySecretStore` | `@unchecked Sendable` | Tests and previews only. `items` is guarded by an `NSLock`. `reads` is written under the lock but read without it, by tests after the work is done. |
| `Notifications/ReminderScheduler.swift:146` `ReminderDelegate` | `@unchecked Sendable` | An `NSObject` subclass (cannot be checked), with one immutable `@Sendable` closure and no other state. |
| `Lanes/SpeechDictation.swift:69` `sink` | `nonisolated(unsafe) let` | The audio tap appends buffers to `SFSpeechAudioBufferRecognitionRequest` on the audio thread, the documented use; nothing else touches the request until `stop()` removes the tap. |
| `Vault/VaultKeyWrap.swift:15` | `@unchecked Sendable` | Only `static let` constants and an `NSLock`; state lives in the Keychain. |
| `Vault/VaultDeviceSigner.swift:11` | `@unchecked Sendable` | Immutable after creation. Holds an `LAContext` (not `Sendable`) that is only passed to Secure Enclave signing. Vault owns it; worth a look if signing ever runs concurrently. |
| `Schedule/ScheduleDocument.swift:159, 166` | `nonisolated(unsafe) static let` `ISO8601DateFormatter` | Configured once in the initialiser and never changed; formatters are thread-safe for formatting and parsing. Could become `Date.ISO8601FormatStyle` (a `Sendable` value) to drop the escape. |

(`Packages/SGitVault` is the vault's package and compiles in Swift 6 mode already.)

## In progress

- CI on the latest push, then a dispatched run so the unit tests (with the new suites) run on iPhone and iPad.

## Waiting

- **Item 6** (notification delegate early in `PrompTugalApp.init`): only if team asks. Not asked yet.

## For other sessions

- **Design:** `Shell/AppShell.swift:35` still persists `-PTMe` (`if let me = LaunchOptions.me { UserDefaults.standard.set(me, forKey: DashboardData.meKey) }`); please remove it with your LaunchOptions change. Nothing of mine passes `-PTMe` any more.
- **Design:** `Dashboards/PreviewSamples.swift:67` writes `team.me = "ana"` into UserDefaults whenever sample data loads. Once "Try with sample data" is a Release button, that overwrites the reader's own "me". Suggest not writing it, or restoring it when sample data is turned off.
- **Everyone:** any HTTP response over 10 MB through `HTTPClient` now fails with `HTTPClient.ResponseTooLarge`. Pass `maxBytes:` if a call genuinely needs more.

## Blocked

Nothing.
