#!/usr/bin/env bash
# release-notes.sh [from-ref] [to-ref]
# Plain-text "What to Test" notes for TestFlight, at most 4,000 characters
# (Apple's limit; we stop at 3,900). Two parts:
#   1. Team status: the "> summary" line of every status page under
#      briefs/*/status/ that changed in the range, one line per session.
#   2. Changes: commit subjects in the range, without merges, the website's
#      "release: v…" bumps and status-only commits.
# An app can add a fixed intro that goes first on every upload: scripts/release/notes/<app>.txt
# (APP_KEY from apps.json), at most 1,500 characters.
# Range: from the previous tag of the app (<app>-v*, or the old ios-v*) (or the last 30 commits) to HEAD.
set -euo pipefail
to=${2:-HEAD}
if [ -n "${1:-}" ]; then from=$1
elif [ -n "${NOTES_FROM:-}" ] && git cat-file -e "$NOTES_FROM^{commit}" 2>/dev/null; then from=$NOTES_FROM
else from=$(git describe --tags --abbrev=0 --match 'v[0-9]*' --match "${APP_KEY:-ios}-v*" --match 'ios-v*' "$to^" 2>/dev/null || true); fi
if [ -n "$from" ]; then range="$from..$to"; since="since $from"
else range="$(git rev-list -n 30 "$to" | tail -1)..$to"; since="in the last 30 commits"; fi

status=$(git diff --name-only "$range" -- 'briefs/*/status/*.md' 2>/dev/null | sort -u | while read -r f; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .md)
  line=$(git show "$to:$f" 2>/dev/null | grep -m1 '^> ' | sed -E 's/^> //; s/\*\*//g; s/`//g; s/\[([^]]*)\]\([^)]*\)/\1/g' | cut -c1-280)
  [ -n "$line" ] && printf -- '- %s: %s\n' "$name" "$line"
done)

changes=$(git log --no-merges --format='%s' "$range" \
  | grep -vE '^(release: v|Merge |Status|status:)' \
  | awk '!seen[$0]++' | sed 's/^/- /')
count=$(printf '%s\n' "$changes" | grep -c '^- ' || true)

# Build the whole text first, then cut it: piping a long text into `head -c` closes the pipe early, and
# with pipefail the writer's SIGPIPE ("printf: write error: Broken pipe") would fail the release step.
notes=$({
  echo "${APP_NAME:-PrompTugal} ${MARKETING_VERSION:-} (${BUILD_NUMBER:-}) · tag ${RELEASE_TAG:-none} · commit $(git rev-parse --short "$to")"
  echo "Test on iPhone and iPad. Report problems to the team channel with the build number."
  intro="$(dirname "$0")/notes/${APP_KEY:-}.txt"
  if [ -n "${APP_KEY:-}" ] && [ -f "$intro" ]; then echo; head -c 1500 "$intro"; echo; fi
  if [ -n "$status" ]; then echo; echo "What each session changed:"; printf '%s\n' "$status"; fi
  echo; echo "Commits $since: $count"
  printf '%s\n' "$changes"
})
printf '%s\n' "${notes:0:3900}"
