#!/usr/bin/env bash
# check-embedded.sh <App.app>
# Every app-extension target of the project must be embedded in the built app, or
# an archive would ship without it (a widget or intents extension that is silently
# missing). Which extensions to expect comes from the project itself, so each app
# is checked against its own list: PrompTugal has two, Team and RiskMandate none.
# Needs PROJECT. Release, iphoneos.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
app=${1:?usage: check-embedded.sh <App.app>}
expected=$(xcodebuild -list -json -project "$PROJECT" \
  | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin)["project"]["targets"]))' \
  | while read -r t; do
      xcodebuild -showBuildSettings -json -project "$PROJECT" -target "$t" -configuration Release -sdk iphoneos 2>/dev/null \
        | python3 -c 'import json,sys
for e in json.load(sys.stdin):
    b=e["buildSettings"]
    if b.get("PRODUCT_TYPE","").endswith(("app-extension","extensionkit-extension")): print(b.get("FULL_PRODUCT_NAME",""))'
    done | sort -u)
ls "$app/PlugIns" "$app/Extensions" 2>/dev/null || true
if [ -z "$expected" ]; then
  note "- No extensions in \`$PROJECT\`; nothing to embed."
  exit 0
fi
missing=0
for ext in $expected; do
  if find "$app" -maxdepth 2 -name "$ext" | grep -q .; then note "- ✅ \`$ext\` is embedded"
  else echo "::error::$ext is not embedded in $app"; note "- ❌ \`$ext\` is not embedded"; missing=1; fi
done
exit $missing
