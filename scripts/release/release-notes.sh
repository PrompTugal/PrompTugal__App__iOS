#!/usr/bin/env bash
# release-notes.sh [from-ref] [to-ref]
# Plain-text release notes from git log, for "What to Test" in TestFlight and
# for the job summary. Defaults: from the previous ios-v* tag (or the last 30
# commits), to HEAD. Skips the website's "release: v…" bump commits and merges.
# Output stays under 4,000 characters (TestFlight's limit for What to Test).
set -euo pipefail
to=${2:-HEAD}
if [ -n "${1:-}" ]; then from=$1
else from=$(git describe --tags --abbrev=0 --match 'ios-v*' "$to^" 2>/dev/null || true); fi
range=${from:+$from..}$to
[ -n "$from" ] || range="-30 $to"

notes=$(git log --no-merges --format='%s' $range \
  | grep -vE '^(release: v|Merge |Status|status:)' \
  | awk '!seen[$0]++' | sed 's/^/- /')
count=$(printf '%s\n' "$notes" | grep -c '^- ' || true)
{
  echo "PrompTugal ${MARKETING_VERSION:-} (${BUILD_NUMBER:-}) · $(git rev-parse --short "$to")"
  echo "Changes ${from:+since $from}${from:-in the last 30 commits}: $count"
  echo
  printf '%s\n' "$notes"
} | head -c 3900
