#!/bin/sh
# Writes BuildInfo.json into the app bundle: git commit, branch, site release
# (/VERSION) and where it was built. Read by BuildInfo.swift for Debug → Build.
# Runs as an Xcode build phase, locally and in CI. Never fails the build:
# anything it cannot find is written as "unknown".
set -u

out="${SCRIPT_OUTPUT_FILE_0:-${TARGET_BUILD_DIR:-.}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:-.}/BuildInfo.json}"
root="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
mkdir -p "$(dirname "$out")"

clean() { printf '%s' "$1" | tr -d '"\\\n\r' ; }
git_() { git -C "$root" "$@" 2>/dev/null; }

commit=unknown; short=unknown; branch=unknown; dirty=false; date=""; count=0
if git_ rev-parse --git-dir >/dev/null; then
  commit=$(git_ rev-parse HEAD || echo unknown)
  short=$(git_ rev-parse --short=7 HEAD || echo unknown)
  branch=${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-$(git_ rev-parse --abbrev-ref HEAD || echo unknown)}}
  [ -n "$(git_ status --porcelain --untracked-files=no | head -1)" ] && dirty=true
  date=$(git_ log -1 --format=%cI || true)
  count=$(git_ rev-list --count HEAD || echo 0)
fi

release=$(head -1 "$root/VERSION" 2>/dev/null || echo unknown)
built=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if [ -n "${GITHUB_RUN_ID:-}" ]; then
  builder=ci
  run="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID}"
else
  builder=local
  run=""
fi

cat > "$out.tmp" <<JSON
{
  "commit": "$(clean "$commit")",
  "shortCommit": "$(clean "$short")",
  "branch": "$(clean "$branch")",
  "dirty": $dirty,
  "commitDate": "$(clean "$date")",
  "commitCount": ${count:-0},
  "siteRelease": "$(clean "$release")",
  "builtAt": "$built",
  "builder": "$builder",
  "ciRun": "$(clean "$run")",
  "configuration": "$(clean "${CONFIGURATION:-unknown}")"
}
JSON
mv "$out.tmp" "$out"
echo "BuildInfo: $short on $branch, site $release, $builder → $out"
