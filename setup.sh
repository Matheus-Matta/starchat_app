#!/usr/bin/env bash
set -euo pipefail

# Troca "osmos/" por "osmos/" em todos os arquivos versionados pelo git
git grep -l 'osmos/' | while read -r file; do
  sed -i 's#osmos/#osmos/#g' "$file"
done

git add .

# Cria um commit
git commit -m "chore: renomear osmos/ para osmos/"
