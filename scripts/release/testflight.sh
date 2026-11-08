#!/usr/bin/env bash
# Signed archive -> App Store .ipa -> upload to App Store Connect (TestFlight).
# Run after signing-setup.sh. MODE is manual or automatic (see release-setup.md).
#
#   manual     the imported Apple Distribution certificate and the installed
#              App Store profiles; ExportOptions signingStyle manual.
#   automatic  Xcode signs with the API key (-allowProvisioningUpdates); export
#              uses a cloud-managed distribution certificate (key role Admin).
#              AUTO_ARCHIVE picks how the archive is signed: codesign (default: unsigned
#              archive, each bundle signed with codesign and its entitlements, no
#              Apple Development certificate; distribution and adhoc are refused by
#              xcodebuild on this SDK), unsigned, or development (creates a development certificate
#              per run and so uses up the account's limit).
#
# Upload: xcodebuild -exportArchive with destination upload and the API key
# (UPLOAD_TOOL=xcodebuild, default) or xcrun altool (UPLOAD_TOOL=altool).
set -euo pipefail
set +x
. "$(dirname "$0")/lib.sh"
: "${MODE:?}" "${EXPECTED_BUNDLE:?}" "${BUILD_NUMBER:?}" "${ARTIFACT_BASE:?}" "${ASC_KEY_PATH:?}" "${APPLE_TEAM_ID:?}"
UPLOAD_TOOL=${UPLOAD_TOOL:-xcodebuild}
DD=$OUT/dd-signed
archive=$OUT/$APP_NAME-signed.xcarchive
export_dir=$OUT/export
mkdir -p "$export_dir" "$LOGS"
auth=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

summary ""
summary "### Signed archive ($MODE signing): $MARKETING_VERSION ($BUILD_NUMBER) · tag ${RELEASE_TAG:-none} · commit ${SHORT_SHA:-?}"

profile_for() { awk -F'\t' -v b="$1" '$1==b{print $2; exit}' "$OUT/profiles.tsv" 2>/dev/null; }

settings=(CURRENT_PROJECT_VERSION="$BUILD_NUMBER" MARKETING_VERSION="$MARKETING_VERSION" DEVELOPMENT_TEAM="$APPLE_TEAM_ID")
extra=()
if [ "$MODE" = manual ]; then
  "$(dirname "$0")/check-profiles.sh"
  # One profile per target, with no project change: a CI-only xcconfig sets
  # PROVISIONING_PROFILE_SPECIFIER = $(PT_PROFILE_$(TARGET_NAME)) and one
  # PT_PROFILE_<target> per signed target. Targets without a value (Swift
  # packages, tests) get an empty specifier, which is what they need.
  xc=$OUT/signing.xcconfig
  {
    echo "CODE_SIGN_STYLE = Manual"
    echo "CODE_SIGN_IDENTITY = Apple Distribution"
    echo "DEVELOPMENT_TEAM = $APPLE_TEAM_ID"
    echo 'PROVISIONING_PROFILE_SPECIFIER = $(PT_PROFILE_$(TARGET_NAME))'
    [ -n "${KEYCHAIN_PATH:-}" ] && echo "OTHER_CODE_SIGN_FLAGS = --keychain $KEYCHAIN_PATH"
  } > "$xc"
  missing=()
  while IFS=$'\t' read -r target bundle type _ent; do
    case "$type" in *application|*app-extension|*extensionkit-extension) ;; *) continue ;; esac
    pname=$(profile_for "$bundle")
    if [ -z "$pname" ]; then missing+=("$bundle ($target)"); continue; fi
    echo "PT_PROFILE_$target = $pname" >> "$xc"
    summary "- \`$target\` (\`$bundle\`) → profile \`$pname\`"
  done < <("$(dirname "$0")/targets.sh")
  if [ ${#missing[@]} -gt 0 ]; then
    for m in "${missing[@]}"; do
      echo "::error::no App Store profile installed for $m. Add it as a secret (see release-setup.md)."
      summary "- ❌ no profile for \`$m\`: add \`IOS_PROFILE_<APP|WIDGETS|INTENTS|SHARE>_BASE64\`"
    done
    exit 1
  fi
  extra+=(-xcconfig "$xc")
else
  case "${AUTO_ARCHIVE:-codesign}" in
    development)  # Xcode signs the archive itself; creates an Apple Development certificate per run
      extra+=(-allowProvisioningUpdates "${auth[@]}")
      settings+=(CODE_SIGN_STYLE=Automatic) ;;
    distribution) # automatic signing with the distribution identity: no development certificate
      extra+=(-allowProvisioningUpdates "${auth[@]}")
      settings+=(CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Distribution")
      summary "- Archive signed automatically with the distribution identity." ;;
    adhoc)        # ad-hoc signature that carries the entitlements; the export re-signs
      settings+=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO PROVISIONING_PROFILE_SPECIFIER=)
      summary "- Archive signed ad hoc with its entitlements; the export signs it for distribution." ;;
    codesign)     # unsigned archive, then each bundle is signed ad hoc with the codesign tool and its entitlements
      settings+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=)
      summary "- Archive built unsigned; bundles signed ad hoc with their entitlements before the export." ;;
    unsigned)     # no entitlements in the archive; the export adds only the basics
      settings+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=)
      summary "- Archive built unsigned." ;;
    *) echo "::error::unknown AUTO_ARCHIVE=$AUTO_ARCHIVE"; exit 1 ;;
  esac
