# Release setup: from CI build to TestFlight

> What Dinis does once, in the Apple Developer portal, App Store Connect and GitHub, so the `iOS release` workflow signs each app and uploads it to its own TestFlight record. Three apps: PrompTugal (public, existing record), Team (new record) and RiskMandate (builds, never uploads yet). Also covers how to install the unsigned builds CI makes.

**Priority (Dinis):** the target is **internal TestFlight** (team members as App Store Connect users, no Beta App Review) plus the unsigned CI artifacts. PrompTugal goes to Beta App Review before Monday 9 Nov; Team never needs App Review.

Owner: release engineering (`split/release`) · Workflows: `.github/workflows/ios-release.yml`, `ios.yml`, `screens.yml`, `ios-changes.yml` · Scripts: `scripts/release/` · The apps and their bundle IDs: `apps.json`

## The three apps

| App (`apps.json` key) | Bundle ID | Extensions (own App IDs and profiles) | App Group | App Store Connect record | Uploads |
| --- | --- | --- | --- | --- | --- |
| PrompTugal (`promptugal`) | `news.promptugal.reader` | `.widgets`, `.intents` | `group.news.promptugal.reader` | exists ("PrompTugal.news") | yes |
| Team (`team`) | `news.promptugal.team` | none tonight | `group.news.promptugal.team` if needed | **Dinis creates it by hand** | yes, once the record exists |
| RiskMandate (`riskmandate`) | `ai.riskmandate.app` | none | none | not yet (publishing account undecided) | no (`testflight: false`) |

Until phase 4 of the split lands, the project at the repository root is still one app with bundle `news.promptugal.reader`, and `apps.json` calls it `team`. CI builds and uploads it as that. After phase 4, `team` is `Apps/Team/` with `news.promptugal.team` and `promptugal` is `Apps/PrompTugal/` with `news.promptugal.reader`. Nothing in the workflows changes.

**How CI chooses.** A change builds, tests and uploads only the apps it touches (`apps.json` `paths`, plus the packages each app is built from, plus anything under `all`). The run summary starts with a table that says which apps ran and why. An app whose project does not exist yet is skipped with a line in that table.

**Nothing uploads to the wrong record.** Before every upload CI checks that (1) the archive and the .ipa have the bundle ID that `apps.json` names for that app, (2) every installed profile belongs to that bundle ID, and (3) App Store Connect has a record for exactly that bundle ID. If (3) fails, the job ends green with "no App Store Connect record for …" and uploads nothing. If (1) or (2) fails, the job fails.

## Morning checklist: first internal TestFlight builds (about 60 minutes)

For Dinis. Nothing in the code changes. Do the PrompTugal column first; it has a record already.

1. **App IDs** (developer.apple.com → Certificates, IDs & Profiles → Identifiers). Make sure these explicit App IDs exist:
   - PrompTugal: `news.promptugal.reader`, `news.promptugal.reader.widgets`, `news.promptugal.reader.intents`. Create the App Group `group.news.promptugal.reader`. On the app ID enable **App Groups** (that group), **Associated Domains**, **Time Sensitive Notifications**. On both extension IDs enable **App Groups** (same group).
   - Team: `news.promptugal.team`. Enable the same capabilities the Team app's entitlements file lists (the "Targets to sign" table in a package run's summary names them). Add its App Group if it asks for one.
   - RiskMandate: not needed yet.
2. **Certificate.** One **Apple Distribution** certificate serves all apps. Reuse one whose private key you have, or make one. Export it from Keychain Access as `distribution.p12` with a password.
3. **Profiles.** Profiles → + → **App Store Connect**, one for each App ID above (three for PrompTugal, one for Team), all with that certificate. Download them.
4. **App Store Connect.**
   - **Create the Team record by hand:** Apps → + → New App, iOS, bundle ID `news.promptugal.team`, name of your choice (working name "PT Team"), any SKU. The API cannot create apps. Until it exists the Team job skips the upload.
   - API key: Users and Access → Integrations → App Store Connect API → Team Keys → + with role **App Manager** (manual signing) or **Admin** (automatic). One key serves all apps. Note the **Key ID** and **Issuer ID**.
