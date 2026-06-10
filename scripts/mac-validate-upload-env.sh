#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  "APP_STORE_CONNECT_USERNAME"
  "APPLE_DEVELOPER_TEAM_ID"
  "APP_STORE_CONNECT_API_KEY_ID"
  "APP_STORE_CONNECT_API_ISSUER_ID"
  "APP_STORE_CONNECT_API_KEY_PATH"
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

echo "== Fastlane upload environment =="

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
  echo "Set all required App Store Connect environment variables before upload." >&2
  exit 1
fi

key_path="${APP_STORE_CONNECT_API_KEY_PATH}"
if [[ "${key_path}" != /* ]]; then
  echo "APP_STORE_CONNECT_API_KEY_PATH must be an absolute path." >&2
  exit 1
fi

if [[ ! -f "${key_path}" ]]; then
  echo "App Store Connect API key file was not found: ${key_path}" >&2
  exit 1
fi

if [[ "${key_path}" != *.p8 ]]; then
  echo "App Store Connect API key file should use the .p8 extension." >&2
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
key_dir="$(cd "$(dirname "${key_path}")" && pwd -P)"
key_realpath="${key_dir}/$(basename "${key_path}")"
repo_realpath="$(cd "${repo_root}" && pwd -P)"

case "${key_realpath}" in
  "${repo_realpath}"/*)
    echo "Do not store the App Store Connect .p8 key inside this repository." >&2
    exit 1
    ;;
esac

if git ls-files --error-unmatch "${key_path}" >/dev/null 2>&1; then
  echo "The App Store Connect .p8 key appears to be tracked by git." >&2
  exit 1
fi

if ! head -n 1 "${key_path}" | grep -q "BEGIN PRIVATE KEY"; then
  echo "The .p8 file does not look like an App Store Connect private key." >&2
  exit 1
fi

if [[ ! "${APP_STORE_CONNECT_API_ISSUER_ID}" =~ ^[0-9a-fA-F-]{36}$ ]]; then
  echo "APP_STORE_CONNECT_API_ISSUER_ID should look like a UUID." >&2
  exit 1
fi

if [[ ! "${APPLE_DEVELOPER_TEAM_ID}" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "APPLE_DEVELOPER_TEAM_ID should look like a 10-character Apple team id." >&2
  exit 1
fi

echo "Fastlane upload environment looks ready."
