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

xcodebuild test \
  -scheme SnapTableReminder \
  -destination 'platform=iOS Simulator,name=iPhone 15'

xcodebuild build \
  -scheme SnapTableReminder \
  -destination 'platform=iOS Simulator,name=iPhone 15'

echo "Mac verification completed."