5. **Testers.** For each record: TestFlight → Internal Testing → + group "Team", **automatic distribution** on, and add the testers. Move the Team app's testers to the Team record; the old record keeps PrompTugal's.
6. **GitHub secrets** (repo → Settings → Secrets and variables → Actions → New repository secret). Paste `base64 -i <file> | pbcopy` for files. Shared: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`, `IOS_DIST_CERT_P12_BASE64`, `IOS_DIST_CERT_PASSWORD`. Profiles, one set per app (see the table in Step 3). With automatic signing you only need the shared ASC secrets and the variable `APPLE_TEAM_ID`.
7. **Dry run.** Actions → **iOS release** → Run workflow → branch `dev`, **app** = `promptugal`, tick **dry_run** → Run. In the run's summary, the **Profiles against entitlements** table must be all ✅. A ❌ row names the capability to enable; fix it in step 1, regenerate that profile, update its secret, run again. Repeat with **app** = `team`.
8. **Upload.** Run again with **upload** ticked (per app, or `all`). App Store Connect processes the build in 5–30 minutes and the group gets it in the TestFlight app.

After that, **every push to `dev` uploads the apps it touched** (pushes that only touch docs, the site or `VERSION` are skipped). Tags and manual runs also work.

**Pause.** In **Settings → Secrets and variables → Actions → Variables**:

| Variable | Effect |
| --- | --- |
| `TESTFLIGHT_ON_PUSH=false` | no app uploads on push |
| `TESTFLIGHT_ON_PUSH_PROMPTUGAL=false` | PrompTugal does not upload on push |
| `TESTFLIGHT_ON_PUSH_TEAM=false` | Team does not upload on push |
| `TESTFLIGHT_ON_PUSH_RISKMANDATE=false` | no effect while `testflight` is false in `apps.json` |

Tags and manual runs ignore the pause variables.

**Tags.** One tag releases one app, whatever else changed:

```sh
git tag promptugal-v0.3.2 && git push origin promptugal-v0.3.2
git tag team-v0.1.0       && git push origin team-v0.1.0
git tag riskmandate-v0.0.1 && git push origin riskmandate-v0.0.1   # builds; uploads nothing while testflight is false
```

The old `ios-v*` tag still works and means the app with bundle `news.promptugal.reader`.

**Manual run.** Actions → **iOS release** → Run workflow. Input **app**: `all` or one app. `all` means every app whose project exists, not only the ones the diff touches.

## What CI does today, with no keys

Every push to `dev` that changes more than docs or the site (pushes touching only `briefs/`, `website/`, `*.md` or `VERSION` are skipped to save macOS runner time), and every manual run, runs the **package** job of `iOS release` once per affected app on a macOS runner with the newest stable Xcode. Each app produces four artifacts, named `<Scheme>-<version>-<build>-<sha>-…` (for example `PrompTugal-0.3.1-…`):

| Artifact | What it is | Use |
| --- | --- | --- |
| `…-unsigned-ipa` | `Payload/PrompTugal.app`, zipped, not signed | Re-sign and install on a device (below) |
| `…-simulator-app` | Release build for the iOS Simulator | `xcrun simctl install booted PrompTugal.app` |
| `…-xcarchive` | The archive, with dSYMs | Re-sign, or symbolicate crash logs |
| `build-info-<app>` | `build-info.json`: app, version, build, commit, sizes | Size checks and the website |

The job summary lists the Info.plist values (bundle id, version, build, minimum iOS, SDK, device family) and a size breakdown. The job fails if the app is not built for both iPhone and iPad (`UIDeviceFamily` must be `1,2`).

The **testflight** job runs once per app, on every push to `dev` that builds that app (unless a pause variable is `false`), on a release tag, and when someone starts it by hand with **upload** or **dry_run** ticked. It only runs for an app whose unsigned package succeeded in the same run. Without secrets it does nothing and writes one `skipped: secret X missing` line per missing secret, so pushes stay green until the secrets exist. When `dev` gets several pushes close together, one upload runs and only the newest waiting push follows it; the ones in between are skipped.

## Version and build numbers

- **Version** (`CFBundleShortVersionString`) is `MARKETING_VERSION` in each app's own Xcode project (PrompTugal continues from 0.3.1, Team starts at 0.1.0, RiskMandate at 0.0.1). Change it in Xcode (target → General → Version) when you start a new release. CI never changes it.
- **Build** (`CFBundleVersion`) is set by CI on the `xcodebuild` command line: `CURRENT_PROJECT_VERSION = <run number of iOS release> + the app's offset`. Each app has its own offset: the variable `IOS_BUILD_OFFSET_<APP>` (for example `IOS_BUILD_OFFSET_PROMPTUGAL`), else `IOS_BUILD_OFFSET`, else `100`. PrompTugal must stay above its manual build 6, and the push builds so far used run number + 100, so keep its offset at 100 or higher; never lower it. Team and RiskMandate start fresh, and 100 is fine for them.
- The run number only grows, and both jobs of one run use the same number, so the .ipa artifact and the TestFlight build match. The run number is shared by all apps in a run, so an app's numbers skip but still only grow.
- App Store Connect rejects a build number already used for the same version. If that happens (for example after uploading from Xcode by hand with a higher number), raise that app's offset variable in **Settings → Secrets and variables → Actions → Variables**, or run the workflow by hand with **app** and **build_number** set.
- The export option `manageAppVersionAndBuildNumber` is `false`, so App Store Connect does not renumber the build.

