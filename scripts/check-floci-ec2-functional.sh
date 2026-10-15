#!/usr/bin/env bash
# Functional HTTP smoke against the local Floci EC2; this is not AWS or a full production E2E.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK="$ROOT/infra/opentofu/stacks/aws/local"

for cmd in docker timeout; do
  command -v "$cmd" >/dev/null || { echo "[ERROR] Missing command: $cmd" >&2; exit 2; }
done

if (( $# > 1 )); then
  echo 'Usage: check-floci-ec2-functional.sh [floci-ec2-i-INSTANCE]' >&2
  exit 2
fi
if (( $# == 1 )); then
  CONTAINER="$1"
else
  command -v tofu >/dev/null || { echo '[ERROR] Missing command: tofu' >&2; exit 2; }
  INSTANCE_ID="$(tofu -chdir="$STACK" output -raw app_instance_id)"
  CONTAINER="floci-ec2-$INSTANCE_ID"
fi
[[ "$CONTAINER" =~ ^floci-ec2-i-[[:alnum:]]+$ ]] || {
  echo "[ERROR] Unexpected Floci container name: $CONTAINER" >&2
  exit 2
}

probe() {
  local a="$1" b="$2" expected="$3" response
  if ! response="$(timeout 5s docker exec "$CONTAINER" \
    wget -qO- -T 2 "http://127.0.0.1:8080/sum?a=$a&b=$b" 2>/dev/null)"; then
    echo "[FAIL] Functional smoke: GET /sum?a=$a&b=$b failed HTTP/transport" >&2
    return 1
  fi
  if [[ "$response" != "$expected" ]]; then
    echo "[FAIL] Functional smoke: $a + $b expected $expected, got '$response'" >&2
    return 1
  fi
  echo "[PASS] Functional smoke: $a + $b = $expected"
}

probe 2 3 5
probe 7 4 11
