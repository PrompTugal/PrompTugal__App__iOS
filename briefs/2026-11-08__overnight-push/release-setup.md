# Release setup: from CI build to TestFlight

> What Dinis does once, in the Apple Developer portal, App Store Connect and GitHub, so the `iOS release` workflow signs PrompTugal and uploads it to TestFlight with no code changes. Also covers how to install the unsigned builds CI makes today.

Owner: release engineering (`night/release`) · Workflow: `.github/workflows/ios-release.yml` · Scripts: `scripts/release/`

## What CI does today, with no keys

Every push to `dev` or `night/**` runs the **package** job of `iOS release` on a macOS runner with the newest stable Xcode. It produces four artifacts, named `PrompTugal-<version>-<build>-<sha>-…`:

| Artifact | What it is | Use |
| --- | --- | --- |
| `…-unsigned-ipa` | `Payload/PrompTugal.app`, zipped, not signed | Re-sign and install on a device (below) |
| `…-simulator-app` | Release build for the iOS Simulator | `xcrun simctl install booted PrompTugal.app` |
| `…-xcarchive` | The archive, with dSYMs | Re-sign, or symbolicate crash logs |
| `build-info` | `build-info.json`: version, build, commit, sizes | Size checks and the website |

The job summary lists the Info.plist values (bundle id, version, build, minimum iOS, SDK, device family) and a size breakdown. The job fails if the app is not built for both iPhone and iPad (`UIDeviceFamily` must be `1,2`).

The **testflight** job runs only when someone starts it by hand with **upload** ticked, or on a tag `ios-v*`. Without secrets it does nothing and writes one `skipped: secret X missing` line per missing secret.

## Version and build numbers

- **Version** (`CFBundleShortVersionString`) is `MARKETING_VERSION` in the Xcode project. Change it in Xcode (target → General → Version) when you start a new release. CI never changes it.
- **Build** (`CFBundleVersion`) is set by CI on the `xcodebuild` command line: `CURRENT_PROJECT_VERSION = <run number of iOS release> + IOS_BUILD_OFFSET`. The offset is a repository variable, default `100`, so CI builds sort above the builds uploaded by hand from Xcode (build 4 and earlier).
- The run number only grows, and both jobs of one run use the same number, so the .ipa artifact and the TestFlight build match.
- App Store Connect rejects a build number already used for the same version. If that happens (for example after uploading from Xcode by hand with a higher number), raise `IOS_BUILD_OFFSET` in **Settings → Secrets and variables → Actions → Variables**, or run the workflow by hand with **build_number** set.
- The export option `manageAppVersionAndBuildNumber` is `false`, so App Store Connect does not renumber the build.

## Step 1. Apple Developer portal (developer.apple.com → Certificates, IDs & Profiles)

1. **App ID** `news.promptugal.reader` (explicit, not wildcard). It probably exists already from Silvio's Xcode installs. Enable these capabilities:
   - **App Groups**, then assign the group `group.news.promptugal.reader` (create it under Identifiers → App Groups first).
   - **Associated Domains** (the app uses `webcredentials:promptugal.news` and `applinks:promptugal.news`). The website must also serve `/.well-known/apple-app-site-association` with the team ID and bundle id, or passkeys and links will not work.
   - **In-App Purchase** is on for every explicit App ID. It has no entitlement key. The products themselves are created in App Store Connect.
   - **NFC Tag Reading**: not used today. Enable it only if a session adds Core NFC.
   - Push Notifications: not needed for local reminders. Enable it only if remote push is added.
2. **Extensions.** There are none yet. When the platform session adds a widget, intents or share extension, each one needs its own App ID (for example `news.promptugal.reader.widget`) with App Groups and the same group, and its own App Store profile. The workflow installs up to three extension profiles (`IOS_PROFILE_WIDGET_BASE64`, `IOS_PROFILE_INTENTS_BASE64`, `IOS_PROFILE_SHARE_BASE64`) and reads the bundle id from each profile, so their exact names do not matter.
3. **Certificate** (only for manual signing, the default). Create an **Apple Distribution** certificate: Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority, save to disk, upload the CSR, download the `.cer`, double-click it, then in Keychain Access → My Certificates, right-click it → Export → `.p12` with a strong password. A team can have only a few distribution certificates, so reuse an existing one if you have its private key. It is valid for one year.
4. **Provisioning profile.** Profiles → + → **App Store Connect** (Distribution) → App ID `news.promptugal.reader` → the distribution certificate → name it `PrompTugal App Store`. Download it. Recreate it whenever you add a capability or renew the certificate, and update the secret.

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
| `IOS_PROFILE_APP_BASE64` | `base64 -i PrompTugal_App_Store.mobileprovision` | manual signing |
| `IOS_PROFILE_WIDGET_BASE64`, `IOS_PROFILE_INTENTS_BASE64`, `IOS_PROFILE_SHARE_BASE64` | extension profiles | only once those extensions exist |