## Step 1. Apple Developer portal (developer.apple.com → Certificates, IDs & Profiles)

1. **App ID** `news.promptugal.reader` (explicit, not wildcard). It probably exists already from Silvio's Xcode installs. Enable these capabilities:
   - **App Groups**, then assign the group `group.news.promptugal.reader` (create it under Identifiers → App Groups first).
   - **Associated Domains** (the app uses only `webcredentials:promptugal.news`, for passkeys; `applinks` was removed for App Review, so the app claims no universal links). The website must also serve `/.well-known/apple-app-site-association` with the team ID and bundle id, or passkeys and links will not work.
   - **In-App Purchase** is on for every explicit App ID. It has no entitlement key. The products themselves are created in App Store Connect.
   - **NFC Tag Reading**: not used today. Enable it only if a session adds Core NFC.
   - **Time Sensitive Notifications** (the app has `com.apple.developer.usernotifications.time-sensitive`, for session reminders). Without it on the App ID and in the profile, the signed archive fails.
   - Push Notifications: not needed for local reminders. Enable it only if remote push is added.
2. **Extensions.** The platform branch has two, each needing its own explicit App ID with **App Groups** on and the group `group.news.promptugal.reader` assigned, and its own App Store profile:
   - `news.promptugal.reader.widgets`: the widget extension (target `PrompTugalWidgets`), profile secret `IOS_PROFILE_WIDGETS_BASE64`.
   - `news.promptugal.reader.intents`: the App Intents extension (target `PrompTugalIntents`), profile secret `IOS_PROFILE_INTENTS_BASE64`.
   - A share extension, if one is added later, uses `IOS_PROFILE_SHARE_BASE64`.
   The workflow reads the bundle id from each profile and matches it to the target with the same bundle id, so profile names do not matter. Every package run lists the targets to sign and the secret each one needs under **Targets to sign** in its summary. If a profile is missing, the signed job stops and names it.
3. **Certificate** (only for manual signing, the default). Create an **Apple Distribution** certificate: Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority, save to disk, upload the CSR, download the `.cer`, double-click it, then in Keychain Access → My Certificates, right-click it → Export → `.p12` with a strong password. A team can have only a few distribution certificates, so reuse an existing one if you have its private key. It is valid for one year.
4. **Provisioning profiles.** Profiles → + → **App Store Connect** (Distribution) → App ID `news.promptugal.reader` → the distribution certificate → name it `PrompTugal App Store`. Download it. Repeat for `news.promptugal.reader.widgets` and `news.promptugal.reader.intents`: three profiles in all. Recreate it whenever you add a capability or renew the certificate, and update the secret.

## Step 2. App Store Connect (appstoreconnect.apple.com)

1. **App record.** Apps → + → New App, platform iOS, bundle id `news.promptugal.reader`, SKU of your choice. Skip if it exists.
2. **API key.** Users and Access → Integrations → App Store Connect API → Team Keys → +. Role:
   - **App Manager** is enough for manual signing and uploads.
   - **Admin** is needed for automatic signing, because Xcode creates profiles and uses a cloud-managed distribution certificate.
   Download the `.p8` (only once). Note the **Key ID** and the **Issuer ID** (top of the page).
