#!/usr/bin/env bash
set -euo pipefail

# Variáveis padrão
: "${RAILS_ENV:=production}"
: "${DB_MIGRATE_ON_BOOT:=true}"
: "${POSTGRES_HOST:=postgres}"
: "${POSTGRES_PORT:=5432}"
: "${REDIS_HOST:=redis}"
: "${REDIS_PORT:=6379}"
: "${REDIS_PASSWORD:=}"

echo "=> Boot entrypoint (RAILS_ENV=${RAILS_ENV})"

# Aguarda Postgres
echo "=> Waiting for Postgres at ${POSTGRES_HOST}:${POSTGRES_PORT} ..."
until /bin/bash -lc "pg_isready -h ${POSTGRES_HOST} -p ${POSTGRES_PORT}" >/dev/null 2>&1; do
  sleep 1
done
echo "=> Postgres is ready"

# Aguarda Redis
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

# Prepara DB (create + migrate)
if [ "${DB_MIGRATE_ON_BOOT}" = "true" ]; then
  echo "=> Running db:prepare"
  bundle exec rails db:prepare
fi

# Inicia o processo solicitado (Puma/Sidekiq/etc)
echo "=> Exec: $*"
exec "$@"
