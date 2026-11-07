#!/usr/bin/env bash
# Work out the version and build number for this CI run and export them.
#
#   MARKETING_VERSION      read from the Xcode project (CFBundleShortVersionString).
#                          People change it in Xcode; CI never changes it.
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

offset=${IOS_BUILD_OFFSET:-100}
run=${GITHUB_RUN_NUMBER:-0}
if [ -n "${BUILD_NUMBER_OVERRIDE:-}" ]; then
  [[ "$BUILD_NUMBER_OVERRIDE" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || { echo "::error::build number '$BUILD_NUMBER_OVERRIDE' is not 1-3 dot-separated integers"; exit 1; }
  build=$BUILD_NUMBER_OVERRIDE; how="override"
else
  build=$((run + offset)); how="run $run + offset $offset"
fi

marketing=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=iOS' -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/^ *MARKETING_VERSION = /{print $2; exit}')
marketing=${marketing:-0.0.0}
sha=${GITHUB_SHA:-$(git rev-parse HEAD)}
short=${sha:0:7}
base="${APP_NAME}-${marketing}-${build}-${short}"

echo "MARKETING_VERSION=$marketing  BUILD_NUMBER=$build ($how)  SHA=$short"
for f in "${GITHUB_ENV:-}" "${GITHUB_OUTPUT:-}"; do
  [ -n "$f" ] || continue
  { echo "MARKETING_VERSION=$marketing"; echo "BUILD_NUMBER=$build"; echo "SHORT_SHA=$short"; echo "ARTIFACT_BASE=$base"; } >> "$f"
done
summary "**Version:** \`$marketing\` · **build** \`$build\` ($how) · **commit** \`$short\`"
summary ""
