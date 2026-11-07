#!/usr/bin/env bash
# Remove everything signing-setup.sh installed. Safe to run more than once.
set -uo pipefail
if [ -n "${KEYCHAIN_PATH:-}" ] && [ -f "$KEYCHAIN_PATH" ]; then
  security delete-keychain "$KEYCHAIN_PATH" && echo "Deleted the temporary keychain."
fi
rm -rf "${RUNNER_TEMP:-/nonexistent}/asc" "${RUNNER_TEMP:-/nonexistent}"/profile-* "${RUNNER_TEMP:-/nonexistent}/dist.p12"
rm -f ~/.appstoreconnect/private_keys/AuthKey_*.p8
if [ -f "${OUT:-${RUNNER_TEMP:-/nonexistent}/release}/profiles.tsv" ]; then
  cut -f3 "${OUT:-$RUNNER_TEMP/release}/profiles.tsv" | while read -r uuid; do
    rm -f ~/Library/MobileDevice/Provisioning\ Profiles/"$uuid".mobileprovision \
          "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/$uuid.mobileprovision"
  done
  echo "Removed the installed profiles."
fi
echo "Cleanup done."
