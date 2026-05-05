#!/usr/bin/env bash
#
# Fetch the SignService SAML SP metadata, ready to upload to the SWAMID QA
# self-service tool: https://metadata.qa.swamid.se/
#
# Requires the stack to be running (docker compose up -d).
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/secrets/sp-metadata.xml}"

# Path is /sign/<engine>/saml/metadata - matches application.yml engines[0].
URL="${SIGNSERVICE_BASE_URL:-https://localhost:8443}/sign/integration-rest/saml/metadata"

echo "==> Fetching SP metadata from $URL"
curl -sk "$URL" -o "$OUT"

if ! head -c 5 "$OUT" | grep -q '<?xml'; then
  echo "ERROR: response is not XML. Contents:" >&2
  cat "$OUT" >&2
  exit 1
fi

echo "==> Wrote $OUT"
echo
echo "Next steps:"
echo "  1. Open https://metadata.qa.swamid.se/"
echo "  2. Sign in (eduGAIN/SWAMID account) and submit a new SP using this XML"
echo "  3. Wait for SWAMID to publish your entity (manual review for QA)"
echo "  4. Once published you can sign in via SWAMID QA IdPs through the SignService"
