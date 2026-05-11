#!/usr/bin/env bash
#
# Generate dev crypto material + fetch SWAMID QA federation trust:
#   - integration-rest signing keypair (PKCS12 + PEM cert)
#   - signservice SAML SP signing+encryption keystore (PKCS12, two entries)
#   - SWAMID QA metadata signing certificate (with fingerprint verification)
#   - copy of the signservice demo response-signing cert
#
# Idempotent: re-runs leave existing files in place. Pass --force to regenerate.
#
set -euo pipefail

for tool in openssl curl; do
  command -v "$tool" >/dev/null || { echo "ERROR: $tool not found in PATH" >&2; exit 1; }
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS="$ROOT/secrets"
FORCE="${1:-}"

mkdir -p "$SECRETS"
# Dir + .p12s must be readable by container UIDs 10001/10002 (the bind-mount is :ro,
# but POSIX perms still apply). Keystore passwords ("changeit"/"secret") are the
# real gate in dev; world-readable .p12s are fine here, not in production.
chmod 755 "$SECRETS"

# SIGNSERVICE_HOME bind-mount target. The signservice container (UID 10002)
# writes audit logs, CRL files, and MDQ backup material here at runtime, so
# the host dir must be writable by that UID. 1777 (sticky world-writable) is
# the simplest option that doesn't require sudo on the host.
DATA="$ROOT/ss-dev-src/signservice"
mkdir -p "$DATA"
chmod 1777 "$DATA"

PASS="changeit"

# --- integration-rest SignRequest signing keypair --------------------------
IR_P12="$SECRETS/integration-rest-signing.p12"
IR_CRT="$SECRETS/integration-rest-signing.crt"
IR_KEY="$SECRETS/integration-rest-signing.key"
IR_ALIAS="integration-rest"
IR_SUBJ="/C=SE/O=Dev/OU=integration-rest/CN=integration-rest.dev.local"

if [[ "$FORCE" == "--force" ]]; then
  rm -f "$IR_P12" "$IR_CRT" "$IR_KEY"
fi

if [[ ! -f "$IR_P12" ]]; then
  echo "==> Generating integration-rest SignRequest signing keypair"
  openssl req -x509 -newkey rsa:3072 -sha256 -days 1825 -nodes \
    -keyout "$IR_KEY" -out "$IR_CRT" -subj "$IR_SUBJ"
  openssl pkcs12 -export \
    -inkey "$IR_KEY" -in "$IR_CRT" \
    -name "$IR_ALIAS" -out "$IR_P12" \
    -passout "pass:$PASS"
  chmod 644 "$IR_P12"
  chmod 600 "$IR_KEY"
else
  echo "==> integration-rest signing keypair already present"
fi

# --- signservice SAML SP signing + encryption keystores --------------------
# Two separate single-entry PKCS12 files. The signservice config references
# each as its own keystore bundle - this avoids a keytool dependency on the
# host (keytool ships with the JDK, not always present on a docker host).
SP_SIGN_P12="$SECRETS/swamid-saml-sp-sign.p12"
SP_ENC_P12="$SECRETS/swamid-saml-sp-encrypt.p12"
SP_SIGN_CRT="$SECRETS/swamid-saml-sp-sign.crt"
SP_ENC_CRT="$SECRETS/swamid-saml-sp-encrypt.crt"
SP_SIGN_KEY="$(mktemp)"
SP_ENC_KEY="$(mktemp)"
trap 'rm -f "$SP_SIGN_KEY" "$SP_ENC_KEY"' EXIT

# The CN doesn't have to encode the entityID - SAML peers verify the public key,
# not the cert subject. Keep the CN simple to avoid issues with reserved DN chars.
SP_SIGN_SUBJ="/C=SE/O=Dev/OU=SignService SAML SP/CN=signservice-saml-sp-sign"
SP_ENC_SUBJ="/C=SE/O=Dev/OU=SignService SAML SP/CN=signservice-saml-sp-encrypt"

