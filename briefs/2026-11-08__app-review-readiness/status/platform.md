# Status · platform · App Review readiness

> Done: items 1–8, design's Q9 and team's Q6/Q8. Final CI run 263 (`aa64031`, head of `night/platform`): all green, Release build green, 212 tests in 61 suites on iPhone and on iPad (3 known issues: team's StoreKit tests, no products on the CI simulator). Ready for the conductor to merge.

Branch: `night/platform` · Last update: 18:07 UTC

## Done · CI run 210 (`2b0644e`, workflow_dispatch): all jobs green

Build and SGitVault tests ✅ · Release build (device, unsigned) ✅, `PrompTugalWidgets.appex` in PlugIns and `PrompTugalIntents.appex` in Extensions · unit tests **141 in 38 suites passed on iPhone and on iPad** (124 before today; new: InfoPlist, LaunchOptions, HTTP size cap, ReaderStore, Websites column).


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

## Later today

6. **Q6 notification delegate** (`c270bfa`, after team reached dev): `PrompTugalApp.init` calls `ReminderScheduler.installNotificationDelegate()` next to the background-task registrations, so a reminder tapped on a cold launch is delivered. **Q8:** the app's private `lisbonDay` is replaced by team's `Lisbon.day`; `LisbonDayHelperTests` pins summer and winter boundaries. Run 254: green, 198 tests in 55 suites.
10. **StoreKit in CI tests** (conductor's request, for team's `CreditStoreTests`). The `PrompTugal` scheme's Test action now names `Store/PrompTugal.storekit` (`2ecc2fc`; it is what Xcode uses locally). On the CI simulator (Xcode 26.6) StoreKit returned **0 products and no error** in every setup I tried:

    | Run | Setup | Products |
    |---|---|---|
    | 245 | scheme Test action configuration only | 0 |
    | 245 | `SKTestSession(contentsOf:)` with the file path | 0 |
    | 254 | both of the above, test host signed ad hoc (`signed=true`) | 0 |
    | 260 | copy in the test bundle, `SKTestSession(configurationFileNamed:)` | 0 |

    The signing, the bundled copy and the probe test were removed again (`02176c0`); only the scheme setting stays. Team's three purchase tests keep their `withKnownIssue`. **For Dinis or anyone with a Mac:** run `CreditStoreTests` from Xcode (⌘U) once; if products load there, the gap is the headless CI simulator, not the code or the file.

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

Nothing. (`99c4e1c` after run 210 changes only this page.)

## Waiting

Nothing.

## For other sessions

- **Design:** `Shell/AppShell.swift:35` still persists `-PTMe` (`if let me = LaunchOptions.me { UserDefaults.standard.set(me, forKey: DashboardData.meKey) }`); please remove it with your LaunchOptions change. Nothing of mine passes `-PTMe` any more.
- **Design:** `Dashboards/PreviewSamples.swift:67` writes `team.me = "ana"` into UserDefaults whenever sample data loads. Once "Try with sample data" is a Release button, that overwrites the reader's own "me". Suggest not writing it, or restoring it when sample data is turned off.
- **Everyone:** any HTTP response over 10 MB through `HTTPClient` now fails with `HTTPClient.ResponseTooLarge`. Pass `maxBytes:` if a call genuinely needs more.

## Blocked

Nothing.