3. **TestFlight group.** TestFlight → Internal Testing → + → a group (for example "Team"), with **Enable automatic distribution** on, so every processed build reaches the team without a click. Add the team as App Store Connect users (any role, for example Marketing or Customer Support) and add them to the group.

## Step 3. GitHub secrets (repo → Settings → Secrets and variables → Actions)

Make the base64 on a Mac with `base64 -i <file> | pbcopy` and paste it as the secret value. Nothing else is needed: no line breaks to remove, no quotes.

| Secret | Value | Needed for |
| --- | --- | --- |
| `ASC_KEY_ID` | Key ID, 10 characters | always |
| `ASC_ISSUER_ID` | Issuer ID (a UUID) | always |
| `ASC_KEY_P8_BASE64` | `base64 -i AuthKey_<KEYID>.p8` | always |
| `IOS_DIST_CERT_P12_BASE64` | `base64 -i distribution.p12` | manual signing |
| `IOS_DIST_CERT_PASSWORD` | the .p12 export password | manual signing |

Profiles are per app, because each app has its own App IDs. The name is `IOS_PROFILE_<APP>_<PART>_BASE64`, with `<PART>` = `APP` (the app itself), `WIDGETS`, `INTENTS` or `SHARE` (extensions), all for manual signing:

| App | Secrets |
| --- | --- |
| PrompTugal | `IOS_PROFILE_PROMPTUGAL_APP_BASE64`, `IOS_PROFILE_PROMPTUGAL_WIDGETS_BASE64`, `IOS_PROFILE_PROMPTUGAL_INTENTS_BASE64` |
| Team | `IOS_PROFILE_TEAM_APP_BASE64` (and an extension secret if Team gets an extension) |
| RiskMandate | none (no upload) |

For the app with bundle `news.promptugal.reader` the older names `IOS_PROFILE_APP_BASE64`, `IOS_PROFILE_WIDGETS_BASE64`, `IOS_PROFILE_INTENTS_BASE64` and `IOS_PROFILE_SHARE_BASE64` still work, so secrets you already added keep working. They are only ever read for that bundle, so a PrompTugal profile can never be installed for Team. CI also refuses a profile whose bundle ID is not the app's, and says which secret is wrong.

Variables (not secret), under the **Variables** tab:

| Variable | Value | Needed for |
| --- | --- | --- |
| `APPLE_TEAM_ID` | 10-character team ID (Membership page) | automatic signing; manual reads it from the profile |
| `IOS_BUILD_OFFSET` | default `100`, for every app | optional |
| `IOS_BUILD_OFFSET_PROMPTUGAL`, `_TEAM`, `_RISKMANDATE` | build-number offset of one app; wins over `IOS_BUILD_OFFSET` | optional |
| `TESTFLIGHT_ON_PUSH`, `TESTFLIGHT_ON_PUSH_<APP>` | `false` pauses push uploads (all apps, or one) | optional |

The secrets can live at repository level or in an environment called `testflight`. The job uses that environment, so you can add a required reviewer to it in **Settings → Environments** if you want a human to approve every upload.

The scripts never print a secret value. The keychain password is random per run and masked. The temporary keychain, the profiles and the key file are deleted at the end of the job, even when it fails.

## Step 4. Upload a build to TestFlight

Either:

- **By hand:** Actions → **iOS release** → Run workflow → pick the branch (normally `dev`) → choose **app** → tick **upload** → Run. Leave **signing** on `auto`.
- **By tag:** `git tag promptugal-v0.3.2 && git push origin promptugal-v0.3.2` (on the commit you want). Tags never cancel half way.

Other inputs for a manual run:

- **app:** `all` or one of `team`, `promptugal`, `riskmandate`.
- **dry_run:** signs, checks every profile against its target's entitlements, and exports the App Store .ipa as an artifact, but does not upload. Use it first, right after adding the secrets. A missing capability shows as a ❌ row naming the entitlement, before the archive starts.
- **internal_only:** sets `testFlightInternalTestingOnly`. That build can then only go to internal testers, never to external testers or the App Store. Leave it off unless you want that guarantee.
- **source_ref:** builds another branch (for example `night/platform`) with the release scripts from the branch you run on.
- **build_number:** overrides the build number (for every app the run covers; pick one **app** when you use it).

