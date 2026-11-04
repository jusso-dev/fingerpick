#!/bin/bash
# Runs FingerPickKit tests with coverage, prints a per-file table and fails if any
# source file is under the threshold (default 90%). Used by CI (#22).
set -euo pipefail
threshold="${1:-90}"
package=Packages/FingerPickKit

swift test --package-path "$package" --enable-code-coverage
json="$(swift test --package-path "$package" --show-codecov-path)"

report="$(jq -r '.data[0].files[]
  | select(.filename | test("/Sources/"))
  | "\(.summary.lines.percent * 10 | floor / 10)\t\(.filename | sub(".*/Sources/FingerPickKit/"; ""))"' "$json")"

{
  echo "### FingerPickKit line coverage"
  echo
  echo "| File | Lines |"
  echo "|---|---|"
  while IFS=$'\t' read -r percent file; do echo "| $file | $percent% |"; done <<< "$report"
} | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"

below="$(awk -F'\t' -v t="$threshold" '$1 < t { print $2 " (" $1 "%)" }' <<< "$report")"
if [[ -n "$below" ]]; then
  echo "Coverage below ${threshold}%:" >&2
  echo "$below" >&2
  exit 1
fi
