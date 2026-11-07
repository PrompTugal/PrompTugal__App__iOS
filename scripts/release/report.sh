#!/usr/bin/env bash
# report.sh <path/to/App.app> [path/to/App.ipa]
# Writes the app's Info.plist values and a size breakdown to the job summary,
# and fails if the app is not built for both iPhone and iPad.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
app=$1; ipa=${2:-}
plist=$app/Info.plist

families=$(/usr/libexec/PlistBuddy -c "Print :UIDeviceFamily" "$plist" 2>/dev/null | tr -d ' ' | grep -E '^[0-9]+$' | sort | tr '\n' ',' | sed 's/,$//')
summary ""
summary "### Info.plist"
summary ""
summary "| Key | Value |"
summary "| --- | --- |"
for k in CFBundleIdentifier CFBundleDisplayName CFBundleShortVersionString CFBundleVersion MinimumOSVersion DTPlatformVersion DTSDKName DTXcode DTXcodeBuild ITSAppUsesNonExemptEncryption; do
  summary "| \`$k\` | \`$(plist_get "$plist" "$k")\` |"
done
summary "| \`UIDeviceFamily\` | \`$families\` (1 = iPhone, 2 = iPad) |"

exe=$(plist_get "$plist" CFBundleExecutable)
total=$(bytes "$app")
summary ""
summary "### Size"
summary ""
summary "| Part | Size | Share |"
summary "| --- | ---: | ---: |"
row() { local n=$1 b=$2; [ "$b" -gt 0 ] || return 0; summary "| $n | $(human "$b") | $(awk -v b="$b" -v t="$total" 'BEGIN{printf "%.1f%%", 100*b/t}') |"; }
row "Executable \`$exe\`" "$(bytes "$app/$exe")"
[ -d "$app/Frameworks" ] && row "Frameworks/" "$(bytes "$app/Frameworks")"
[ -d "$app/PlugIns" ] && row "PlugIns/ (extensions)" "$(bytes "$app/PlugIns")"
[ -f "$app/Assets.car" ] && row "Assets.car (asset catalog)" "$(bytes "$app/Assets.car")"
known=$(( $(bytes "$app/$exe") + $( [ -d "$app/Frameworks" ] && bytes "$app/Frameworks" || echo 0) + $( [ -d "$app/PlugIns" ] && bytes "$app/PlugIns" || echo 0) + $( [ -f "$app/Assets.car" ] && bytes "$app/Assets.car" || echo 0) ))
row "Everything else" "$((total - known))"
summary "| **App bundle total** | **$(human "$total")** | |"
[ -n "$ipa" ] && [ -f "$ipa" ] && summary "| .ipa (zipped download) | $(human "$(bytes "$ipa")") | |"
summary ""
summary "<details><summary>Largest 10 files</summary>"
summary ""
summary '```'
find "$app" -type f -print0 | xargs -0 stat -f '%z %N' | sort -rn | head -10 \
  | while read -r b p; do printf '%10s  %s\n' "$(human "$b")" "${p#$app/}"; done >> "$SUMMARY"
summary '```'
summary "</details>"

# Machine-readable size record for the regression check and the website.
mkdir -p "$OUT/dist"
cat > "$OUT/dist/build-info.json" <<JSON
{
  "app": "$(plist_get "$plist" CFBundleIdentifier)",
  "version": "$(plist_get "$plist" CFBundleShortVersionString)",
  "build": "$(plist_get "$plist" CFBundleVersion)",
  "commit": "${SOURCE_SHA:-${GITHUB_SHA:-unknown}}",
  "ref": "${GITHUB_REF_NAME:-unknown}",
  "run": "${GITHUB_SERVER_URL:-}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-}",
  "builtAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "xcode": "$(plist_get "$plist" DTXcode)",
  "sdk": "$(plist_get "$plist" DTSDKName)",
  "minimumOS": "$(plist_get "$plist" MinimumOSVersion)",
  "deviceFamily": [${families}],
  "appBytes": $total,
  "ipaBytes": $( [ -n "$ipa" ] && [ -f "$ipa" ] && bytes "$ipa" || echo 0 ),
  "executableBytes": $(bytes "$app/$exe")
}
JSON

if [ "$families" != "1,2" ]; then
  echo "::error::UIDeviceFamily is '$families'; the app must be built for iPhone and iPad (1,2)."
  summary "❌ UIDeviceFamily is \`$families\`, expected \`1,2\` (iPhone and iPad)."
  exit 1
fi
