#!/usr/bin/env bash
# Select the newest stable Xcode installed on the runner and print its version.
# Set XCODE_APP (e.g. /Applications/Xcode_26.1.app) to force one.
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
swift --version
{
  echo "**Xcode:** \`$(xcodebuild -version | tr '\n' ' ')\` from \`$(basename "$XCODE_APP")\`"
  echo
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
