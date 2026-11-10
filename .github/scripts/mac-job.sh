#!/usr/bin/env bash
# The one macOS job of ios.yml: every app and package a run touches, on one Mac.
#
#   mac-job.sh sims       pick an iPhone and an iPad simulator and start booting both
#   mac-job.sh apps       per app: build-for-testing once, then test-without-building on each
#                         device (or a plain Debug build when tests are off), then the Release
#                         device build (unsigned) with check-embedded.sh, unless the app is
#                         about to be archived for TestFlight in this job
#   mac-job.sh packages   each affected package's tests, in one shared DerivedData
#   mac-job.sh release    the unsigned Release device build for the apps named in RELEASE_APPS
#                         (apps that were going to upload but did not get a release commit)
#   mac-job.sh publish    per app in UPLOAD_JSON: version, signing setup, signed archive,
#                         size check, export, upload (scripts/release/testflight.sh), cleanup
#
# One app failing does not stop the others: every app and package is built and tested,
# failures are listed in the summary, and the step fails at the end. A later step that
# publishes runs only when every earlier step passed.
#
# Environment (from ios.yml): APPS_JSON, PACKAGES_JSON, UPLOAD_JSON (matrix entries from
# ios-changes.yml), RUN_TESTS, DEVICES ("iPhone iPad"), RELEASE_BUILD, PUBLISH.
set -uo pipefail
root=$PWD
T=${RUNNER_TEMP:?}
DD=$T/dd                 # one DerivedData for every app's Debug build and tests
PDD=$T/dd-packages       # one for every package's tests
RDD=$T/dd-release        # one for every Release build, unsigned or signed
LOGS=$T/logs
SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/null}
mkdir -p "$LOGS"
sims=$T/sims.env
failed=()

say() { printf '%s\n' "$*" >> "$SUMMARY"; }
step() { .github/scripts/run-and-summarize.sh "$@"; }
fail() { failed+=("$1"); }
finish() {
  if [ ${#failed[@]} -gt 0 ]; then
    say ""; say "**Failed:** $(printf '`%s` ' "${failed[@]}")"
    echo "Failed: ${failed[*]}"; exit 1
  fi
  exit 0
}
# app_field <json entry> <key>
field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2], ""))' "$1" "$2"; }
entries() { python3 -c 'import json,sys; [print(json.dumps(e)) for e in json.loads(sys.argv[1] or "[]")]' "${1:-[]}"; }
in_list() { python3 -c 'import json,sys; sys.exit(0 if any(e["app"] == sys.argv[2] for e in json.loads(sys.argv[1] or "[]")) else 1)' "${1:-[]}" "$2"; }
# The scripts write KEY=value lines to $GITHUB_ENV for later steps; inside one step, export them.
# Line by line, not `source`: values have spaces (the signing identity's name).
load_env() { local k v; while IFS="=" read -r k v; do if [ -n "$k" ]; then export "$k=$v"; fi; done < "$1"; return 0; }
udid_for() { grep "^$1=" "$sims" | cut -d= -f2; }
wait_booted() {
  local u=$1
  # bootstatus -b boots if needed and waits; cap it so a stuck boot leaves xcodebuild to finish it.
  ( xcrun simctl bootstatus "$u" -b >/dev/null 2>&1 ) & local p=$!
  for _ in $(seq 1 60); do kill -0 "$p" 2>/dev/null || break; sleep 5; done
  kill "$p" 2>/dev/null || true
}

release_build() {  # release_build <entry>: Release, generic iOS device, unsigned, then check-embedded
  local e=$1 key project scheme app
  key=$(field "$e" app); project=$(field "$e" project); scheme=$(field "$e" scheme)
  if step "$key: Release build (iOS device, unsigned)" "$LOGS/$key-release.log" -- \
      xcodebuild build -project "$project" -scheme "$scheme" -configuration Release \
        -destination 'generic/platform=iOS' -derivedDataPath "$RDD" \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO; then
    # The DerivedData is shared by every app, so ask the scheme which .app is its own.
    name=$(xcodebuild -showBuildSettings -json -project "$project" -scheme "$scheme" -configuration Release \
             -destination 'generic/platform=iOS' -derivedDataPath "$RDD" 2>/dev/null \
           | python3 -c 'import json,sys; print(next(e["buildSettings"]["FULL_PRODUCT_NAME"] for e in json.load(sys.stdin) if e["buildSettings"].get("WRAPPER_EXTENSION") == "app"))')
    app=$RDD/Build/Products/Release-iphoneos/$name
    echo "Built: $app"
    PROJECT=$project SCHEME=$scheme scripts/release/check-embedded.sh "$app" || fail "$key: extensions"
  else
    fail "$key: Release build"
  fi
}

