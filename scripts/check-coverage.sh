#!/bin/bash
set -euo pipefail
swift test --enable-code-coverage
binary="$(swift build --show-bin-path)"
xcrun llvm-cov export "$binary/DynamicUIPackageTests.xctest/Contents/MacOS/DynamicUIPackageTests" -instr-profile "$binary/codecov/default.profdata" > "$binary/coverage.json"
ruby -rjson -e '
files = JSON.parse(File.read(ARGV[0]))["data"].flat_map { |d| d["files"] }.select { |f| f["filename"].end_with?("/Sources/DynamicUICore/Engine.swift") }
abort "No production coverage found" if files.empty?
covered = files.sum { |f| f["summary"]["lines"]["covered"] }
total = files.sum { |f| f["summary"]["lines"]["count"] }
percentage = 100.0 * covered / total
puts "DynamicUICore line coverage: #{percentage.round(2)}% (#{covered}/#{total})"
abort "Coverage must be greater than 80%" unless percentage > 80
' "$binary/coverage.json"
