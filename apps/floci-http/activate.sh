#!/bin/sh
# Executed inside the Floci-backed EC2 container. POSIX sh; no downloads.
set -eu

APP_ROOT="${APP_ROOT:-/srv/app}"
ACTIVE="$APP_ROOT/health-handler.sh"
RELEASES="$APP_ROOT/releases"

activate_target() {
  target="$1"
  [ -f "$target" ] || { echo "[ERROR] Release handler missing: $target" >&2; exit 2; }
  [ -x "$target" ] || { echo "[ERROR] Release handler not executable: $target" >&2; exit 2; }
  temporary="$APP_ROOT/.handler-next-$$"
  trap 'rm -f "$temporary"' 0
  ln -s "$target" "$temporary"
  # Atomic rename of a symlink to a file, so requests see old or new release.
  mv -f "$temporary" "$ACTIVE"
  trap - 0
}

case "${1:-}" in
  prepare)
    [ -f "$ACTIVE" ] || { echo "[ERROR] Bootstrap handler missing." >&2; exit 2; }
    if [ ! -L "$ACTIVE" ]; then
      mkdir -p "$RELEASES/bootstrap"
      cp "$ACTIVE" "$RELEASES/bootstrap/handler.sh"
      chmod 755 "$RELEASES/bootstrap/handler.sh"
      activate_target "$RELEASES/bootstrap/handler.sh"
    fi
    ;;
  activate)
    version="${2:-}"
    case "$version" in
      v[0-9]*) ;;
      *) echo "[ERROR] Invalid version." >&2; exit 2 ;;
    esac
    # Host orchestrator does strict version validation; verify here too.
    echo "$version" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9]+)?$' || exit 2
    activate_target "$RELEASES/$version/handler.sh"
    ;;
  restore)
    target="${2:-}"
    case "$target" in
      "$RELEASES"/*/handler.sh) activate_target "$target" ;;
      *) echo "[ERROR] Unsafe rollback target." >&2; exit 2 ;;
    esac
    ;;
  *) echo "Usage: sh activate.sh {prepare|activate VERSION|restore TARGET}" >&2; exit 2 ;;
esac
