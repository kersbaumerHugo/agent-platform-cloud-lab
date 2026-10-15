#!/usr/bin/env bash
# Local-only deployment against the Floci simulated EC2 Docker container.
# Releases are versioned in Git; OpenTofu provisions infra, this script deploys app.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK="$ROOT/infra/opentofu/stacks/aws/local"
ACTIVATOR="$ROOT/apps/floci-http/activate.sh"
VERSION="${1:-}"

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9]+)?$ ]]; then
  echo "Usage: bash scripts/deploy-floci-ec2-app.sh v1.0.0" >&2
  exit 2
fi
RELEASE="$ROOT/apps/floci-http/releases/$VERSION/handler.sh"
if [[ ! -f "$RELEASE" ]]; then
  echo "[ERROR] Release is not in Git worktree: $RELEASE" >&2
  exit 2
fi
for cmd in tofu docker timeout; do
  command -v "$cmd" >/dev/null || { echo "[ERROR] Missing command: $cmd" >&2; exit 2; }
done

INSTANCE_ID="$(tofu -chdir="$STACK" output -raw app_instance_id)"
[[ "$INSTANCE_ID" =~ ^i-[[:alnum:]]+$ ]] || { echo "[ERROR] Bad instance ID" >&2; exit 2; }
CONTAINER="floci-ec2-$INSTANCE_ID"
docker inspect "$CONTAINER" >/dev/null

remote_activate() {
  docker exec -i "$CONTAINER" sh -s -- "$@" < "$ACTIVATOR"
}

# Bootstrap already provides a handler used by BusyBox nc. Preserve it as
# the first rollback target; later activation swaps the handler symlink.
remote_activate prepare
PREVIOUS="$(docker exec "$CONTAINER" readlink /srv/app/health-handler.sh)"
[[ "$PREVIOUS" == /srv/app/releases/*/handler.sh ]] || {
  echo "[ERROR] Unsafe previous release: $PREVIOUS" >&2; exit 2;
}

DEST="/srv/app/releases/$VERSION/handler.sh"
if docker exec "$CONTAINER" test -e "$DEST"; then
  echo "[ERROR] $VERSION already exists in the instance; release artifacts are immutable." >&2
  exit 2
fi

docker exec "$CONTAINER" mkdir -p "/srv/app/releases/$VERSION"
docker cp "$RELEASE" "$CONTAINER:$DEST"
docker exec "$CONTAINER" chmod 755 "$DEST"

echo "[DEPLOY] $VERSION (previous: $PREVIOUS)"
remote_activate activate "$VERSION"

# Reuse the existing bounded readiness test. /version additionally ensures
# a stale old release cannot falsely pass a /health-only deployment gate.
if HEALTH_TIMEOUT_SECONDS="${DEPLOY_TIMEOUT_SECONDS:-20}" \
    HEALTH_INTERVAL_SECONDS="${DEPLOY_INTERVAL_SECONDS:-2}" \
    bash "$ROOT/scripts/check-floci-ec2-health.sh" \
    && ACTUAL="$(timeout 5s docker exec "$CONTAINER" \
         wget -qO- -T 2 http://127.0.0.1:8080/version 2>/dev/null)" \
    && [[ "$ACTUAL" == "$VERSION" ]]; then
  echo "[PASS] Release $VERSION is ready (/health=ok, /version=$VERSION)."
  exit 0
fi

echo "[ROLLBACK] Release $VERSION failed readiness/version check; restoring $PREVIOUS." >&2
remote_activate restore "$PREVIOUS"
if HEALTH_TIMEOUT_SECONDS=15 HEALTH_INTERVAL_SECONDS=2 \
    bash "$ROOT/scripts/check-floci-ec2-health.sh"; then
  echo "[RECOVERED] Previous release is healthy: $PREVIOUS" >&2
else
  echo "[CRITICAL] Rollback performed, but previous release is NOT healthy." >&2
fi
exit 1
