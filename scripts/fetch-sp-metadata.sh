#!/usr/bin/env bash
#
# Fetch the SignService SAML SP metadata for both engines, ready to register
# in the federations:
#   - integration-rest (SWAMID-style engine, eduID et al.):
#       register in SWAMID QA: https://metadata.qa.swamid.se/
#   - integration-rest-sc (Sweden Connect-style engine, BankID + Freja+):
#       register in SWAMID QA (the test BankID IdP lives there) AND in the
#       Sweden Connect test federation (for Freja).
#
# Requires the stack to be running (docker compose up -d).
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="${SIGNSERVICE_BASE_URL:-https://localhost:8443}"
OUT_DIR="${1:-$ROOT/secrets}"

fetch() {
  local engine="$1" out="$2"
  # Path is /sign/<engine>/saml/metadata - matches application.yml engines[].
  local url="$BASE/sign/$engine/saml/metadata"
  echo "==> Fetching SP metadata from $url"
  curl -sk "$url" -o "$out"
  if ! head -c 5 "$out" | grep -q '<?xml'; then
    echo "ERROR: response is not XML. Contents:" >&2
    cat "$out" >&2
    exit 1
  fi
  echo "==> Wrote $out"
}

fetch integration-rest "$OUT_DIR/sp-metadata.xml"
fetch integration-rest-sc "$OUT_DIR/sp-sc-metadata.xml"

echo
echo "Next steps:"
echo "  1. Open https://metadata.qa.swamid.se/"
echo "  2. Sign in (eduGAIN/SWAMID account) and submit BOTH SPs:"
echo "     - sp-metadata.xml    (SWAMID-style engine, eduID et al.)"
echo "     - sp-sc-metadata.xml (Sweden Connect-style engine; the test BankID"
echo "       IdP reads SP metadata from SWAMID QA)"
echo "  3. Register sp-sc-metadata.xml in the Sweden Connect test federation"
echo "     as well, so the Freja IdP trusts it"
echo "  4. Wait for the registrations to be published (manual review for QA)"
