#!/usr/bin/env bash
set -euo pipefail

# Troca "aptain/" por "osmo/" em todos os arquivos versionados pelo git
git grep -l 'aptain/' | while read -r file; do
  sed -i 's#aptain/#osmo/#g' "$file"
done

git add .

# Cria um commit
git commit -m "chore: renomear aptain/ para osmo/"
