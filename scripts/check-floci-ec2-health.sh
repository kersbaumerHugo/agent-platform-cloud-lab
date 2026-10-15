#!/usr/bin/env bash
# Readiness smoke for the existing Floci-backed EC2 instance. No AWS real calls.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK="$ROOT/infra/opentofu/stacks/aws/local"
TIMEOUT_SECONDS="${HEALTH_TIMEOUT_SECONDS:-300}"
INTERVAL_SECONDS="${HEALTH_INTERVAL_SECONDS:-5}"
HEALTH_PATH="${HEALTH_PATH:-/health}"

for value in "$TIMEOUT_SECONDS" "$INTERVAL_SECONDS"; do
  if ! [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "[ERROR] Timeout and interval must be positive integers (seconds)." >&2
    exit 2
  fi
done
if [[ "$HEALTH_PATH" != /* ]]; then
  echo "[ERROR] HEALTH_PATH must start with '/'." >&2
  exit 2
fi
for command in tofu docker timeout; do
  if ! command -v "$command" >/dev/null; then
    echo "[ERROR] Required command not found: $command" >&2
    exit 2
  fi
done

if ! INSTANCE_ID="$(tofu -chdir="$STACK" output -raw app_instance_id)"; then
  echo "[ERROR] Could not read app_instance_id from the local Floci state." >&2
  exit 2
fi
if ! [[ "$INSTANCE_ID" =~ ^i-[[:alnum:]]+$ ]]; then
  echo "[ERROR] Unexpected Floci instance ID: $INSTANCE_ID" >&2
  exit 2
fi
CONTAINER="floci-ec2-$INSTANCE_ID"
STARTED=$(date +%s)
DEADLINE=$((STARTED + TIMEOUT_SECONDS))
ATTEMPT=0

echo "[INFO] Readiness check: container=$CONTAINER path=$HEALTH_PATH timeout=${TIMEOUT_SECONDS}s interval=${INTERVAL_SECONDS}s"
while :; do
  NOW=$(date +%s)
  REMAINING=$((DEADLINE - NOW))
  if (( REMAINING <= 0 )); then
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  PROBE_LIMIT=$((REMAINING < 5 ? REMAINING : 5))
  if RESPONSE="$(timeout "${PROBE_LIMIT}s" docker exec "$CONTAINER" \
      wget -qO- -T 2 "http://127.0.0.1:8080${HEALTH_PATH}" 2>/dev/null)" \
      && [[ "$RESPONSE" == "ok" ]]; then
    echo "[PASS] HTTP health returned 'ok' after $(( $(date +%s) - STARTED ))s ($ATTEMPT attempts)."
    exit 0
  fi

  NOW=$(date +%s)
  REMAINING=$((DEADLINE - NOW))
  if (( REMAINING <= 0 )); then
    break
  fi
  echo "[WAIT] Attempt $ATTEMPT: app not ready; ${REMAINING}s remaining."
  SLEEP_FOR=$((INTERVAL_SECONDS < REMAINING ? INTERVAL_SECONDS : REMAINING))
  sleep "$SLEEP_FOR"
done

echo "[FAIL] Application did not return 'ok' within ${TIMEOUT_SECONDS}s ($ATTEMPT attempts)." >&2
echo "[DIAG] Docker container state:" >&2
docker inspect --format '{{.State.Status}}' "$CONTAINER" >&2 || true
echo "[DIAG] App process / listener logs:" >&2
docker exec "$CONTAINER" sh -c \
  'ps | grep "[n]c -lk" || true; cat /tmp/health-listener.log 2>/dev/null || true' >&2 || true
echo "[DIAG] Recent Floci logs:" >&2
docker logs --tail 60 agent-platform-floci-aws >&2 || true
exit 1
