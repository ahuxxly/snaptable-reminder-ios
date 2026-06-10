#!/usr/bin/env bash
set -euo pipefail

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is missing. Install it with: brew install xcodegen" >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is missing. Install Xcode from the Mac App Store and run xcode-select." >&2
  exit 1
fi

xcodegen generate

SIMULATOR_ID="$(xcrun simctl list devices available | grep -m 1 -E 'iPhone' | grep -Eo '[0-9A-F-]{36}' | head -n 1)"
if [[ -z "${SIMULATOR_ID}" ]]; then
  echo "No available iPhone simulator was found." >&2
  exit 1
fi

xcodebuild test \
  -scheme SnapTableReminder \
  -destination "platform=iOS Simulator,id=${SIMULATOR_ID}"

xcodebuild build \
  -scheme SnapTableReminder \
  -destination "platform=iOS Simulator,id=${SIMULATOR_ID}"

echo "Mac verification completed."
