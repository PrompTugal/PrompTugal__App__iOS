#!/usr/bin/env bash
# Install what signing and upload need, from secrets in the environment:
#
#   App Store Connect API key (both modes)
#     ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_BASE64
#     -> $RUNNER_TEMP/asc/AuthKey_<id>.p8 (also ~/.appstoreconnect/private_keys for altool)
#   MODE=manual
#     IOS_DIST_CERT_P12_BASE64 + IOS_DIST_CERT_PASSWORD -> temporary keychain
#     IOS_PROFILE_{APP,WIDGETS,INTENTS,SHARE}_BASE64     -> ~/Library/MobileDevice/Provisioning Profiles
#     Writes $OUT/profiles.tsv: bundle id <TAB> profile name <TAB> uuid <TAB> team
#   MODE=automatic
#     Only the API key; Xcode creates or fetches certificates and profiles.
#     If the certificate secrets are also set they are imported, so Xcode does
#     not create a new certificate on every run.
#
# Never prints a secret. Values derived from secrets are masked.
set -euo pipefail
set +x
. "$(dirname "$0")/lib.sh"
mkdir -p "$OUT" "$LOGS"
: "${MODE:?MODE must be manual or automatic}"

# --- API key ---------------------------------------------------------------
keydir=$RUNNER_TEMP/asc
mkdir -p "$keydir" ~/.appstoreconnect/private_keys
chmod 700 "$keydir" ~/.appstoreconnect/private_keys
key=$keydir/AuthKey_${ASC_KEY_ID}.p8
printf '%s' "$ASC_KEY_P8_BASE64" | base64 --decode > "$key"
chmod 600 "$key"
cp "$key" ~/.appstoreconnect/private_keys/
grep -q "BEGIN PRIVATE KEY" "$key" || { echo "::error::ASC_KEY_P8_BASE64 does not decode to a .p8 private key"; exit 1; }
echo "ASC_KEY_PATH=$key" >> "$GITHUB_ENV"
note "- API key installed (key id ends …${ASC_KEY_ID: -2})"

# --- certificate -----------------------------------------------------------
if [ -n "${IOS_DIST_CERT_P12_BASE64:-}" ]; then
  kc=$RUNNER_TEMP/release.keychain-db
  kcpw=$(openssl rand -hex 24); echo "::add-mask::$kcpw"
  p12=$RUNNER_TEMP/dist.p12
  printf '%s' "$IOS_DIST_CERT_P12_BASE64" | base64 --decode > "$p12"
  security create-keychain -p "$kcpw" "$kc"
  security set-keychain-settings -lut 21600 "$kc"
  security unlock-keychain -p "$kcpw" "$kc"
  security import "$p12" -k "$kc" -P "$IOS_DIST_CERT_PASSWORD" -f pkcs12 -A \
    -T /usr/bin/codesign -T /usr/bin/security -T /usr/bin/productbuild >/dev/null
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$kcpw" "$kc" >/dev/null
  # Our keychain first, then the existing ones (login keychain stays usable).
  security list-keychains -d user -s "$kc" $(security list-keychains -d user | tr -d '"')
  rm -f "$p12"
  echo "KEYCHAIN_PATH=$kc" >> "$GITHUB_ENV"
  ids=$(security find-identity -v -p codesigning "$kc")
  echo "$ids" | sed -E 's/[0-9A-F]{40}/<sha1>/'   # names only, no hashes
  if ! echo "$ids" | grep -qE '"(Apple|iPhone) Distribution'; then
    echo "::error::the .p12 has no Apple Distribution identity (found: $(echo "$ids" | grep -c '"') identities)"
    exit 1
  fi
  name=$(echo "$ids" | grep -oE '"(Apple|iPhone) Distribution[^"]*"' | head -1 | tr -d '"')
  echo "SIGN_IDENTITY_NAME=$name" >> "$GITHUB_ENV"
  # The certificate's expiry, so it does not surprise anyone.
  exp=$(security find-certificate -c "$name" -p "$kc" | openssl x509 -noout -enddate | cut -d= -f2)
  note "- Certificate imported into a temporary keychain: \`${name%% (*}\` (expires $exp)"
fi

# --- profiles --------------------------------------------------------------
pdir=~/Library/MobileDevice/Provisioning\ Profiles
mkdir -p "$pdir" "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
: > "$OUT/profiles.tsv"
for slot in APP WIDGETS INTENTS SHARE; do
  var=IOS_PROFILE_${slot}_BASE64
  [ -n "${!var:-}" ] || continue
  tmp=$RUNNER_TEMP/profile-$slot.mobileprovision
  printf '%s' "${!var}" | base64 --decode > "$tmp"
  security cms -D -i "$tmp" > "$RUNNER_TEMP/profile-$slot.plist"
  pl=$RUNNER_TEMP/profile-$slot.plist
  uuid=$(plist_get "$pl" UUID)
  pname=$(plist_get "$pl" Name)
  team=$(plist_get "$pl" TeamIdentifier:0)
  appid=$(plist_get "$pl" Entitlements:application-identifier)
  bundle=${appid#*.}
  expires=$(plist_get "$pl" ExpirationDate)
  if /usr/libexec/PlistBuddy -c "Print :ProvisionedDevices" "$pl" >/dev/null 2>&1; then
    echo "::error::$var is a development or ad hoc profile (it lists devices). Use an App Store profile."
    exit 1
  fi
  # Xcode 16+ reads the UserData folder; older Xcode reads MobileDevice.
  cp "$tmp" "$pdir/$uuid.mobileprovision"
  cp "$tmp" "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/$uuid.mobileprovision"
  printf '%s\t%s\t%s\t%s\n' "$bundle" "$pname" "$uuid" "$team" >> "$OUT/profiles.tsv"
  note "- Profile \`$pname\` for \`$bundle\` installed (expires $expires)"
  rm -f "$tmp"
done

if [ "$MODE" = manual ]; then
  [ -s "$OUT/profiles.tsv" ] || { echo "::error::manual signing needs IOS_PROFILE_APP_BASE64"; exit 1; }
  grep -q "^news\.promptugal\.reader	" "$OUT/profiles.tsv" || \
    { echo "::error::no installed profile is for news.promptugal.reader"; exit 1; }
  if [ -z "${APPLE_TEAM_ID:-}" ]; then
    echo "APPLE_TEAM_ID=$(head -1 "$OUT/profiles.tsv" | cut -f4)" >> "$GITHUB_ENV"
  fi
fi
