#!/bin/sh
set -eu

. /usr/local/bin/dev-drop-privileges.sh

export DEV_CHOWN_PATHS="${DEV_CHOWN_PATHS:-/opt/venv /app/backend/data /home/appuser/.cache}"

dev_drop_privileges "$@"

cd /app/backend

# Compose passes unset LLM_* values as empty strings, which would hide apps/backend/.env.
# Drop those so pydantic-settings can read the file. A non-empty shell override is kept.
for var in \
  LLM_PROVIDER LLM_MODEL LLM_API_KEY LLM_API_BASE \
  LOG_LEVEL LOG_LLM \
  DATABASE_URL DATABASE_SCHEMA \
  CORS_ORIGINS REQUEST_TIMEOUT_SECONDS REASONING_EFFORT
do
  if printenv "$var" >/dev/null 2>&1; then
    value=$(printenv "$var" || true)
    if [ -z "$value" ]; then
      unset "$var"
    fi
  fi
done

# Listen on every interface so published ports reach the process.
# 127.0.0.1:3000 is the Next dev server sharing this network namespace.
export HOST=0.0.0.0
export PORT=8000
export RELOAD=true
if [ -z "${FRONTEND_BASE_URL:-}" ]; then
  export FRONTEND_BASE_URL=http://127.0.0.1:3000
fi
export UV_CACHE_DIR="${UV_CACHE_DIR:-/home/appuser/.cache/uv}"
export UV_LINK_MODE=copy
export UV_PROJECT_ENVIRONMENT=/opt/venv
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/ms-playwright}"

log_level=$(printenv LOG_LEVEL || true)
case "$log_level" in
  CRITICAL|ERROR|WARNING|INFO|DEBUG) ;;
  *) log_level=INFO ;;
esac
uvicorn_level=$(printf '%s' "$log_level" | tr '[:upper:]' '[:lower:]')

echo "Syncing Python dependencies..."
uv sync

exec uv run --no-sync uvicorn app.main:app \
  --host 0.0.0.0 \
  --port 8000 \
  --reload \
  --reload-dir /app/backend/app \
  --log-level "$uvicorn_level"
