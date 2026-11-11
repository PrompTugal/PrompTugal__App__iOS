#!/usr/bin/env bash
# latest-build.sh <out.json> [branch]
# Writes the build-info.json of the latest successful build on a branch (default dev),
# from ios.yml (dev publishes from it) or ios-release.yml, with the run's links and
# artifact names added, for the website's "latest CI build" panel. Runs on any runner with gh and GH_TOKEN
# (actions: read). If there is no such run yet it writes {"available": false}
# and exits 0, so the site build never fails because of it.
set -euo pipefail
out=$1; branch=${2:-dev}
tmp=$(mktemp -d)
# The website shows the public app, so prefer its build-info; then the team app's.
run=""
for art in promptugal team; do
  run=$("$(dirname "$0")/find-build-info.sh" "$art" "$tmp" success "$branch") && break
done
if [ -z "$run" ]; then
  echo '{"available": false}' > "$out"; echo "No successful iOS build with a build-info on $branch yet."; exit 0
fi
id=$run
run=$(gh run view "$id" --json databaseId,url,createdAt,headSha)
arts=$(gh api "repos/{owner}/{repo}/actions/runs/$id/artifacts" -q '[.artifacts[] | select(.expired|not) | {name, size: .size_in_bytes, expires: .expires_at}]')
RUN="$run" ARTS="$arts" python3 - "$tmp/build-info.json" "$out" <<'PY'
import json, os, sys
info = json.load(open(sys.argv[1]))
run = json.loads(os.environ["RUN"])
info.update(available=True, runUrl=run["url"], runCreatedAt=run["createdAt"],
            artifacts=json.loads(os.environ["ARTS"] or "[]"))
json.dump(info, open(sys.argv[2], "w"), indent=2)
print(f"Latest iOS build: {info['version']} ({info['build']}) at {info['commit'][:7]}")
PY