fi

run_logged "Archive (signed)" "$LOGS/archive-signed.log" -- \
  xcodebuild archive \
    -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$archive" -derivedDataPath "$DD" \
    ${extra[@]+"${extra[@]}"} "${settings[@]}"

app=$(find "$archive/Products/Applications" -maxdepth 1 -name '*.app' | head -1)

if [ "$MODE" = automatic ] && [ "${AUTO_ARCHIVE:-codesign}" = codesign ]; then
  # xcodebuild refuses ad-hoc signing on this SDK, so use the codesign tool: innermost first
  # (frameworks, then each extension, then the app), each with its own entitlements file.
  "$(dirname "$0")/targets.sh" > "$OUT/targets-archive.tsv"
  sign_adhoc() {  # sign_adhoc <bundle>
    local b=$1 bid ent
    bid=$(plist_get "$b/Info.plist" CFBundleIdentifier)
    ent=$(awk -F'\t' -v x="$bid" '$2==x && $4!=""{print $4; exit}' "$OUT/targets-archive.tsv")
    if [ -n "$ent" ]; then
      [ -f "$(dirname "$PROJECT")/$ent" ] && ent="$(dirname "$PROJECT")/$ent"
      echo "codesign (ad hoc) $(basename "$b") with $ent"
      codesign --force --sign - --entitlements "$ent" "$b"
    else
      echo "codesign (ad hoc) $(basename "$b") without entitlements"
      codesign --force --sign - "$b"
    fi
  }
  while IFS= read -r f; do sign_adhoc "$f"; done < <(find "$app" -name '*.framework' -type d -prune)
  while IFS= read -r x; do sign_adhoc "$x"; done < <(find "$app/PlugIns" "$app/Extensions" -maxdepth 1 -name '*.appex' -type d 2>/dev/null)
  sign_adhoc "$app"
fi
# Never upload to the wrong App Store record: the archive must be the app apps.json names.
built=$(plist_get "$app/Info.plist" CFBundleIdentifier)
if [ "$built" != "$EXPECTED_BUNDLE" ]; then
  echo "::error::the archive is $built, but apps.json says this app is $EXPECTED_BUNDLE. Nothing exported or uploaded."
  summary "- ❌ bundle id mismatch: archive \`$built\`, apps.json \`$EXPECTED_BUNDLE\`. Nothing uploaded."
  exit 1
fi
summary "- Bundle id \`$built\` matches apps.json."
enc=$(plist_get "$app/Info.plist" ITSAppUsesNonExemptEncryption)
if [ "$enc" = "?" ]; then
  echo "::warning::Info.plist has no ITSAppUsesNonExemptEncryption; App Store Connect will ask the export compliance question for every build."
  summary "- ⚠️ \`ITSAppUsesNonExemptEncryption\` missing: each build waits for the export compliance answer in App Store Connect."
fi

# ExportOptions from the template, filled in for this run.
make_options() {  # make_options <destination> <out.plist>
  local dest=$1 plist=$2
  if [ "$MODE" = manual ]; then cp "$(dirname "$0")/ExportOptions-manual.plist" "$plist"
  else cp "$(dirname "$0")/ExportOptions-automatic.plist" "$plist"; fi
  /usr/libexec/PlistBuddy -c "Set :teamID $APPLE_TEAM_ID" -c "Set :destination $dest" "$plist"
  if [ "$MODE" = manual ]; then
    while IFS=$'\t' read -r bundle pname _uuid _team; do
      /usr/libexec/PlistBuddy -c "Add :provisioningProfiles:$bundle string $pname" "$plist"
    done < "$OUT/profiles.tsv"
  fi
  if [ "${INTERNAL_ONLY:-false}" = true ]; then
    /usr/libexec/PlistBuddy -c "Add :testFlightInternalTestingOnly bool true" "$plist"
  fi
}

opts=$OUT/ExportOptions-export.plist
make_options export "$opts"
eflags=()
[ "$MODE" = automatic ] && eflags+=(-allowProvisioningUpdates "${auth[@]}")
run_logged "Export App Store .ipa" "$LOGS/export.log" -- \
  xcodebuild -exportArchive -archivePath "$archive" -exportPath "$export_dir" \
    -exportOptionsPlist "$opts" ${eflags[@]+"${eflags[@]}"}

