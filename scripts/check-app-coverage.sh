#!/bin/bash
set -euo pipefail
result="${1:?Pass a unit-only xcresult bundle}"
report="$(mktemp)"
trap 'rm -f "$report"' EXIT
xcrun xccov view --report --json "$result" > "$report"
ruby -rjson -e '
target = JSON.parse(File.read(ARGV[0]))["targets"].find { |t| t["name"] == "Forma.app" }
abort "Missing app coverage" unless target && target["executableLines"] > 0
puts "Forma unit-run line coverage: #{(target["lineCoverage"] * 100).round(2)}%"
abort "App coverage must exceed 80%" unless target["lineCoverage"] > 0.8
' "$report"
