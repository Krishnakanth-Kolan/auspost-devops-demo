#!/usr/bin/env bash
set -euo pipefail
URL="${1:-http://localhost:8080/healthz}"
EXPECTED_VERSION="${2:-}"

response="$(curl --fail --silent --show-error --retry 10 --retry-delay 3 "$URL")"
echo "$response"

echo "$response" | grep -q '"status":"success"' || {
  echo "Health response did not report success" >&2
  exit 1
}

if [[ -n "$EXPECTED_VERSION" ]]; then
  echo "$response" | grep -q "\"version\":\"$EXPECTED_VERSION\"" || {
    echo "Expected version $EXPECTED_VERSION was not returned" >&2
    exit 1
  }
fi
