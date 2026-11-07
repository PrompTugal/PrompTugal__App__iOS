#!/usr/bin/env bash
# Signed archive -> App Store .ipa -> upload to App Store Connect (TestFlight).
# Run after signing-setup.sh. MODE is manual or automatic (see release-setup.md).
#
#   manual     the imported Apple Distribution certificate and the installed
#              App Store profiles; ExportOptions signingStyle manual.
#   automatic  Xcode signs with the API key (-allowProvisioningUpdates); export
#              uses a cloud-managed distribution certificate (key role Admin).
#
# Upload: xcodebuild -exportArchive with destination upload and the API key
# (UPLOAD_TOOL=xcodebuild, default) or xcrun altool (UPLOAD_TOOL=altool).
set -euo pipefail
set +x
. "$(dirname "$0")/lib.sh"
: "${MODE:?}" "${BUILD_NUMBER:?}" "${ARTIFACT_BASE:?}" "${ASC_KEY_PATH:?}" "${APPLE_TEAM_ID:?}"
UPLOAD_TOOL=${UPLOAD_TOOL:-xcodebuild}
DD=$OUT/dd-signed
archive=$OUT/$APP_NAME-signed.xcarchive
export_dir=$OUT/export
mkdir -p "$export_dir" "$LOGS"
auth=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

summary ""
summary "### Signed archive ($MODE signing), $MARKETING_VERSION ($BUILD_NUMBER)"

profile_for() { awk -F'\t' -v b="$1" '$1==b{print $2; exit}' "$OUT/profiles.tsv" 2>/dev/null; }

settings=(CURRENT_PROJECT_VERSION="$BUILD_NUMBER" DEVELOPMENT_TEAM="$APPLE_TEAM_ID")
extra=()
if [ "$MODE" = manual ]; then
  app_profile=$(profile_for news.promptugal.reader)
  settings+=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Distribution")
  [ -n "${KEYCHAIN_PATH:-}" ] && settings+=(OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN_PATH")
  # Per-target profiles. The project reads PT_PROFILE_<SLOT> in each target's
  # settings (requested from the platform session); until it does, set the
  # app's profile for every target, which works while the app has no
  # extensions and its packages are static libraries.
  if grep -rqs 'PT_PROFILE_APP' Config "$PROJECT/project.pbxproj"; then
    settings+=(PT_PROFILE_APP="$app_profile")
    for slot in WIDGET INTENTS SHARE; do
      b=$(awk -F'\t' -v s="$slot" 'BEGIN{m["WIDGET"]="widget";m["INTENTS"]="intents";m["SHARE"]="share"} $1 ~ ("\\." m[s] "$"){print $2; exit}' "$OUT/profiles.tsv")
      [ -n "$b" ] && settings+=(PT_PROFILE_$slot="$b")
    done
    summary "- Profiles passed per target (PT_PROFILE_*)."
  else
    settings+=(PROVISIONING_PROFILE_SPECIFIER="$app_profile")
    summary "- Profile passed for all targets (project has no PT_PROFILE_APP yet)."
  fi
else
  extra+=(-allowProvisioningUpdates "${auth[@]}")
  settings+=(CODE_SIGN_STYLE=Automatic)
fi

run_logged "Archive (signed)" "$LOGS/archive-signed.log" -- \
  xcodebuild archive \
    -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$archive" -derivedDataPath "$DD" \
    ${extra[@]+"${extra[@]}"} "${settings[@]}"

app=$(find "$archive/Products/Applications" -maxdepth 1 -name '*.app' | head -1)
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
"$(dirname "$0")/report.sh" "$app" "$ipa"
codesign -dvv "$app" 2>&1 | grep -E '^(Authority|TeamIdentifier|Identifier)=' | head -4 | sed 's/^/    /'

if [ "${SKIP_UPLOAD:-false}" = true ]; then
  note "- Upload skipped (SKIP_UPLOAD=true). The signed .ipa is an artifact."
  exit 0
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
          --bundle-id news.promptugal.reader --bundle-version "$BUILD_NUMBER" \
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
