#!/usr/bin/env bash
# Select the newest stable Xcode on the runner, print it, and record it in
# the job summary. Set XCODE_APP=/Applications/Xcode_26.1.app to pin one.
set -euo pipefail
if [ -z "${XCODE_APP:-}" ]; then
  candidates=$(ls -d /Applications/Xcode_*.app 2>/dev/null | grep -viE 'beta|release_candidate|_rc' || true)
  [ -z "$candidates" ] && candidates=$(ls -d /Applications/Xcode*.app)
  XCODE_APP=$(echo "$candidates" | sort -V | tail -1)
fi
echo "Installed: $(ls -d /Applications/Xcode*.app | xargs -n1 basename | tr '\n' ' ')"
echo "Selecting $XCODE_APP"
sudo xcode-select -s "$XCODE_APP/Contents/Developer"
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
{
  echo "**Xcode:** \`$(xcodebuild -version | tr '\n' ' ')\` from \`$(basename "$XCODE_APP")\`, iOS SDK \`$(xcrun --sdk iphoneos --show-sdk-version)\`"
  echo
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
