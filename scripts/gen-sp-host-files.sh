#!/usr/bin/env bash
#
# Generate the files that the dev sp container mounts read-only, the way a
# production host provides them (see docker-compose.yml):
#   - secrets/sp-host/passwd, group: the image's files, with other ids for
#     _shibd than the image was built with
#   - secrets/sp-host/private, certs: SP key pair (shibsp-<host>) and HTTPS
#     key pair (<host>), keys mode 600 and owned by the host user
#
# With these mounts, a start script that writes /etc/passwd or /etc/group,
# or that expects _shibd to own or reach the SP key, fails in dev too.
#
# Needs the sp image: run `docker compose build sp` first.
# Idempotent: existing files are kept. Pass --force to regenerate.
#
set -euo pipefail

for tool in openssl docker; do
  command -v "$tool" >/dev/null || { echo "ERROR: $tool not found in PATH" >&2; exit 1; }
done

cd "$(dirname "$0")/.."
OUT="secrets/sp-host"
HOST="${SP_HOSTNAME:-dev.edusign.sunet.se}"
SHIBD_ID=4321
[[ "${1:-}" == "--force" ]] && rm -rf "$OUT"
mkdir -p "$OUT/private" "$OUT/certs"

# Plain `docker run`: `docker compose run` would create the networks and
# volumes of the stack.
IMAGE="$(docker compose config --images | grep -- '-sp$')"
from_image() { docker run --rm --entrypoint cat "$IMAGE" "$1"; }

if [[ ! -s "$OUT/passwd" || ! -s "$OUT/group" ]]; then
  from_image /etc/passwd | sed -E "s/^_shibd:x:[0-9]+:[0-9]+:/_shibd:x:$SHIBD_ID:$SHIBD_ID:/" > "$OUT/passwd"
  from_image /etc/group | sed -E "s/^_shibd:x:[0-9]+:/_shibd:x:$SHIBD_ID:/" > "$OUT/group"
  grep -q "^_shibd:x:$SHIBD_ID:" "$OUT/passwd" && grep -q "^_shibd:x:$SHIBD_ID:" "$OUT/group" \
    || { echo "ERROR: no _shibd user or group in the sp image" >&2; rm -f "$OUT/passwd" "$OUT/group"; exit 1; }
  chmod 644 "$OUT/passwd" "$OUT/group"
  echo "generated $OUT/passwd and $OUT/group"
fi

for name in "shibsp-$HOST" "$HOST"; do
  key="$OUT/private/$name.key"; crt="$OUT/certs/$name.crt"
  if [[ ! -s "$key" || ! -s "$crt" ]]; then
    openssl req -x509 -newkey rsa:3072 -nodes -days 3650 -subj "/CN=$HOST" \
      -addext "subjectAltName=DNS:$HOST" -keyout "$key" -out "$crt" 2>/dev/null
    chmod 600 "$key"; chmod 644 "$crt"
    echo "generated $key and $crt"
  fi
done
