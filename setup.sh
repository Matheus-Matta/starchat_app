#!/usr/bin/env bash
set -euo pipefail

# Troca "osmo/" por "osmo/" em todos os arquivos versionados pelo git
git grep -l 'osmo/' | while read -r file; do
  sed -i 's#osmo/#osmo/#g' "$file"
done

git add .

# Cria um commit
git commit -m "chore: renomear osmo/ para osmo/"
