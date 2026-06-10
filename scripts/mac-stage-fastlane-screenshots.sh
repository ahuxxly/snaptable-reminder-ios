#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${1:-build/app-store-screenshots}"
DESTINATION_DIR="${2:-fastlane/screenshots/en-US}"

required_names=(
  "01-Capture"
  "02-Records"
  "03-Dashboard"
  "04-Settings"
)

if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "Screenshot source directory does not exist: ${SOURCE_DIR}" >&2
  exit 1
fi

image_files=()
while IFS= read -r image_file; do
  image_files+=("${image_file}")
done < <(find "${SOURCE_DIR}" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | sort)

if [[ "${#image_files[@]}" -lt 4 ]]; then
  echo "Expected at least four screenshot files in ${SOURCE_DIR}; found ${#image_files[@]}." >&2
  exit 1
fi

rm -rf "${DESTINATION_DIR}"
mkdir -p "${DESTINATION_DIR}"

copy_named_or_sorted() {
  local expected_name="$1"
  local sorted_index="$2"
  local source_file=""
  local file

  for file in "${image_files[@]}"; do
    if [[ "$(basename "${file}")" == *"${expected_name}"* ]]; then
      source_file="${file}"
      break
    fi
  done

  if [[ -z "${source_file}" ]]; then
    source_file="${image_files[${sorted_index}]}"
    echo "Could not find exported attachment named ${expected_name}; using sorted file ${source_file}" >&2
  fi

  cp "${source_file}" "${DESTINATION_DIR}/${expected_name}.png"
}

for index in "${!required_names[@]}"; do
  copy_named_or_sorted "${required_names[$index]}" "${index}"
done

echo "Fastlane screenshots staged in ${DESTINATION_DIR}"
find "${DESTINATION_DIR}" -maxdepth 1 -type f | sort
