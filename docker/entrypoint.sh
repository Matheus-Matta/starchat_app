#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

if command -v dos2unix >/dev/null 2>&1; then
  find /app -maxdepth 2 -type f -name "*.sh" -exec dos2unix {} \; || true
fi

echo "=> Running db:chatwoot_prepare"
bundle exec rails db:chatwoot_prepare

if [ ! -d /app/public/assets ] && [ ! -d /app/public/packs ] && [ ! -d /app/public/vite ]; then
  echo "=> Precompiling assets"
  SECRET_KEY_BASE="${SECRET_KEY_BASE:-runtime_placeholder}" \
  RAILS_LOG_TO_STDOUT=enabled \
  bundle exec rake assets:precompile
fi

echo "=> Exec: $*"
exec "$@"
