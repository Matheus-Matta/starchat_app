#!/usr/bin/env bash
set -euo pipefail

echo "=> Boot entrypoint (RAILS_ENV=${RAILS_ENV})"

if [ -n "${REDIS_PASSWORD}" ]; then
  echo "=> Waiting for Redis at ${REDIS_HOST}:${REDIS_PORT} (auth) ..."
  until redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" PING | grep -q PONG; do
    sleep 1
  done
else
  echo "=> Waiting for Redis at ${REDIS_HOST}:${REDIS_PORT} ..."
  until redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" PING | grep -q PONG; do
    sleep 1
  done
fi
echo "=> Redis is ready"

echo "=> Exec: $*"
exec "$@"
