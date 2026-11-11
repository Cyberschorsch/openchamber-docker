#!/usr/bin/env bash
# Usage: smoke-test.sh <image> <expected-opencode-version>
set -euo pipefail

IMG="$1"
EXPECTED_OPENCODE="$2"
NAME="oc-smoke"

docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" -p 3000:3000 \
  -e PUID=99 -e PGID=100 -e OPENCHAMBER_UI_PASSWORD=smoke \
  "$IMG" >/dev/null

cleanup() {
  docker logs "$NAME" > smoke.log 2>&1 || true
  docker rm -f "$NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

fail() { echo "SMOKE TEST FAILED: $*"; docker logs "$NAME" 2>&1 | tail -n 80; exit 1; }

# 1. Bundled OpenCode is the version we asked for
ACTUAL=$(docker exec "$NAME" opencode --version 2>/dev/null | tr -d '[:space:]' || true)
[[ "$ACTUAL" == *"$EXPECTED_OPENCODE"* ]] || fail "opencode --version is '$ACTUAL', expected $EXPECTED_OPENCODE"
echo "ok: opencode $ACTUAL"

# 2. OpenChamber web server answers
for i in $(seq 1 60); do
  curl -fs http://localhost:3000/health >/dev/null && break
  [ "$i" = 60 ] && fail "/health did not answer within 120s"
  sleep 2
done
echo "ok: /health -> $(curl -fs http://localhost:3000/health)"

# 3. OpenChamber reports its managed OpenCode as ready
for i in $(seq 1 45); do
  HEALTH=$(curl -fs http://localhost:3000/health || true)
  echo "$HEALTH" | grep -q '"isOpenCodeReady":true' && break
  [ "$i" = 45 ] && fail "OpenCode not ready after 90s: $(echo "$HEALTH" | grep -o '"lastOpenCodeError":[^,]*')"
  sleep 2
done
echo "ok: isOpenCodeReady=true"

# 4. Let it settle, then confirm it is still ready and logs are clean
sleep 15
curl -fs http://localhost:3000/health | grep -q '"isOpenCodeReady":true' || fail "OpenCode went away after startup"
PATTERNS='Failed to start OpenCode|requires OpenCode|Continuing without OpenCode|Timed out waiting for OpenCode|: not found'
if docker logs "$NAME" 2>&1 | grep -Eiq "$PATTERNS"; then
  fail "error pattern found in logs: $(docker logs "$NAME" 2>&1 | grep -Ei "$PATTERNS" | head -n 3)"
fi
echo "ok: still ready, no error patterns in logs"

echo "SMOKE TEST PASSED"
