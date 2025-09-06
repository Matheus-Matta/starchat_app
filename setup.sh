#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# detecta sed GNU vs BSD/macOS para inplace
if sed --version >/dev/null 2>&1; then
  SED_INPLACE=(-i)
else
  SED_INPLACE=(-i '')
fi

echo "Atualizando conteúdo dos arquivos .rb no diretório atual…"

changed=0
for f in ./*; do
  [[ -f "$f" ]] || continue
  if grep -q 'Cosmos::' "$f"; then
    sed "${SED_INPLACE[@]}" 's#\bCaptain::#Cosmos::#g' "$f"
    echo "✔ Alterado: $f"
    ((changed++)) || true
  fi
done

if [[ $changed -eq 0 ]]; then
  echo "Nada a alterar."
fi
