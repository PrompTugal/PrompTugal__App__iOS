#!/usr/bin/env bash
# size-check.sh <build-info.json>
# Compares this build's sizes with the latest successful iOS release build on
# dev (its build-info artifact), and with fixed budgets in size-budget.json.
#   - over a budget                      -> error, the job fails
#   - grew more than warnPercent vs dev  -> warning in the summary
# Needs GH_TOKEN (the workflow's GITHUB_TOKEN, actions: read) for the comparison;
# without it, only the budgets are checked.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
cur=$1
budget=$(dirname "$0")/size-budget.json
get() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2],0))' "$1" "$2"; }

summary ""
summary "### Size check"
summary ""
summary "| | This build | dev baseline | Change | Budget |"
summary "| --- | ---: | ---: | ---: | ---: |"

base=""
if [ -n "${GH_TOKEN:-}" ] && command -v gh >/dev/null; then
  # The newest successful dev run that has a build-info for THIS app. Runs that did not
  # touch the app have none, so look back a few runs. Older runs named it plain build-info.
  for run in $(gh run list --workflow ios-release.yml --branch dev --status success --limit 20 --json databaseId -q '.[].databaseId' 2>/dev/null || true); do
    for art in "build-info-${APP_KEY:-app}" build-info; do
      if gh run download "$run" -n "$art" -D "$OUT/baseline" >/dev/null 2>&1; then base=$OUT/baseline/build-info.json; break 2; fi
    done
  done
fi

warn=$(get "$budget" warnPercent)
fail=0
for k in ipaBytes appBytes executableBytes; do
  c=$(get "$cur" $k); b=0; [ -n "$base" ] && b=$(get "$base" $k)
  lim=$(get "$budget" $k)
  change="–"
  if [ "$b" -gt 0 ]; then
    pct=$(awk -v c="$c" -v b="$b" 'BEGIN{printf "%+.1f", 100*(c-b)/b}')
    change="$pct%"
    if awk -v p="$pct" -v w="$warn" 'BEGIN{exit !(p>w)}'; then
      echo "::warning::$k grew $pct% against dev ($(human "$b") → $(human "$c"))"
      change="⚠️ $pct%"
    fi
  fi
  status=""
  if [ "$lim" -gt 0 ] && [ "$c" -gt "$lim" ]; then
    echo "::error::$k is $(human "$c"), over the budget of $(human "$lim") in scripts/release/size-budget.json"
    status=" ❌"; fail=1
  fi
  summary "| \`$k\` | $(human "$c")$status | $( [ "$b" -gt 0 ] && human "$b" || echo –) | $change | $(human "$lim") |"
done
if [ -z "$base" ]; then summary ""; summary "No dev baseline yet (no successful dev run, or no token)."; fi
exit $fail
