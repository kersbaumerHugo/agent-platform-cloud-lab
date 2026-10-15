#!/usr/bin/env bash
# Offline tests for the *same* POSIX activation script used in the container.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACT="$ROOT/apps/floci-http/activate.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export APP_ROOT="$TMP/app"
mkdir -p "$APP_ROOT"
printf '#!/bin/sh\nexit 0\n' > "$APP_ROOT/health-handler.sh"
chmod +x "$APP_ROOT/health-handler.sh"

sh "$ACT" prepare
BOOTSTRAP="$APP_ROOT/releases/bootstrap/handler.sh"
[[ "$(readlink "$APP_ROOT/health-handler.sh")" == "$BOOTSTRAP" ]]
sh "$ACT" prepare  # idempotent
[[ "$(readlink "$APP_ROOT/health-handler.sh")" == "$BOOTSTRAP" ]]

for release in v1.0.0 v1.1.0 v1.2.0-bad v1.3.0 v1.4.0-badlogic; do
  mkdir -p "$APP_ROOT/releases/$release"
  cp "$ROOT/apps/floci-http/releases/$release/handler.sh" "$APP_ROOT/releases/$release/handler.sh"
  chmod +x "$APP_ROOT/releases/$release/handler.sh"
done

sh "$ACT" activate v1.0.0
[[ "$(readlink "$APP_ROOT/health-handler.sh")" == "$APP_ROOT/releases/v1.0.0/handler.sh" ]]
sh "$ACT" activate v1.1.0
GOOD="$(readlink "$APP_ROOT/health-handler.sh")"
sh "$ACT" activate v1.2.0-bad
[[ "$(readlink "$APP_ROOT/health-handler.sh")" == "$APP_ROOT/releases/v1.2.0-bad/handler.sh" ]]
sh "$ACT" restore "$GOOD"
[[ "$(readlink "$APP_ROOT/health-handler.sh")" == "$GOOD" ]]

# Malicious or missing rollback targets must fail closed.
if sh "$ACT" restore /tmp/evil.sh >/dev/null 2>&1; then exit 1; fi
if sh "$ACT" activate v9.9.9 >/dev/null 2>&1; then exit 1; fi
[[ "$(readlink "$APP_ROOT/health-handler.sh")" == "$GOOD" ]]

echo '[PASS] Release activation, rollback and unsafe-target rejection.'
