#!/bin/sh
set -e

# Append the UI password flag if one is configured
if [ -n "${OPENCHAMBER_UI_PASSWORD:-}" ]; then
  set -- "$@" --ui-password "$OPENCHAMBER_UI_PASSWORD"
fi

if [ "$(id -u)" = "0" ]; then
  # Map the agent user to PUID/PGID (Unraid: 99/100)
  groupmod -o -g "${PGID}" agent
  usermod  -o -u "${PUID}" agent >/dev/null

  if [ "${SKIP_FIX_PERMISSIONS:-false}" != "true" ]; then
    echo "Fixing ownership (set SKIP_FIX_PERMISSIONS=true to skip)"
    chown -R agent:agent /home/agent/.config /home/agent/.local
    chown agent:agent /home/agent /home/agent/workspaces
  fi

  # Run the check as agent: opencode writes its log on every invocation, and a
  # root-owned log file in /home/agent would break the server running as agent.
  echo "OpenChamber $(npm ls -g @openchamber/web --depth=0 2>/dev/null | grep -o '@openchamber/web@[^ ]*' || true), OpenCode $(gosu agent opencode --version 2>/dev/null || echo unknown)"
  exec gosu agent "$@"
fi

exec "$@"