case "${1:?phase}" in
  sims)
    : > "$sims"
    for d in ${DEVICES:-iPhone iPad}; do
      u=$(.github/scripts/pick-simulator.py "$d") || { echo "::error::no $d simulator"; exit 1; }
      echo "$d=$u" >> "$sims"
      xcrun simctl boot "$u" 2>/dev/null || true   # boots in the background while the apps compile
      echo "$d: $u"
    done
    cat "$sims"
    ;;

  apps)
    while IFS= read -r e; do
      [ -n "$e" ] || continue
      key=$(field "$e" app); project=$(field "$e" project); scheme=$(field "$e" scheme)
      say ""; say "## \`$key\`"
      common=(-project "$project" -scheme "$scheme" -configuration Debug -derivedDataPath "$DD"
              CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
      if [ "${RUN_TESTS:-false}" = true ]; then
        first=$(udid_for "${DEVICES%% *}")
        # One build for every device: same platform, same architecture, same test bundle.
        if step "$key: build for testing (Debug, iOS Simulator)" "$LOGS/$key-build-for-testing.log" -- \
            xcodebuild build-for-testing "${common[@]}" -destination "id=$first"; then
          for d in ${DEVICES:-iPhone iPad}; do
            u=$(udid_for "$d"); wait_booted "$u"
            rm -rf "$LOGS/$key-$d.xcresult"
            step "$key: unit tests ($d)" "$LOGS/$key-test-$d.log" -- \
              xcodebuild test-without-building "${common[@]}" -destination "id=$u" \
                -resultBundlePath "$LOGS/$key-$d.xcresult" \
                -parallel-testing-enabled NO -test-timeouts-enabled YES \
                -default-test-execution-time-allowance 60 -maximum-test-execution-time-allowance 180 \
              || fail "$key: tests ($d)"
          done
        else
          fail "$key: build for testing"
        fi
      else
        step "$key: Debug build (iOS Simulator)" "$LOGS/$key-build.log" -- \
          xcodebuild build "${common[@]}" -destination 'generic/platform=iOS Simulator' \
          || fail "$key: Debug build"
      fi
      if [ "${RELEASE_BUILD:-true}" = true ]; then
        if [ "${PUBLISH:-false}" = true ] && in_list "${UPLOAD_JSON:-[]}" "$key"; then
          say "- Release build: done by the signed archive below (this app uploads)."
        else
          release_build "$e"
        fi
      fi
    done < <(entries "${APPS_JSON:-[]}")
    finish
    ;;

  packages)
    u=$(udid_for iPhone 2>/dev/null || true)
    [ -n "$u" ] && wait_booted "$u"
    while IFS= read -r e; do
      [ -n "$e" ] || continue
      name=$(field "$e" name); path=$(field "$e" path)
      PACKAGE_DERIVED_DATA=$PDD scripts/release/test-package.sh "$path" "$u" || fail "package $name"
    done < <(entries "${PACKAGES_JSON:-[]}")
    finish
    ;;

  release)
    while IFS= read -r e; do
      [ -n "$e" ] || continue
      in_list "${RELEASE_APPS:-[]}" "$(field "$e" app)" && release_build "$e"
    done < <(entries "${APPS_JSON:-[]}")
    finish
    ;;

  publish)
    # Each app is set up, archived, uploaded and cleaned up in turn, with its own OUT folder
    # and its own profiles; the API key and certificate are the same for every app.
    pub=$T/publish; mkdir -p "$pub"
    uploaded=()
    while IFS= read -r e; do
      [ -n "$e" ] || continue
      key=$(field "$e" app); KEY_UP=$(field "$e" secret)
      say ""; say "## TestFlight: \`$key\` (\`$(field "$e" bundle)\`)"
      envf=$T/env-$key; : > "$envf"
      # The profile secrets of this app (and the old unprefixed names for the legacy app).
      pick() { local v="IOS_PROFILE_${KEY_UP}_$1_BASE64" l="LEGACY_PROFILE_$1_BASE64"
               if [ -n "${!v:-}" ]; then printf '%s' "${!v}"
               elif [ "$(field "$e" legacy)" = True ]; then printf '%s' "${!l:-}"; fi; }
      (
        set -e
        export PROJECT=$(field "$e" project) SCHEME=$(field "$e" scheme) APP_NAME=$(field "$e" name)
        export APP_KEY=$key EXPECTED_BUNDLE=$(field "$e" bundle) BUNDLE_ID=$(field "$e" bundle)
        export IOS_BUILD_OFFSET=$(field "$e" offset) NOTES_FROM=$(field "$e" base)
        export OUT=$T/release/$key LOGS=$T/release/$key/logs SIGNED_DERIVED_DATA=$RDD
        export IOS_PROFILE_APP_BASE64=$(pick APP) IOS_PROFILE_WIDGETS_BASE64=$(pick WIDGETS)
        export IOS_PROFILE_INTENTS_BASE64=$(pick INTENTS) IOS_PROFILE_SHARE_BASE64=$(pick SHARE)
        export SIZE_CHECK=true CHECK_EMBEDDED=true GITHUB_ENV=$envf GITHUB_OUTPUT=$envf
        mode=manual
        { [ -n "${IOS_DIST_CERT_P12_BASE64:-}" ] && [ -n "${IOS_DIST_CERT_PASSWORD:-}" ] && [ -n "$IOS_PROFILE_APP_BASE64" ]; } || mode=automatic
        missing=()
        for s in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_P8_BASE64; do [ -n "${!s:-}" ] || missing+=("$s"); done
        [ "$mode" = automatic ] && [ -z "${APPLE_TEAM_ID:-}" ] && missing+=(APPLE_TEAM_ID)
        if [ ${#missing[@]} -gt 0 ]; then
          echo "::error::$key: signing secrets missing: ${missing[*]}"; say "- ❌ secrets missing: ${missing[*]}"; exit 1
        fi
        export MODE=$mode
        scripts/release/version.sh;       load_env "$envf"
        trap 'scripts/release/signing-cleanup.sh >/dev/null 2>&1 || true' EXIT
        scripts/release/signing-setup.sh; load_env "$envf"
        rc=0; python3 scripts/release/asc.py has-record || rc=$?
        if [ "$rc" = 3 ]; then say "- ⏭️ no App Store Connect record for \`$EXPECTED_BUNDLE\`; nothing archived or uploaded."; exit 0; fi
        [ "$rc" = 0 ]
        scripts/release/testflight.sh
        scripts/release/release-notes.sh > "$OUT/dist/release-notes.txt"
        mkdir -p "$pub/$key"
        cp "$OUT/dist/build-info.json" "$OUT/dist/release-notes.txt" "$pub/$key/"
        cp "$OUT"/export/*.ipa "$pub/$key/" 2>/dev/null || true
        python3 -c 'import json,sys; json.dump(dict(app=sys.argv[1], bundle=sys.argv[2], version=sys.argv[3], build=sys.argv[4]), open(sys.argv[5], "w"))' \
          "$key" "$EXPECTED_BUNDLE" "$MARKETING_VERSION" "$BUILD_NUMBER" "$pub/$key/uploaded.json"
      ) || fail "$key: TestFlight"
      [ -f "$pub/$key/uploaded.json" ] && uploaded+=("$pub/$key/uploaded.json")
    done < <(entries "${UPLOAD_JSON:-[]}")
    list=$(python3 -c 'import json,sys; print(json.dumps([json.load(open(f)) for f in sys.argv[1:]], separators=(",", ":")))' ${uploaded[@]+"${uploaded[@]}"})
    echo "uploaded=$list" >> "${GITHUB_OUTPUT:-/dev/null}"
    echo "uploaded: $list"
    finish
    ;;

  *) echo "unknown phase $1"; exit 2 ;;
esac
