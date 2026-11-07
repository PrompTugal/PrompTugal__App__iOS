#!/usr/bin/env bash
# Unsigned packaging. Needs no Apple account, so it runs on every push.
#
#   1. xcodebuild archive for generic/platform=iOS, signing off  -> .xcarchive
#   2. Payload/PrompTugal.app zipped                              -> unsigned .ipa
#   3. Release build for the iOS Simulator                        -> .app zip
#   4. Info.plist values and a size breakdown in the job summary
#
# Expects version.sh to have run (MARKETING_VERSION, BUILD_NUMBER, ARTIFACT_BASE).
# Output in $OUT/dist.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

: "${BUILD_NUMBER:?run version.sh first}" "${ARTIFACT_BASE:?run version.sh first}"
DIST=$OUT/dist
DD=${DERIVED_DATA:-$OUT/dd}
mkdir -p "$DIST" "$LOGS"
archive=$OUT/$APP_NAME.xcarchive
rm -rf "$archive"

unsigned=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" CODE_SIGN_ENTITLEMENTS="" DEVELOPMENT_TEAM="")

summary "## Unsigned build"
run_logged "Archive (generic/platform=iOS, unsigned)" "$LOGS/archive-unsigned.log" -- \
  xcodebuild archive \
    -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$archive" -derivedDataPath "$DD" \
    "${unsigned[@]}" CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

app=$(find "$archive/Products/Applications" -maxdepth 1 -name '*.app' | head -1)
[ -d "$app" ] || { echo "::error::no .app in $archive/Products/Applications"; exit 1; }

# Unsigned .ipa: Payload/<App>.app, zipped. Re-sign before installing (see release-setup.md).
stage=$OUT/ipa-stage; rm -rf "$stage"; mkdir -p "$stage/Payload"
ditto "$app" "$stage/Payload/$(basename "$app")"
ipa=$DIST/$ARTIFACT_BASE-unsigned.ipa
(cd "$stage" && zip -qry --symlinks "$ipa" Payload)

# The archive itself (with dSYMs), for re-signing or symbolication later.
ditto -c -k --sequesterRsrc --keepParent "$archive" "$DIST/$ARTIFACT_BASE.xcarchive.zip"

# Simulator app.
run_logged "Release build (iOS Simulator)" "$LOGS/build-simulator.log" -- \
  xcodebuild build \
    -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" \
    "${unsigned[@]}" CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
simapp=$(find "$DD/Build/Products/Release-iphonesimulator" -maxdepth 1 -name '*.app' | head -1)
ditto -c -k --sequesterRsrc --keepParent "$simapp" "$DIST/$ARTIFACT_BASE-simulator.app.zip"

"$(dirname "$0")/report.sh" "$app" "$ipa"

summary ""
summary "### Files"
summary ""
summary "| File | Size |"
summary "| --- | ---: |"
for f in "$DIST"/*; do summary "| \`$(basename "$f")\` | $(human "$(bytes "$f")") |"; done
summary ""
summary "Simulator: unzip, then \`xcrun simctl install booted $APP_NAME.app\`. Device: re-sign the unsigned .ipa first (docs: \`briefs/2026-11-08__overnight-push/release-setup.md\`)."
ls -la "$DIST"
