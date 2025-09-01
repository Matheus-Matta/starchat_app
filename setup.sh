#!/usr/bin/env bash
set -euo pipefail

# Lista apenas arquivos *text* versionados que contêm "Captain::"
mapfile -t files < <(git grep -Il 'cosmos_::' || true)

if [ ${#files[@]} -eq 0 ]; then
  echo "Nenhuma ocorrência de 'cosmos_::' encontrada."
  exit 0
fi

# Detecta a flag correta de inplace do sed (GNU vs BSD/macOS)
if sed --version >/dev/null 2>&1; then
  SED_INPLACE=(-i)
else
  SED_INPLACE=(-i '')
fi

# Substitui Captain:: -> Cosmos:: em cada arquivo
for file in "${files[@]}"; do
  sed "${SED_INPLACE[@]}" 's#cosmos_::#cosmos_::#g' "$file"
done

# Comita as alterações
git add "${files[@]}"
git commit -m "chore: renomear namespace cosmos_:: para cosmos_"
