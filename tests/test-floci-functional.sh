#!/usr/bin/env bash
# Offline contract for the *exact* POSIX release handlers executed inside Floci.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GOOD="$ROOT/apps/floci-http/releases/v1.3.0/handler.sh"
BAD="$ROOT/apps/floci-http/releases/v1.4.0-badlogic/handler.sh"

request() {
  local handler="$1" path="$2"
  printf 'GET %s HTTP/1.1\r\nHost: localhost\r\n\r\n' "$path" | sh "$handler"
}
assert_result() {
  local handler="$1" path="$2" expected="$3" status="$4" response first body
  response="$(request "$handler" "$path")"
  first="$(printf '%s\n' "$response" | head -n1 | tr -d '\r')"
  body="${response##*$'\n'}"
  [[ "$first" == "HTTP/1.1 $status" ]] || { echo "[FAIL] Status for $path: $first"; exit 1; }
  [[ "$body" == "$expected" ]] || { echo "[FAIL] Body for $path: got '$body', expected '$expected'"; exit 1; }
}

assert_result "$GOOD" /health ok '200 OK'
assert_result "$GOOD" /version v1.3.0 '200 OK'
assert_result "$GOOD" '/sum?a=2&b=3' 5 '200 OK'
assert_result "$GOOD" '/sum?a=7&b=4' 11 '200 OK'
assert_result "$GOOD" '/sum?a=abc&b=4' 'invalid a' '400 Bad Request'
assert_result "$BAD" /health ok '200 OK'
assert_result "$BAD" /version v1.4.0-badlogic '200 OK'
assert_result "$BAD" '/sum?a=2&b=3' 6 '200 OK'
assert_result "$BAD" '/sum?a=7&b=4' 12 '200 OK'

echo '[PASS] Functional contracts: good version correct, badlogic version fails business assertions despite /health=ok.'

# Exercise the live probe script against a fake Docker CLI which executes the
# actual checked-in handler. This asserts the deployment gate rejects badlogic.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat > "$TMP/bin/docker" <<'MOCK_DOCKER'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == exec ]] || exit 2
url="${@: -1}"
path="${url#http://127.0.0.1:8080}"
response="$(printf 'GET %s HTTP/1.1\r\n\r\n' "$path" | sh "$MOCK_HANDLER")"
status="$(printf '%s\n' "$response" | head -n1 | tr -d '\r')"
[[ "$status" == 'HTTP/1.1 200 OK' ]] || exit 1
printf '%s\n' "${response##*$'\n'}"
MOCK_DOCKER
chmod +x "$TMP/bin/docker"
export PATH="$TMP/bin:$PATH"
export MOCK_HANDLER="$GOOD"
bash "$ROOT/scripts/check-floci-ec2-functional.sh" floci-ec2-i-test
export MOCK_HANDLER="$BAD"
if bash "$ROOT/scripts/check-floci-ec2-functional.sh" floci-ec2-i-test >"$TMP/bad.out" 2>&1; then
  echo '[FAIL] Defective release unexpectedly passed functional smoke.' >&2
  exit 1
fi
grep -Fq "expected 5, got '6'" "$TMP/bad.out"
echo '[PASS] Functional smoke gate accepts the correct release and rejects badlogic.'
