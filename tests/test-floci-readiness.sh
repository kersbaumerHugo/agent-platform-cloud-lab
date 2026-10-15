#!/usr/bin/env bash
# Fast offline tests: fake tofu/Docker, no Floci or AWS required.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/tofu" <<'MOCK'
#!/bin/sh
printf 'i-test123\n'
MOCK
cat > "$TMP/docker" <<'MOCK'
#!/bin/sh
case "$1" in
  exec)
    if [ "${MOCK_APP_READY:-0}" = 1 ]; then
      printf 'ok\n'
      exit 0
    fi
    exit 1 ;;
  inspect|logs) exit 0 ;;
  *) exit 2 ;;
esac
MOCK
chmod +x "$TMP/tofu" "$TMP/docker"

bash -n "$ROOT/scripts/check-floci-ec2-health.sh"
PATH="$TMP:$PATH" MOCK_APP_READY=1 HEALTH_TIMEOUT_SECONDS=3 \
  bash "$ROOT/scripts/check-floci-ec2-health.sh" > "$TMP/pass.log"
grep -q '\[PASS\]' "$TMP/pass.log"

if PATH="$TMP:$PATH" MOCK_APP_READY=0 HEALTH_TIMEOUT_SECONDS=2 \
   HEALTH_INTERVAL_SECONDS=1 bash "$ROOT/scripts/check-floci-ec2-health.sh" \
   > "$TMP/fail.log" 2>&1; then
  echo "[ERROR] Unready service unexpectedly passed." >&2
  exit 1
fi
grep -q '\[FAIL\]' "$TMP/fail.log"
echo '[PASS] Offline readiness tests: healthy and timeout cases.'
