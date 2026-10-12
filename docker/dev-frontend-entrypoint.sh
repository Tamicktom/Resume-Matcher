#!/bin/sh
set -eu

. /usr/local/bin/dev-drop-privileges.sh

export DEV_CHOWN_PATHS="${DEV_CHOWN_PATHS:-/app/frontend/node_modules /app/frontend/.next /home/appuser/.npm}"

dev_drop_privileges "$@"

cd /app/frontend

export HOME=/home/appuser
export NEXT_TELEMETRY_DISABLED=1
export PORT="${PORT:-3000}"
export HOSTNAME=0.0.0.0

lock_hash=$(sha256sum package-lock.json)
lock_hash=${lock_hash%% *}
stamp="node_modules/.docker-lock-hash"
current=""
if [ -f "$stamp" ]; then
  current=$(cat "$stamp")
fi

if [ ! -x node_modules/.bin/next ] || [ "$current" != "$lock_hash" ]; then
  echo "Installing frontend dependencies..."
  npm ci
  echo "$lock_hash" > "$stamp"
else
  echo "Frontend dependencies are up to date."
fi

exec npm run dev -- --hostname 0.0.0.0 --port "$PORT"
