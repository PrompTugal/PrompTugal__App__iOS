#!/usr/bin/env bash
# Copy the shared tool-test cases (format abp-tooltest/1) from PrompTugal/PrompTugal__App__Mobile
# into the RiskMandate app bundle. The Swift reader is Apps/RiskMandate/Sources/Workbench/ToolTestCase.swift.
#   scripts/apps/sync-tool-tests.sh [ref]      (default ref: dev)
# Then update ToolTestCatalogue.sourceCommit to the commit printed here, and run the RiskMandate tests.
set -euo pipefail
ref=${1:-dev}
root=$(git rev-parse --show-toplevel)
dest="$root/Apps/RiskMandate/Resources/ToolTests"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git clone -q --depth 1 -b "$ref" https://github.com/PrompTugal/PrompTugal__App__Mobile "$tmp/mobile"
rm -f "$dest"/*.json
cp "$tmp"/mobile/scenarios/tool-tests/[0-9]*.json "$dest"/
echo "Copied $(ls "$dest"/*.json | wc -l) files from PrompTugal__App__Mobile@$(git -C "$tmp/mobile" rev-parse --short HEAD)"
