#!/usr/bin/env bash
# Shared helpers for the release scripts. Source it: . scripts/release/lib.sh
# Nothing here prints a secret. Callers pass secrets through the environment
# and never on a command line that `set -x` or a log would show.

SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/null}
# The app being built comes from apps.json (the workflows pass these; APP_NAME is required by the scripts that name files). No defaults: the
# project moved to Apps/Team, and a stale default would build or sign the wrong app.
: "${PROJECT:?PROJECT is not set (project of the app, from apps.json)}"
: "${SCHEME:?SCHEME is not set (scheme of the app, from apps.json)}"
OUT=${OUT:-${RUNNER_TEMP:-$PWD/build}/release}
LOGS=${LOGS:-$OUT/logs}

summary() { printf '%s\n' "$*" >> "$SUMMARY"; }
note()    { printf '%s\n' "$*"; summary "$*"; }

# run_logged <title> <log> -- <command...>
# Runs a command with its full output in <log>. On failure copies the error
# lines into the job summary and repeats them as the last lines of the step.
run_logged() {
  local title=$1 log=$2; shift 2; [ "${1:-}" = "--" ] && shift
  mkdir -p "$(dirname "$log")"
  echo "::group::$title"
  "$@" 2>&1 | tee "$log"
  local status=${PIPESTATUS[0]}
  echo "::endgroup::"
  if [ "$status" -eq 0 ]; then summary "### ✅ $title"; return 0; fi
  local errs
  errs=$(grep -E "error:|\*\* (ARCHIVE|BUILD|EXPORT) FAILED|No profiles for|requires a provisioning profile|doesn't match|Provisioning profile" "$log" \
          | sed -E "s#${GITHUB_WORKSPACE:-$PWD}/##g" | awk '!seen[$0]++' | awk 'NR<=60')
  { echo "### ❌ $title (exit $status)"; echo; echo '```'; echo "$errs"; echo '```'
    echo; echo "Full log: the \`release-logs\` artifact, file \`$(basename "$log")\`."; } >> "$SUMMARY"
  echo "===== $title failed (exit $status) ====="; echo "$errs"; echo "===== end ====="
  return "$status"
}

# plist_get <plist> <key>
plist_get() { /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || echo "?"; }

# human <bytes>
human() { awk -v b="$1" 'BEGIN{ s="B KB MB GB"; split(s,u," "); i=1; while (b>=1024 && i<4){b/=1024;i++}; printf (i==1?"%d %s":"%.1f %s"), b, u[i] }'; }

# bytes <path>  (apparent size, recursive)
bytes() { if [ -d "$1" ]; then find "$1" -type f -print0 | xargs -0 stat -f%z 2>/dev/null | awk '{s+=$1} END{print s+0}'; else stat -f%z "$1"; fi; }
