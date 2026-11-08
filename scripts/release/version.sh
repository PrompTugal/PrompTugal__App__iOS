#!/usr/bin/env bash
# Work out the version and build number for this CI run and export them.
#
#   MARKETING_VERSION      the repo release version in /VERSION at the built commit, without
#                          the "v" (v0.4.7 -> 0.4.7; v0.4 -> 0.4.0). Every app gets the same
#                          number, and the build commands pass it to xcodebuild. If VERSION
#                          is missing, the project's own MARKETING_VERSION is used.
#   RELEASE_TAG            the v* tag on the built commit (website.yml puts it there), or "none".
#   BUILD_NUMBER           CFBundleVersion. GITHUB_RUN_NUMBER of the ios-release
#                          workflow plus IOS_BUILD_OFFSET (default 100, so CI builds
#                          sort above the hand-uploaded builds 1-4). It only grows,
#                          and a re-run of the same run keeps its number.
#                          Override with BUILD_NUMBER_OVERRIDE (workflow input).
#   SHORT_SHA, ARTIFACT_BASE  for file and artifact names.
#
# Writes them to $GITHUB_ENV and $GITHUB_OUTPUT when those exist.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
: "${APP_NAME:?APP_NAME is not set (name of the app, from apps.json)}"

offset=${IOS_BUILD_OFFSET:-100}
run=${GITHUB_RUN_NUMBER:-0}
if [ -n "${BUILD_NUMBER_OVERRIDE:-}" ]; then
  [[ "$BUILD_NUMBER_OVERRIDE" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || { echo "::error::build number '$BUILD_NUMBER_OVERRIDE' is not 1-3 dot-separated integers"; exit 1; }
  build=$BUILD_NUMBER_OVERRIDE; how="override"
else
  build=$((run + offset)); how="run $run + offset $offset"
fi

sha=${SOURCE_SHA:-${GITHUB_SHA:-$(git rev-parse HEAD)}}
short=${sha:0:7}
# VERSION as it is at the commit that is checked out (the built commit).
raw=$(tr -d ' \r\n' < VERSION 2>/dev/null || true)
if [[ "$raw" =~ ^v([0-9]+)\.([0-9]+)(\.([0-9]+))?$ ]]; then
  marketing="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[4]:-0}"
else
  echo "::warning::VERSION holds '$raw', not v<major>.<minor>[.<n>]; using the project's MARKETING_VERSION"
  marketing=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=iOS' -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/^ *MARKETING_VERSION = /{print $2; exit}')
  marketing=${marketing:-0.0.0}
fi
tag=$(git tag --points-at "$sha" --list 'v[0-9]*' 2>/dev/null | sort -V | tail -1)
tag=${tag:-none}
base="${APP_NAME}-${marketing}-${build}-${short}"

echo "MARKETING_VERSION=$marketing  BUILD_NUMBER=$build ($how)  TAG=$tag  SHA=$short"
for f in "${GITHUB_ENV:-}" "${GITHUB_OUTPUT:-}"; do
  [ -n "$f" ] || continue
  { echo "MARKETING_VERSION=$marketing"; echo "RELEASE_TAG=$tag"; echo "BUILD_NUMBER=$build"; echo "SHORT_SHA=$short"; echo "ARTIFACT_BASE=$base"; } >> "$f"
done
summary "**$marketing ($build) · tag $tag · commit $short**  (build number: $how)"
summary ""
