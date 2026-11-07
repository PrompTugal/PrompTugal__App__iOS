#!/usr/bin/env bash
# Print every target of the project as:
#   target <TAB> bundle id <TAB> product type <TAB> entitlements file (may be empty)
# (Release, iphoneos). Used to match provisioning profiles to targets.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
xcodebuild -list -json -project "$PROJECT" \
  | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin)["project"]["targets"]))' \
  | while read -r t; do
      xcodebuild -showBuildSettings -json -project "$PROJECT" -target "$t" -configuration Release -sdk iphoneos 2>/dev/null \
        | python3 -c 'import json,sys
for e in json.load(sys.stdin):
    b=e["buildSettings"]; print("\t".join([e["target"], b.get("PRODUCT_BUNDLE_IDENTIFIER",""), b.get("PRODUCT_TYPE",""), b.get("CODE_SIGN_ENTITLEMENTS","")]))'
    done
