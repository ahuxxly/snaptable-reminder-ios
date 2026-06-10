#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${1:-build/app-store-screenshots}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-build/DerivedData-Screenshots}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-build/SnapTableReminderScreenshots.xcresult}"
SCHEME="SnapTableReminderScreenshots"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is missing. Install it with: brew install xcodegen" >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is missing. Install Xcode from the Mac App Store and run xcode-select." >&2
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is missing. Install Xcode command line tools." >&2
  exit 1
fi

pick_simulator_id() {
  if [[ -n "${SCREENSHOT_SIMULATOR_ID:-}" ]]; then
    echo "${SCREENSHOT_SIMULATOR_ID}"
    return
  fi

  local preferred_devices=(
    "iPhone 17 Pro Max"
    "iPhone Air"
    "iPhone 16 Pro Max"
    "iPhone 16 Plus"
    "iPhone 15 Pro Max"
    "iPhone 15 Plus"
    "iPhone 14 Pro Max"
  )

  local device_name
  for device_name in "${preferred_devices[@]}"; do
    local line
    line="$(xcrun simctl list devices available | grep -m 1 -E "^[[:space:]]+${device_name} \\(" || true)"
    if [[ -n "${line}" ]]; then
      echo "${line}" | grep -Eo '[0-9A-Fa-f-]{36}' | head -n 1
      return
    fi
  done

  return 1
}

xcodegen generate

SIMULATOR_ID="$(pick_simulator_id)"
if [[ -z "${SIMULATOR_ID}" ]]; then
  echo "No preferred App Store screenshot simulator was found." >&2
  echo "Install an iPhone Pro Max or Plus simulator, or set SCREENSHOT_SIMULATOR_ID." >&2
  exit 1
fi

rm -rf "${RESULT_BUNDLE_PATH}" "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

xcrun simctl boot "${SIMULATOR_ID}" >/dev/null 2>&1 || true
xcrun simctl bootstatus "${SIMULATOR_ID}" -b

xcodebuild test \
  -scheme "${SCHEME}" \
  -destination "platform=iOS Simulator,id=${SIMULATOR_ID}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -resultBundlePath "${RESULT_BUNDLE_PATH}"

xcrun xcresulttool export attachments \
  --path "${RESULT_BUNDLE_PATH}" \
  --output-path "${OUTPUT_DIR}"

echo "Screenshots exported to ${OUTPUT_DIR}"
find "${OUTPUT_DIR}" -maxdepth 2 -type f | sort