ipa=$(find "$export_dir" -maxdepth 1 -name '*.ipa' | head -1)
mv "$ipa" "$export_dir/$ARTIFACT_BASE-appstore.ipa"; ipa=$export_dir/$ARTIFACT_BASE-appstore.ipa
ipa_bundle=$(unzip -p "$ipa" 'Payload/*.app/Info.plist' | plutil -extract CFBundleIdentifier raw -o - -)
[ "$ipa_bundle" = "$EXPECTED_BUNDLE" ] || { echo "::error::the .ipa is $ipa_bundle, expected $EXPECTED_BUNDLE. Nothing uploaded."; exit 1; }
"$(dirname "$0")/report.sh" "$app" "$ipa"
# Show who signed the exported app (the archive itself may be unsigned).
tmp=$(mktemp -d); unzip -q "$ipa" 'Payload/*' -d "$tmp"
codesign -dvv "$tmp"/Payload/*.app 2>&1 | grep -E '^(Authority|TeamIdentifier|Identifier)=' | head -4 | sed 's/^/    /' || true
# Entitlements of the exported app and every extension. Every key the target's entitlements
# file declares must be in the signed export, or the build would break widgets, shared data,
# webcredentials. A missing key stops the run before any upload.
summary "#### Entitlements in the exported .ipa"
ent_dir=$(dirname "$PROJECT")
"$(dirname "$0")/targets.sh" > "$OUT/targets.tsv"
ent_fail=0
for b in "$tmp"/Payload/*.app "$tmp"/Payload/*.app/PlugIns/*.appex "$tmp"/Payload/*.app/Extensions/*.appex; do
  [ -e "$b" ] || continue
  bid=$(plist_get "$b/Info.plist" CFBundleIdentifier)
  codesign -d --entitlements :- "$b" 2>/dev/null | plutil -convert xml1 -o "$OUT/ent-got.plist" - 2>/dev/null || echo '<plist version="1.0"><dict/></plist>' > "$OUT/ent-got.plist"
  want=$(awk -F'\t' -v b="$bid" '$2==b && $4!=""{print $4; exit}' "$OUT/targets.tsv")
  echo "== entitlements: $(basename "$b") ($bid), declared in: ${want:-none}"
  plutil -p "$OUT/ent-got.plist" | sed 's/^/    /'
  summary "**$(basename "$b")** (\`$bid\`, declared in \`${want:-none}\`)"
  summary '```'; plutil -p "$OUT/ent-got.plist" | while IFS= read -r l; do summary "$l"; done; summary '```'
  if [ -n "$want" ]; then
    wf="$ent_dir/$want"; [ -f "$wf" ] || wf="$want"
    missing=$(python3 - "$wf" "$OUT/ent-got.plist" <<'PY'
import plistlib, sys
want = plistlib.load(open(sys.argv[1], "rb")); got = plistlib.load(open(sys.argv[2], "rb"))
print(" ".join(k for k in want if k not in got))
PY
)
    if [ -n "$missing" ]; then
      echo "::error::$(basename "$b") is missing entitlements declared in $want: $missing"
      summary "- ❌ missing in the export: $missing"
      ent_fail=1
    fi
  fi
done
rm -rf "$tmp"
[ "$ent_fail" = 0 ] || { summary "- ❌ entitlements missing in the export: nothing uploaded."; exit 1; }

if [ "${SKIP_UPLOAD:-false}" = true ]; then
  note "- Upload skipped (SKIP_UPLOAD=true). The signed .ipa is an artifact."
  exit 0
fi

# The record must exist for exactly this bundle id. An app without one (Team, before Dinis
# creates it) is skipped, not failed. Any other error stops here, before the upload.
BUNDLE_ID=$EXPECTED_BUNDLE python3 "$(dirname "$0")/asc.py" has-record && rec=0 || rec=$?
if [ "$rec" = 3 ]; then
  note "Not uploaded: no App Store Connect record for $EXPECTED_BUNDLE yet."
  exit 0
elif [ "$rec" != 0 ]; then
  exit "$rec"
fi

case "$UPLOAD_TOOL" in
  xcodebuild)
    up=$OUT/ExportOptions-upload.plist
    make_options upload "$up"
    run_logged "Upload to App Store Connect (xcodebuild)" "$LOGS/upload.log" -- \
      xcodebuild -exportArchive -archivePath "$archive" -exportPath "$OUT/upload" \
        -exportOptionsPlist "$up" -allowProvisioningUpdates "${auth[@]}"
    ;;
  altool)
    if [ -n "${ASC_APP_ID:-}" ]; then
      run_logged "Upload to App Store Connect (altool --upload-package)" "$LOGS/upload.log" -- \
        xcrun altool --upload-package "$ipa" --platform ios --apple-id "$ASC_APP_ID" \
          --bundle-id "$EXPECTED_BUNDLE" --bundle-version "$BUILD_NUMBER" \
          --bundle-short-version-string "$MARKETING_VERSION" \
          --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID"
    else
      run_logged "Upload to App Store Connect (altool --upload-app)" "$LOGS/upload.log" -- \
        xcrun altool --upload-app -f "$ipa" -t ios --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID"
    fi
    ;;
  *) echo "::error::UPLOAD_TOOL must be xcodebuild or altool"; exit 1 ;;
esac

note ""
note "✅ Uploaded $MARKETING_VERSION ($BUILD_NUMBER). App Store Connect processes it in 5–30 minutes; then it appears in TestFlight for the internal group."