Pushes to branches never upload. (A manual run on a branch can.) After the job is green, App Store Connect processes the build in 5–30 minutes. You get an email, and with automatic distribution the internal group sees it in the TestFlight app.

After the upload, the job waits up to 20 minutes for processing, then uses the API key (`scripts/release/asc.py`, Python standard library and `openssl`) to:

- answer export compliance for the build (`usesNonExemptEncryption = false`) if Info.plist does not already;
- set TestFlight's **What to Test** to release notes made from `git log` since the previous `ios-v*` tag (`scripts/release/release-notes.sh`).

If processing takes longer, these steps give up without failing the job. The build still arrives.

## Step 4b. Submit to the App Store (later)

Workflow **iOS App Store submit** (`.github/workflows/ios-submit.yml`), by hand only, on a Linux runner:

1. In App Store Connect, create the version (for example 0.4.0) and fill in the metadata, screenshots for iPhone and iPad, privacy answers and review notes. The workflow does not touch these.
2. Actions → **iOS App Store submit** → version and build number → Run. Without **confirm** it is a dry run that prints the plan.
3. Run again with **confirm** ticked. It waits for processing, answers export compliance, attaches the build to the version, and creates and submits a review submission.

It uses the same three `ASC_*` secrets. It runs in an environment called `app-store`, where you can add a required reviewer.

### Two signing modes

| | Manual (default when the .p12 secrets exist) | Automatic (`signing: automatic`, or only the API key set) |
| --- | --- | --- |
| Secrets | API key + .p12 + profile(s) | API key + `APPLE_TEAM_ID` |
| How | Imports the .p12 into a temporary keychain, installs the App Store profiles, archives with `CODE_SIGN_STYLE=Manual`, `CODE_SIGN_IDENTITY="Apple Distribution"`, exports with `signingStyle manual` and the profile map | `xcodebuild archive -allowProvisioningUpdates -authenticationKeyPath … -authenticationKeyID … -authenticationKeyIssuerID …`; Xcode creates or downloads the profiles and exports with a cloud-managed distribution certificate |
| Good | Predictable, works with an App Manager key, nothing created in the portal by CI | Fewer secrets, no yearly certificate or profile renewal in GitHub |
| Watch out | Renew the certificate and profile yearly and when capabilities change, then update the secrets | Key must be Admin. Archiving may create an Apple Development certificate on the runner each run, and a team has a limit on those. Import a .p12 too to avoid that. |

Both modes upload with `xcodebuild -exportArchive` with `destination = upload` and the API key flags. The fallback `UPLOAD_TOOL=altool` uses `xcrun altool --upload-package` (or `--upload-app`, which Apple has deprecated) with the same key. No third-party tools are used.

## Step 5. How testers install

- **Internal testers** (App Store Connect users, up to 100): install **TestFlight** from the App Store, accept the email invite, tap Install. No review needed. Builds appear as soon as processing finishes.
- **External testers** (anyone with an email or a public link, up to 10,000): add the build to an external group and fill in Test Information. The **first build of each version needs Beta App Review** (usually under a day). Later builds of the same version often go through without review.
- The same build installs on iPhone and iPad.

## Installing the unsigned builds (today, without TestFlight)

Quickest for tonight, in this order:

