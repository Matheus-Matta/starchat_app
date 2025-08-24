#!/usr/bin/env bash
set -euo pipefail

# Evita CRLF vindos do Windows
export LC_ALL=C

# Função: aguarda Postgres
wait_for_postgres() {
  local host="${POSTGRES_HOST:-postgres}"
  local port="${POSTGRES_PORT:-5432}"
  local user="${POSTGRES_USERNAME:-postgres}}"

  echo "=> Waiting for Postgres at ${host}:${port} as ${user} ..."
  until pg_isready -h "$host" -p "$port" -U "$user" >/dev/null 2>&1; do
    sleep 1
  done
  echo "=> Postgres is ready"
}

# Função: aguarda Redis
wait_for_redis() {
  local redis_url="${REDIS_URL:-redis://redis:6379/0}"
  echo "=> Waiting for Redis at ${redis_url} ..."
  # Tenta pingar com/sem senha
  if [[ "$redis_url" =~ ://([^:@]+)?(:([^@]+))?@([^:/]+):([0-9]+) ]]; then
    pass="${BASH_REMATCH[3]:-}"
    host="${BASH_REMATCH[4]}"
    port="${BASH_REMATCH[5]}"
    if [ -n "${pass}" ]; then
      until redis-cli -h "$host" -p "$port" -a "$pass" PING | grep -q PONG; do sleep 1; done
    else
      until redis-cli -h "$host" -p "$port" PING | grep -q PONG; do sleep 1; done
    fi
  else
    # fallback simples
    until redis-cli PING | grep -q PONG; do sleep 1; done
  fi
  echo "=> Redis is ready"
}

# Normaliza linhas caso você tenha editado em Windows
if command -v dos2unix >/dev/null 2>&1; then
  find /app -maxdepth 2 -type f -name "*.sh" -exec dos2unix {} \; || true
fi

# Espera serviços
wait_for_postgres
wait_for_redis

# Prepara DB (create + migrate)
echo "=> Running db:chatwoot_prepare"
bundle exec rails db:chatwoot_prepare

# Precompila assets se necessário
if [ ! -d /app/public/assets ] && [ ! -d /app/public/packs ]; then
  echo "=> Precompiling assets"
  SECRET_KEY_BASE="${SECRET_KEY_BASE:-runtime_placeholder}" \
  RAILS_LOG_TO_STDOUT=enabled \
  bundle exec rake assets:precompile
fi

echo "=> Exec: $*"
exec "$@"
