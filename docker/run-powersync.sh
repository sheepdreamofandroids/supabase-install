#!/usr/bin/env bash
set -euo pipefail

. ./.env

# Wrapper that base64-encodes the PowerSync config and starts the Supabase stack
# with the PowerSync service enabled.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_PATH="${SCRIPT_DIR}/powersync/config.yaml"

if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo "PowerSync config not found at ${CONFIG_PATH}" >&2
  exit 1
fi

COMPOSE_CMD=${COMPOSE_CMD:-docker compose}

# Derive connection information for the Supabase Postgres instance.
POSTGRES_HOST=${POSTGRES_HOST:-db}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_DB=${POSTGRES_DB:-postgres}
POWERSYNC_DB_USER=${POWERSYNC_DB_USER:-postgres}

if [[ -n ${POWERSYNC_DB_PASSWORD:-} ]]; then
  DB_PASSWORD=${POWERSYNC_DB_PASSWORD}
elif [[ -n ${POSTGRES_PASSWORD:-} ]]; then
  DB_PASSWORD=${POSTGRES_PASSWORD}
else
  echo "error: set POWERSYNC_DB_PASSWORD or POSTGRES_PASSWORD so PowerSync can connect to Postgres" >&2
  exit 1
fi

REPLICATION_URI_DEFAULT="postgresql://${POWERSYNC_DB_USER}:${DB_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"

export PS_REPLICATION_URI=${PS_REPLICATION_URI:-${REPLICATION_URI_DEFAULT}}
export PS_STORAGE_URI=${PS_STORAGE_URI:-${REPLICATION_URI_DEFAULT}}

if [[ -n ${PS_SUPABASE_JWT_SECRET:-} ]]; then
  export PS_SUPABASE_JWT_SECRET
elif [[ -n ${JWT_SECRET:-} ]]; then
  export PS_SUPABASE_JWT_SECRET=${JWT_SECRET}
else
  echo "error: set PS_SUPABASE_JWT_SECRET or JWT_SECRET so PowerSync can validate Supabase tokens" >&2
  exit 1
fi

export POWERSYNC_PORT=${POWERSYNC_PORT:-8080}

if ! command -v base64 >/dev/null 2>&1; then
  echo "error: base64 command not found" >&2
  exit 1
fi

if base64 --help 2>&1 | grep -q -- "-w"; then
  POWERSYNC_CONFIG_B64=$(base64 -w0 "${CONFIG_PATH}")
else
  POWERSYNC_CONFIG_B64=$(base64 "${CONFIG_PATH}" | tr -d '\n')
fi
export POWERSYNC_CONFIG_B64

exec ${COMPOSE_CMD} \
  -f "${SCRIPT_DIR}/docker-compose.yml" \
  -f "${SCRIPT_DIR}/docker-compose.powersync.yml" \
  ${@:-up -d}
