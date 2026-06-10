#!/usr/bin/env bash
set -euo pipefail

log_section() {
  local title="$1"
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::group::${title}"
  else
    echo "== ${title} =="
  fi
}

end_section() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::endgroup::"
  fi
}

run_timed() {
  local title="$1"
  shift

  log_section "${title}"
  local start_time
  start_time="$(date +%s)"
  echo "started_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "+ $*"
  local status
  if "$@"; then
    status=0
  else
    status=$?
  fi
  local end_time
  end_time="$(date +%s)"
  echo "finished_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "duration_seconds=$((end_time - start_time))"
  end_section
  return "${status}"
}

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is missing. Install it with: brew install xcodegen" >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is missing. Install Xcode from the Mac App Store and run xcode-select." >&2
  exit 1
fi

run_timed "Generate Xcode project" xcodegen generate

SIMULATOR_ID="$(xcrun simctl list devices available | grep -m 1 -E 'iPhone' | grep -Eo '[0-9A-F-]{36}' | head -n 1)"
if [[ -z "${SIMULATOR_ID}" ]]; then
  echo "No available iPhone simulator was found." >&2
  exit 1
fi
SIMULATOR_NAME="$(xcrun simctl list devices available | grep "${SIMULATOR_ID}" | sed -E 's/^[[:space:]]*([^()]*) .*/\1/' | xargs)"
echo "simulator_id=${SIMULATOR_ID}"
echo "simulator_name=${SIMULATOR_NAME}"

run_timed "xcodebuild test SnapTableReminder" xcodebuild test \
  -scheme SnapTableReminder \
  -destination "platform=iOS Simulator,id=${SIMULATOR_ID}"

run_timed "xcodebuild build SnapTableReminder" xcodebuild build \
  -scheme SnapTableReminder \
  -destination "platform=iOS Simulator,id=${SIMULATOR_ID}"

run_timed "xcodebuild build-for-testing SnapTableReminderScreenshots" xcodebuild build-for-testing \
  -scheme SnapTableReminderScreenshots \
  -destination "platform=iOS Simulator,id=${SIMULATOR_ID}"

echo "Mac verification completed."
