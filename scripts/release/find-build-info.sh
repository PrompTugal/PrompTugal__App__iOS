#!/usr/bin/env bash
# find-build-info.sh <app key> <out dir> [any|success] [branch]
# Finds the newest build-info.json of an app on a branch (default dev) and copies it to
# <out dir>/build-info.json; prints the run id. Exit 1 when there is none.
#
# Two places write one, newest first wins:
#   ios.yml          (a dev push that uploaded to TestFlight) artifact build-info-apps,
#                    file <key>/build-info.json
#   ios-release.yml  (tags, manual runs; dev pushes before 10 Nov 2026) artifact
#                    build-info-<key>, or build-info before the split
# Needs gh and GH_TOKEN (actions: read).
set -uo pipefail
key=${1:?app key}; out=${2:?out dir}; status=${3:-any}; branch=${4:-dev}
mkdir -p "$out"
args=(--branch "$branch" --limit 25 --json databaseId,createdAt -q '.[] | "\(.createdAt) \(.databaseId)"')
[ "$status" = success ] && args+=(--status success)
runs=$( { gh run list --workflow ios.yml "${args[@]}" 2>/dev/null
          gh run list --workflow ios-release.yml "${args[@]}" 2>/dev/null; } | sort -r | cut -d' ' -f2)
tmp=$(mktemp -d)
while read -r id; do
  [ -n "$id" ] || continue
  names=$(gh api "repos/{owner}/{repo}/actions/runs/$id/artifacts" --jq '.artifacts[] | select(.expired | not) | .name' 2>/dev/null || true)
  for art in build-info-apps "build-info-$key" build-info; do
    printf '%s\n' "$names" | grep -qx "$art" || continue
    rm -rf "$tmp"/*
    gh run download "$id" -n "$art" -D "$tmp" >/dev/null 2>&1 || continue
    f=$tmp/build-info.json; [ "$art" = build-info-apps ] && f=$tmp/$key/build-info.json
    [ -f "$f" ] || continue
    cp "$f" "$out/build-info.json"
    [ -f "$(dirname "$f")/release-notes.txt" ] && cp "$(dirname "$f")/release-notes.txt" "$out/"
    echo "$id"; rm -rf "$tmp"; exit 0
  done
done <<< "$runs"
rm -rf "$tmp"; exit 1
