#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  "APPLE_DISTRIBUTION_CERTIFICATE_BASE64"
  "APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD"
  "APPLE_APP_STORE_PROFILE_BASE64"
  "APPLE_CODESIGN_KEYCHAIN_PASSWORD"
)

mask_value() {
  local value="$1"
  local length="${#value}"
  if [[ "${length}" -le 6 ]]; then
    echo "***"
  else
    echo "${value:0:3}***${value: -3}"
  fi
}

decode_base64() {
  local value="$1"
  local output_path="$2"

  if printf '%s' "${value}" | base64 --decode >"${output_path}" 2>/dev/null; then
    return 0
  fi

  printf '%s' "${value}" | base64 -D >"${output_path}"
}

echo "== Apple signing environment =="

missing=0
for var_name in "${required_vars[@]}"; do
  value="${!var_name:-}"
  if [[ -z "${value}" ]]; then
    echo "${var_name}=missing" >&2
    missing=1
  else
    echo "${var_name}=$(mask_value "${value}")"
  fi
done

if [[ "${missing}" -ne 0 ]]; then
  echo "Set all required Apple signing secrets before TestFlight upload." >&2
  exit 1
fi

if ! command -v security >/dev/null 2>&1; then
  echo "The macOS security tool is required for signing validation." >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "OpenSSL is required to validate the p12 signing certificate." >&2
  exit 1
fi

temp_dir="$(mktemp -d)"
trap 'rm -rf "${temp_dir}"' EXIT

certificate_path="${temp_dir}/distribution.p12"
profile_path="${temp_dir}/app-store.mobileprovision"
profile_plist_path="${temp_dir}/profile.plist"

decode_base64 "${APPLE_DISTRIBUTION_CERTIFICATE_BASE64}" "${certificate_path}"
decode_base64 "${APPLE_APP_STORE_PROFILE_BASE64}" "${profile_path}"

if ! openssl pkcs12 -in "${certificate_path}" -nokeys -passin "pass:${APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD}" -out /dev/null >/dev/null 2>&1; then
  echo "The distribution certificate p12 could not be opened with APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD." >&2
  exit 1
fi

if ! security cms -D -i "${profile_path}" >"${profile_plist_path}" 2>/dev/null; then
  echo "The provisioning profile could not be decoded." >&2
  exit 1
fi

profile_uuid="$(/usr/libexec/PlistBuddy -c 'Print UUID' "${profile_plist_path}")"
profile_name="$(/usr/libexec/PlistBuddy -c 'Print Name' "${profile_plist_path}")"
profile_app_identifier="$(/usr/libexec/PlistBuddy -c 'Print Entitlements:application-identifier' "${profile_plist_path}")"
get_task_allow="$(/usr/libexec/PlistBuddy -c 'Print Entitlements:get-task-allow' "${profile_plist_path}" 2>/dev/null || true)"

if [[ -z "${profile_uuid}" || -z "${profile_name}" ]]; then
  echo "The provisioning profile is missing UUID or Name." >&2
  exit 1
fi

if [[ "${profile_app_identifier}" != *".com.snaptable.reminder" ]]; then
  echo "The provisioning profile does not target com.snaptable.reminder: ${profile_app_identifier}" >&2
  exit 1
fi

if [[ "${get_task_allow}" == "true" ]]; then
  echo "The provisioning profile appears to be a development profile, not an App Store distribution profile." >&2
  exit 1
fi

echo "Provisioning profile: ${profile_name} (${profile_uuid})"
echo "Apple signing environment looks ready."