1. **Build from Xcode (recommended, as Silvio did).** Dinis has a paid Apple Developer account, so Xcode's automatic signing works with the full entitlements (App Groups, Associated Domains, Time Sensitive Notifications); the `PrompTugal-Basic.entitlements` fallback below is only for a free Apple ID. `git pull` on `dev`, open `PrompTugal.xcodeproj`, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and put your team ID in it, pick your iPhone or iPad, press Run. Xcode makes the three development profiles (app, widgets, intents) itself. With a free Apple ID, also set `PT_ENTITLEMENTS = Config/PrompTugal-Basic.entitlements` there: the app then runs without App Groups and associated domains, so widgets, the vault cache shared with widgets and passkeys will not work.
2. **Simulator, no Apple account:** download the `…-simulator-app` artifact from the latest green **iOS release** run on `dev`, unzip, `xcrun simctl install booted PrompTugal.app`, then `xcrun simctl launch booted news.promptugal.reader`.
3. **Re-sign the CI .ipa** (for a device without building). The app embeds two extensions, so sign inside-out: each extension with its own profile, then the app. You need three development or ad hoc profiles that include the device: `news.promptugal.reader`, `.widgets`, `.intents`.

   ```sh
   unzip PrompTugal-…-unsigned.ipa -d x && app=x/Payload/PrompTugal.app
   sign() {  # sign <bundle> <profile.mobileprovision>
     cp "$2" "$1/embedded.mobileprovision"
     security cms -D -i "$2" > p.plist
     /usr/libexec/PlistBuddy -x -c 'Print :Entitlements' p.plist > ent.plist
     codesign -f -s "Apple Development: Your Name" --entitlements ent.plist "$1"
   }
   sign "$app/PlugIns/PrompTugalWidgets.appex"  widgets.mobileprovision
   sign "$app/Extensions/PrompTugalIntents.appex" intents.mobileprovision
   sign "$app" app.mobileprovision
   codesign --verify --deep --strict "$app" && (cd x && zip -qry ../PrompTugal-signed.ipa Payload)
   ```
   Install with Finder (drag onto the device) or Xcode → Devices and Simulators. Check the folder names with `ls $app/PlugIns $app/Extensions` first; they follow the target names.
4. **From the archive:** unzip `…-xcarchive` into `~/Library/Developer/Xcode/Archives/` and use Organizer → Distribute App → Custom → Debugging. Xcode may refuse an archive built without signing; if it does, use option 1 or 3.

Once the TestFlight secrets are in, option 1 is only for developers; everyone else installs from TestFlight.

## Gotchas

- **Export compliance.** The app uses encryption only through Apple's frameworks: CryptoKit (AES-GCM, key derivation) for the vault, and HTTPS through URLSession. Apple's table says "Your app uses encryption limited to that within the Apple operating system → No documentation required", and the French declaration is only for algorithms not provided by the OS. So the answer is **`ITSAppUsesNonExemptEncryption = NO`** in Info.plist (requested from the platform session). With the key, uploads skip the question. Without it, each build sits in "Missing Compliance" until someone answers in App Store Connect. In the App Store Connect questions, answer that the app uses encryption limited to Apple's operating system. Whether a yearly BIS self-classification report is also needed is a legal call Apple leaves to the developer. Apple says it "might" be required, so check. If anyone adds their own crypto code or a crypto library, this answer changes.
- **Build numbers must be unique per version** and must grow. See above.
- **TestFlight builds expire after 90 days.** Upload at least every couple of months, or testers lose the app.
- **External testers need Beta App Review** for the first build of each version. Internal testers do not.
- **Capabilities and profiles must match.** Adding an entitlement (App Groups, Associated Domains, NFC, push) in the project without enabling it on the App ID and regenerating the profile fails the signed archive with "Provisioning profile doesn't include the … entitlement". Regenerate the profile and update its `IOS_PROFILE_*_BASE64` secret.
- **Certificates last one year, profiles last one year.** The job summary prints both expiry dates on every signed run.
- **iPhone and iPad.** `TARGETED_DEVICE_FAMILY = 1,2` must stay. The package job fails if it changes. The iPad needs all four orientations unless full screen is required, and App Review checks the iPad layout.
- **The website's `apple-app-site-association`** must list `<TEAMID>.news.promptugal.reader` under `webcredentials`, or passkey sign-in fails silently. The app no longer declares `applinks`, so no universal-link entry is needed.
- **Privacy manifest.** The app calls "required reason" APIs (`UserDefaults`, file timestamps) and has no `PrivacyInfo.xcprivacy` yet. App Store Connect rejects such uploads (ITMS-91053), TestFlight included. A draft with the reasons found in the code is in `scripts/release/templates/PrivacyInfo.xcprivacy` (requested from platform). Every package run warns while it is missing.
- **NFC.** The app has an NFC usage string but no Core NFC code yet. If NFC reading is added, enable **NFC Tag Reading** on the App ID, add the `com.apple.developer.nfc.readersession.formats` entitlement, and regenerate the profile.
- **Background fetch and processing** (`UIBackgroundModes`, `BGTaskSchedulerPermittedIdentifiers`) need no portal capability. **In-App Purchase** products for the meter top-up are created in App Store Connect → the app → In-App Purchases (the local `.storekit` file is for testing only). In TestFlight builds, purchases use the sandbox and testers are not charged.
