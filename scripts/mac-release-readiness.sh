#!/usr/bin/env bash
set -euo pipefail

echo "== Mac verification =="
bash scripts/mac-verify.sh

echo ""
echo "== Screenshot capture =="
bash scripts/mac-capture-screenshots.sh

echo ""
echo "== Fastlane screenshot files =="
required_screenshots=(
  "fastlane/screenshots/en-US/01-Capture.png"
  "fastlane/screenshots/en-US/02-Records.png"
  "fastlane/screenshots/en-US/03-Dashboard.png"
  "fastlane/screenshots/en-US/04-Settings.png"
)

for screenshot in "${required_screenshots[@]}"; do
  if [[ ! -s "${screenshot}" ]]; then
    echo "Missing staged screenshot: ${screenshot}" >&2
    exit 1
  fi
  echo "${screenshot}"
done

echo ""
echo "Release readiness checks completed."
echo "Next upload commands, after App Store Connect credentials are configured:"
echo "bundle exec fastlane ios metadata"
echo "bundle exec fastlane ios screenshots"
echo "bundle exec fastlane ios review_check"
echo "bundle exec fastlane ios testflight"
