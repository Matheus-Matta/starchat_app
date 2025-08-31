#!/usr/bin/env bash
set -euo pipefail

# Lista apenas arquivos *text* versionados que contêm "Cosmos::"
mapfile -t files < <(git grep -Il 'Cosmos' || true)

if [ ${#files[@]} -eq 0 ]; then
  echo "Nenhuma ocorrência de 'Cosmos' encontrada."
  exit 0
fi

# Detecta a flag correta de inplace do sed (GNU vs BSD/macOS)
if sed --version >/dev/null 2>&1; then
  SED_INPLACE=(-i)
else
  SED_INPLACE=(-i '')
fi

# Substitui Cosmos:: -> Cosmos:: em cada arquivo
for file in "${files[@]}"; do
  sed "${SED_INPLACE[@]}" 's#Cosmos#Cosmos#g' "$file"
done

# Comita as alterações
git add "${files[@]}"
git commit -m "chore: renomear namespace Cosmos para Cosmos"
