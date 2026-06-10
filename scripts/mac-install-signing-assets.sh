#!/usr/bin/env bash
set -euo pipefail

decode_base64() {
  local value="$1"
  local output_path="$2"

  if printf '%s' "${value}" | base64 --decode >"${output_path}" 2>/dev/null; then
    return 0
  fi

  printf '%s' "${value}" | base64 -D >"${output_path}"
}

bash scripts/mac-validate-signing-env.sh

signing_dir="${RUNNER_TEMP:-$(mktemp -d)}/apple-signing"
mkdir -p "${signing_dir}"

certificate_path="${signing_dir}/distribution.p12"
profile_path="${signing_dir}/app-store.mobileprovision"
profile_plist_path="${signing_dir}/profile.plist"
keychain_path="${signing_dir}/snaptable-signing.keychain-db"

decode_base64 "${APPLE_DISTRIBUTION_CERTIFICATE_BASE64}" "${certificate_path}"
decode_base64 "${APPLE_APP_STORE_PROFILE_BASE64}" "${profile_path}"

security create-keychain -p "${APPLE_CODESIGN_KEYCHAIN_PASSWORD}" "${keychain_path}"
security set-keychain-settings -lut 21600 "${keychain_path}"
security unlock-keychain -p "${APPLE_CODESIGN_KEYCHAIN_PASSWORD}" "${keychain_path}"

existing_keychains=()
while IFS= read -r existing_keychain; do
  existing_keychain="${existing_keychain//\"/}"
  existing_keychain="${existing_keychain#"${existing_keychain%%[![:space:]]*}"}"
  existing_keychain="${existing_keychain%"${existing_keychain##*[![:space:]]}"}"
  if [[ -n "${existing_keychain}" ]]; then
    existing_keychains+=("${existing_keychain}")
  fi
done < <(security list-keychains -d user)

security list-keychains -d user -s "${keychain_path}" "${existing_keychains[@]}"
security import "${certificate_path}" \
  -k "${keychain_path}" \
  -P "${APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD}" \
  -T /usr/bin/codesign \
  -T /usr/bin/security
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "${APPLE_CODESIGN_KEYCHAIN_PASSWORD}" \
  "${keychain_path}"

security cms -D -i "${profile_path}" >"${profile_plist_path}"
profile_uuid="$(/usr/libexec/PlistBuddy -c 'Print UUID' "${profile_plist_path}")"
profile_name="$(/usr/libexec/PlistBuddy -c 'Print Name' "${profile_plist_path}")"

profile_install_dir="${HOME}/Library/MobileDevice/Provisioning Profiles"
mkdir -p "${profile_install_dir}"
cp "${profile_path}" "${profile_install_dir}/${profile_uuid}.mobileprovision"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "APPLE_CODESIGN_KEYCHAIN_PATH=${keychain_path}"
    echo "APPLE_PROVISIONING_PROFILE_SPECIFIER=${profile_name}"
  } >>"${GITHUB_ENV}"
fi

echo "Installed signing certificate in temporary keychain."
echo "Installed provisioning profile: ${profile_name} (${profile_uuid})"