Variables (not secret), under the **Variables** tab:

| Variable | Value | Needed for |
| --- | --- | --- |
| `APPLE_TEAM_ID` | 10-character team ID (Membership page) | automatic signing; manual reads it from the profile |
| `IOS_BUILD_OFFSET` | default `100` | optional |

The secrets can live at repository level or in an environment called `testflight`. The job uses that environment, so you can add a required reviewer to it in **Settings → Environments** if you want a human to approve every upload.

The scripts never print a secret value. The keychain password is random per run and masked. The temporary keychain, the profiles and the key file are deleted at the end of the job, even when it fails.

## Step 4. Upload a build to TestFlight

Either:

- **By hand:** Actions → **iOS release** → Run workflow → pick the branch (normally `dev`) → tick **upload** → Run. Leave **signing** on `auto`.
- **By tag:** `git tag ios-v0.3.1 && git push origin ios-v0.3.1` (on the commit you want). Tags never cancel half way.

Pushes to branches never upload. After the job is green, App Store Connect processes the build in 5–30 minutes. You get an email, and with automatic distribution the internal group sees it in the TestFlight app.

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

- **Simulator:** download `…-simulator-app`, unzip, `xcrun simctl install booted PrompTugal.app`, then `xcrun simctl launch booted news.promptugal.reader`.
- **Device, from the archive (easiest):** unzip `…-xcarchive` into `~/Library/Developer/Xcode/Archives/`. It appears in Xcode → Organizer. **Distribute App → Custom → Release Testing** (or Debugging) re-signs it with your own team and profile. Then drag the .ipa onto the device in Finder or Xcode → Devices and Simulators.
- **Device, from the .ipa:** re-sign with Apple's tools. Install a development or ad hoc profile for `news.promptugal.reader` (or your own bundle id) that includes your device, then:

  ```sh
  unzip PrompTugal-…-unsigned.ipa -d x
  cp my.mobileprovision x/Payload/PrompTugal.app/embedded.mobileprovision
  security cms -D -i my.mobileprovision > p.plist
  /usr/libexec/PlistBuddy -x -c 'Print :Entitlements' p.plist > ent.plist
  codesign -f -s "Apple Development: Your Name" --entitlements ent.plist x/Payload/PrompTugal.app
  (cd x && zip -qry ../PrompTugal-signed.ipa Payload)
  ```
  Then install it via Finder or Xcode → Devices. Sign any frameworks under `Payload/PrompTugal.app/Frameworks` first (there are none today). A free Apple ID cannot sign App Groups or Associated Domains: use `Config/PrompTugal-Basic.entitlements`-style empty entitlements, and the vault and passkeys will not work.
- Building from Xcode, as Silvio did, still works and is still the quickest for a single device.

## Gotchas

- **Export compliance.** The app uses encryption only through Apple's frameworks: CryptoKit (AES-GCM, key derivation) for the vault, and HTTPS through URLSession. Apple's table says "Your app uses encryption limited to that within the Apple operating system → No documentation required", and the French declaration is only for algorithms not provided by the OS. So the answer is **`ITSAppUsesNonExemptEncryption = NO`** in Info.plist (requested from the platform session). With the key, uploads skip the question. Without it, each build sits in "Missing Compliance" until someone answers in App Store Connect. In the App Store Connect questions, answer that the app uses encryption limited to Apple's operating system. Whether a yearly BIS self-classification report is also needed is a legal call Apple leaves to the developer. Apple says it "might" be required, so check. If anyone adds their own crypto code or a crypto library, this answer changes.
- **Build numbers must be unique per version** and must grow. See above.
- **TestFlight builds expire after 90 days.** Upload at least every couple of months, or testers lose the app.
- **External testers need Beta App Review** for the first build of each version. Internal testers do not.
- **Capabilities and profiles must match.** Adding an entitlement (App Groups, Associated Domains, NFC, push) in the project without enabling it on the App ID and regenerating the profile fails the signed archive with "Provisioning profile doesn't include the … entitlement". Regenerate the profile and update `IOS_PROFILE_APP_BASE64`.
- **Certificates last one year, profiles last one year.** The job summary prints both expiry dates on every signed run.
- **iPhone and iPad.** `TARGETED_DEVICE_FAMILY = 1,2` must stay. The package job fails if it changes. The iPad needs all four orientations unless full screen is required, and App Review checks the iPad layout.
- **The website's `apple-app-site-association`** must list `<TEAMID>.news.promptugal.reader` for `webcredentials` and `applinks`, or passkeys and universal links fail silently.
- **Privacy manifest.** Apple requires `PrivacyInfo.xcprivacy` declaring "required reason" APIs (for example `UserDefaults`, file timestamps). An upload without it gets a warning email now and can be rejected at review.
