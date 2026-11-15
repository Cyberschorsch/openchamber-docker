#!/usr/bin/env bash
# Usage: smoke-test.sh <image> <expected-opencode-version>
set -euo pipefail

IMG="$1"
EXPECTED_OPENCODE="$2"
NAME="oc-smoke"
PORT="${SMOKE_PORT:-3000}"   # host port, override if 3000 is taken locally

docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" -p "$PORT:3000" \
  -e PUID=99 -e PGID=100 -e OPENCHAMBER_UI_PASSWORD=smoke \
  -e GH_TOKEN=smoke-gh -e GITLAB_TOKEN=smoke-gl \
  -e GIT_USER_NAME="Smoke Agent" -e GIT_USER_EMAIL=smoke@example.invalid \
  "$IMG" >/dev/null

cleanup() {
  docker logs "$NAME" > smoke.log 2>&1 || true
  docker rm -f "$NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

fail() { echo "SMOKE TEST FAILED: $*"; docker logs "$NAME" 2>&1 | tail -n 80; exit 1; }

# 1. Bundled OpenCode is the version we asked for (run as agent: opencode writes
#    its log on every invocation and root-owned files break the agent-owned server)
#    Retried: until the entrypoint has finished remapping the agent user and
#    fixing ownership, the call fails with a permission error.
for i in $(seq 1 15); do
  ACTUAL=$(docker exec -u agent "$NAME" opencode --version 2>/dev/null | tr -d '[:space:]' || true)
  [[ "$ACTUAL" == *"$EXPECTED_OPENCODE"* ]] && break
  sleep 2
done
[[ "$ACTUAL" == *"$EXPECTED_OPENCODE"* ]] || fail "opencode --version is '$ACTUAL', expected $EXPECTED_OPENCODE"
echo "ok: opencode $ACTUAL"

# 2. OpenChamber web server answers
for i in $(seq 1 60); do
  curl -fs http://localhost:$PORT/health >/dev/null && break
  [ "$i" = 60 ] && fail "/health did not answer within 120s"
  sleep 2
done
echo "ok: /health -> $(curl -fs http://localhost:$PORT/health)"

# 3. OpenChamber reports its managed OpenCode as ready
for i in $(seq 1 45); do
  HEALTH=$(curl -fs http://localhost:$PORT/health || true)
  echo "$HEALTH" | grep -q '"isOpenCodeReady":true' && break
  [ "$i" = 45 ] && fail "OpenCode not ready after 90s: $(echo "$HEALTH" | grep -o '"lastOpenCodeError":[^,]*')"
  sleep 2
done
echo "ok: isOpenCodeReady=true"

# 4. Let it settle, then confirm it is still ready and logs are clean
sleep 15
curl -fs http://localhost:$PORT/health | grep -q '"isOpenCodeReady":true' || fail "OpenCode went away after startup"
PATTERNS='Failed to start OpenCode|requires OpenCode|Continuing without OpenCode|Timed out waiting for OpenCode|: not found'
if docker logs "$NAME" 2>&1 | grep -Eiq "$PATTERNS"; then
  fail "error pattern found in logs: $(docker logs "$NAME" 2>&1 | grep -Ei "$PATTERNS" | head -n 3)"
fi
echo "ok: still ready, no error patterns in logs"

# 5. Git tooling: CLIs present, tokens reach git only for their own host, identity set
agent() { docker exec -i -u agent -e GIT_TERMINAL_PROMPT=0 "$NAME" "$@"; }
agent gh --version >/dev/null   || fail "gh is not runnable"
agent glab --version >/dev/null || fail "glab is not runnable"
cred() { printf 'protocol=https\nhost=%s\n\n' "$1" | agent git credential fill 2>/dev/null || true; }
cred github.com | grep -qx 'password=smoke-gh' || fail "git does not get GH_TOKEN for github.com"
cred gitlab.com | grep -qx 'password=smoke-gl' || fail "git does not get GITLAB_TOKEN for gitlab.com"
cred example.com | grep -q 'password=' && fail "a token is offered to a foreign host"
[ "$(agent git config user.name)" = "Smoke Agent" ] || fail "GIT_USER_NAME is not applied"
[ "$(agent git config user.email)" = "smoke@example.invalid" ] || fail "GIT_USER_EMAIL is not applied"
echo "ok: gh, glab, git credentials and identity"

echo "SMOKE TEST PASSED"
