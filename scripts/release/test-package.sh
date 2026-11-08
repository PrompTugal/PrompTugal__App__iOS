#!/usr/bin/env bash
# test-package.sh <package dir> <simulator udid or empty>
# Runs one local Swift package's tests.
#   SGitVault is pure Swift and runs on the Mac host: swift test (as before the split).
#   The other packages are iOS-only, so they run through xcodebuild on a simulator.
set -euo pipefail
dir=${1:?package dir}; udid=${2:-}
name=$(basename "$dir")
[ -f "$dir/Package.swift" ] || { echo "### ⏭️ $name: no Package.swift, skipped" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"; exit 0; }
[ -d "$dir/Tests" ] || { echo "### ⏭️ $name: no Tests/ folder, skipped" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"; exit 0; }
logs=${RUNNER_TEMP:-/tmp}/logs; mkdir -p "$logs"
root=$PWD
cd "$dir"
if [ "$name" = SGitVault ] || [ -z "$udid" ]; then
  "$root/.github/scripts/run-and-summarize.sh" "$name swift test" "$logs/$name.log" -- swift test
else
  # The scheme of a package with several products is "<Name>-Package", with one it is "<Name>".
  scheme=$name
  xcodebuild -list -json 2>/dev/null | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin)["workspace"]["schemes"]))' | grep -qx "$name-Package" && scheme="$name-Package"
  "$root/.github/scripts/run-and-summarize.sh" "$name tests (simulator)" "$logs/$name.log" -- \
    xcodebuild test -scheme "$scheme" -destination "id=$udid" \
      -derivedDataPath "${RUNNER_TEMP:-/tmp}/dd-$name" -parallel-testing-enabled NO \
      CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
fi