if [[ "$FORCE" == "--force" ]]; then
  rm -f "$SP_SIGN_P12" "$SP_ENC_P12" "$SP_SIGN_CRT" "$SP_ENC_CRT"
fi

if [[ ! -f "$SP_SIGN_P12" ]]; then
  echo "==> Generating SAML SP signing keypair"
  openssl req -x509 -newkey rsa:3072 -sha256 -days 1825 -nodes \
    -keyout "$SP_SIGN_KEY" -out "$SP_SIGN_CRT" -subj "$SP_SIGN_SUBJ"
  openssl pkcs12 -export -inkey "$SP_SIGN_KEY" -in "$SP_SIGN_CRT" \
    -name sign -out "$SP_SIGN_P12" -passout "pass:$PASS"
  chmod 644 "$SP_SIGN_P12"
else
  echo "==> SAML SP signing keystore already present"
fi

if [[ ! -f "$SP_ENC_P12" ]]; then
  echo "==> Generating SAML SP encryption keypair"
  openssl req -x509 -newkey rsa:3072 -sha256 -days 1825 -nodes \
    -keyout "$SP_ENC_KEY" -out "$SP_ENC_CRT" -subj "$SP_ENC_SUBJ"
  openssl pkcs12 -export -inkey "$SP_ENC_KEY" -in "$SP_ENC_CRT" \
    -name encrypt -out "$SP_ENC_P12" -passout "pass:$PASS"
  chmod 644 "$SP_ENC_P12"
else
  echo "==> SAML SP encryption keystore already present"
fi

# --- SWAMID QA metadata signing certificate --------------------------------
# Source of truth: https://wiki.sunet.se/display/SWAMID/Metadata+for+SWAMID+QA
SWAMID_CRT_URL="https://mds.swamid.se/qa/md/swamid-qa.crt"
SWAMID_CRT_FP="1E:BC:8E:62:0B:C9:3C:EB:C6:E0:7F:9E:34:B8:A1:9F:EA:A9:30:A1:9E:B5:31:B9:44:8B:0F:CC:3B:D9:17:D2"
SWAMID_CRT="$SECRETS/swamid-qa-md-signer.crt"

if [[ "$FORCE" == "--force" ]]; then
  rm -f "$SWAMID_CRT"
fi

if [[ ! -f "$SWAMID_CRT" ]]; then
  echo "==> Downloading SWAMID QA metadata signing certificate"
  curl -fsSL "$SWAMID_CRT_URL" -o "$SWAMID_CRT.tmp"
  ACTUAL_FP=$(openssl x509 -in "$SWAMID_CRT.tmp" -noout -fingerprint -sha256 \
    | sed 's/^.*Fingerprint=//')
  if [[ "$ACTUAL_FP" != "$SWAMID_CRT_FP" ]]; then
    echo "ERROR: SWAMID QA cert fingerprint mismatch" >&2
    echo "  expected: $SWAMID_CRT_FP" >&2
    echo "  got:      $ACTUAL_FP" >&2
    rm -f "$SWAMID_CRT.tmp"
    exit 1
  fi
  mv "$SWAMID_CRT.tmp" "$SWAMID_CRT"
  echo "    fingerprint verified: $SWAMID_CRT_FP"
else
  echo "==> SWAMID QA metadata signing cert already present"
fi

# --- signservice response-signing cert (from cloned demo app) --------------
SS_CRT="$SECRETS/sign-service-cert.pem"
SRC_SS_CRT="$ROOT/signservice/demo-apps/app/src/main/resources/signservice.crt"
if [[ ! -f "$SS_CRT" ]]; then
  if [[ ! -f "$SRC_SS_CRT" ]]; then
    echo "ERROR: $SRC_SS_CRT not found - clone the signservice repo first." >&2
    exit 1
  fi
  echo "==> Copying signservice response-signing cert"
  cp "$SRC_SS_CRT" "$SS_CRT"
fi

echo
echo "Generated:"
ls -l "$SECRETS"
