#!/usr/bin/env bash
set -euo pipefail

# Uso: ./rename_copilot_to_cosmos_i18n.sh [--dry-run]
DRY=${1:-}
if [[ "${DRY:-}" == "--dry-run" ]]; then DRY=1; else DRY=0; fi

TARGET_DIR="app/javascript/dashboard/i18n"

# 1) Confere se estamos num repo Git e se o diretório existe
git rev-parse --is-inside-work-tree >/dev/null
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Erro: diretório '$TARGET_DIR' não existe." >&2
  exit 1
fi

echo ">>> Base: $(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD)"
echo ">>> Alvo: $TARGET_DIR (*.json)"

# 2) Lista apenas arquivos .json RASTREADOS pelo Git dentro do diretório
mapfile -d '' FILES < <(git ls-files -z -- "$TARGET_DIR" | grep -z -E '\.json$' || true)

if ((${#FILES[@]}==0)); then
  echo ">>> Nenhum .json rastreado encontrado em $TARGET_DIR."
  exit 0
fi

if [[ "$DRY" -eq 1 ]]; then
  echo ">>> [dry-run] Ocorrências de 'copilot'/'Copilot' nos .json:"
  # Mostra linhas que serão afetadas
  printf '%s\0' "${FILES[@]}" \
  | xargs -0 -I{} bash -c "grep -nH -e 'copilot' -e 'Copilot' '{}' || true"
  echo ">>> [dry-run] Fim. Nada foi alterado."
  exit 0
fi

# 3) Substituições de conteúdo SOMENTE nesses .json
echo ">>> Substituindo conteúdo em arquivos .json..."
printf '%s\0' "${FILES[@]}" \
| xargs -0 sed -i \
  -e 's/copilot/cosmos/g' \
  -e 's/Copilot/Cosmos/g'
# Obs: 'COPILOT' permanece inalterado.

# 4) Adiciona e commita se houver mudanças
git add --update -- "$TARGET_DIR"
if git diff --cached --quiet; then
  echo ">>> Nenhuma alteração para commitar."
else
  git commit -m "i18n: renomeia copilot→cosmos e Copilot→Cosmos nos JSON de dashboard"
  echo ">>> Feito. Revise com: git show --stat"
fi

# === Opcional: limitar por palavra inteira (evita trocar partes de palavras)
# Substitua a linha do sed por:
#   -e 's/\bCopilot\b/Cosmos/g' \
#   -e 's/\bcopilot\b/cosmos/g'
# (requer GNU sed; no Ubuntu/WSL já é GNU sed)
