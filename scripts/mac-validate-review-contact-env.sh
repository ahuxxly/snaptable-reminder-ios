#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  "APP_REVIEW_FIRST_NAME"
  "APP_REVIEW_LAST_NAME"
  "APP_REVIEW_EMAIL"
  "APP_REVIEW_PHONE"
)

mask_value() {
  local value="$1"
  local length="${#value}"
  if [[ "${length}" -le 4 ]]; then
    echo "***"
  else
    echo "${value:0:2}***${value: -2}"
  fi
}

echo "== App Review contact environment =="

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
  echo "Set all required App Review contact environment variables before final submission." >&2
  exit 1
fi

if [[ ! "${APP_REVIEW_EMAIL}" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
  echo "APP_REVIEW_EMAIL should be a valid email address." >&2
  exit 1
fi

if [[ ! "${APP_REVIEW_PHONE}" =~ ^\+?[0-9][0-9[:space:]().-]{6,}$ ]]; then
  echo "APP_REVIEW_PHONE should be a review-reachable phone number." >&2
  exit 1
fi

echo "App Review contact environment looks ready."
