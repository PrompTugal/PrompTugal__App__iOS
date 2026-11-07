#!/usr/bin/env bash
# check-profiles.sh
# Before a signed archive: for every target that is signed (app and extensions),
# check that an App Store profile is installed for its bundle id and that the
# profile grants every entitlement the target asks for. Prints one table to the
# job summary and fails with the exact capability to enable on the App ID.
# Needs signing-setup.sh to have run (profiles.tsv).
set -euo pipefail
. "$(dirname "$0")/lib.sh"
tsv=$OUT/profiles.tsv
summary ""
summary "### Profiles against entitlements"
summary ""
summary "| Target | Bundle id | Profile | Result |"
summary "| --- | --- | --- | --- |"
fail=0
while IFS=$'\t' read -r target bundle type ent; do
  case "$type" in *application|*app-extension|*extensionkit-extension) ;; *) continue ;; esac
  uuid=$(awk -F'\t' -v b="$bundle" '$1==b{print $3; exit}' "$tsv")
  pname=$(awk -F'\t' -v b="$bundle" '$1==b{print $2; exit}' "$tsv")
  if [ -z "$uuid" ]; then
    summary "| \`$target\` | \`$bundle\` | none | ❌ no App Store profile installed |"
    echo "::error::no App Store profile for $bundle ($target)"; fail=1; continue
  fi
  pf=$(ls "$HOME/Library/MobileDevice/Provisioning Profiles/$uuid.mobileprovision")
  security cms -D -i "$pf" > "$OUT/check-$uuid.plist"
  problems=$(python3 - "$OUT/check-$uuid.plist" "${ent:-}" <<'PY'
import plistlib, sys, os
prof = plistlib.load(open(sys.argv[1], "rb")).get("Entitlements", {})
want = plistlib.load(open(sys.argv[2], "rb")) if sys.argv[2] and os.path.exists(sys.argv[2]) else {}
out = []
for k, v in want.items():
    if k not in prof:
        out.append(f"profile lacks {k}")
        continue
    have = prof[k]
    if isinstance(v, list) and isinstance(have, list) and "*" not in have:
        missing = [x for x in v if x not in have]
        if missing:
            out.append(f"{k} missing {', '.join(missing)}")
print("; ".join(out))
PY
)
  if [ -n "$problems" ]; then
    summary "| \`$target\` | \`$bundle\` | \`$pname\` | ❌ $problems |"
    echo "::error::$target ($bundle): $problems. Enable the capability on the App ID, regenerate the profile, update its secret."
    fail=1
  else
    summary "| \`$target\` | \`$bundle\` | \`$pname\` | ✅ grants all $(python3 -c "import plistlib,sys,os;p=sys.argv[1];print(len(plistlib.load(open(p,'rb'))) if p and os.path.exists(p) else 0)" "${ent:-}") entitlements |"
  fi
done < <("$(dirname "$0")/targets.sh")
exit $fail
