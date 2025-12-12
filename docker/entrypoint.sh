#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

if command -v dos2unix >/dev/null 2>&1; then
  find /app -maxdepth 2 -type f -name "*.sh" -exec dos2unix {} \; || true
fi

bundle exec rails db:chatwoot_prepare

exec "$@"
