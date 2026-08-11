#!/bin/sh
set -eu
set -x

APP_PATH=/app

if [ -f "$APP_PATH/.env.prod" ]; then
  set -a
  . "$APP_PATH/.env.prod"
  set +a
fi

mkdir -p "$APP_PATH/tmp/pids" "$APP_PATH/tmp/cache" "$APP_PATH/log"
rm -f "$APP_PATH/tmp/pids/server.pid"
rm -rf "$APP_PATH/tmp/cache"/* || true

# garante que as gems já estão ok (em produção você NÃO deve rodar bundle install aqui)
bundle check

DB_HOST="${POSTGRES_HOST:-${POSTGRES_HOSTNAME:-${DB_HOST:-postgres}}}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_USER="${POSTGRES_USER:-postgres}"

until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" >/dev/null 2>&1; do
  echo "Waiting for Postgres at ${DB_HOST}:${DB_PORT}..."
  sleep 2
done

bundle exec rails db:starchats_prepare

exec "$@"
