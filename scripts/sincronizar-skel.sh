#!/bin/bash
# sincronizar-skel.sh — copia as suas configs atuais (dotfiles versionados) para skel/ do repositório.
# Rode depois de mudar algo no seu terminal que deva ir para a distro. Revise com `git diff` antes de commitar.
# Não copia: .gitconfig, config do triagem-logs (tem os seus links), README dos dotfiles.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
SKEL=$REPO/skel
cd "$HOME"

git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" ls-files | grep -vE \
    '^(\.gitconfig|\.config/triagem-logs/config\.json|\.config/dotfiles/|\.local/bin/deep:)' |
    while IFS= read -r f; do [[ -f $f ]] && install -D -m "$(stat -c %a "$f")" "$f" "$SKEL/$f"; done

# ajustes para qualquer usuário
sed -i "s|^export OSH=.*|export OSH=\"\$HOME/.oh-my-bash\"|" "$SKEL/.bashrc"
sed -i 's/, notebook corporativo//' "$SKEL/.claude/CLAUDE.md"
# exemplos que citavam projetos de clientes
sed -i 's/fix(orders): converte horário TEF da VTEX para fuso de Maceió/fix(orders): converte horário do pagamento para o fuso local/' "$SKEL/.local/bin/deep-commit"
sed -i 's/(hub_labs, rest) usam/usam/' "$SKEL/.config/nvim/lua/plugins/typescript.lua"
sed -i 's|^projeto: ~/clones/rest|projeto: ~/clones/meu-projeto|' "$SKEL/.claude/commands/registrar.md"

# trava: nada pessoal, de empresa ou segredo
if grep -rnIE "nvapi-[A-Za-z0-9_-]{20,}|sk-ant-|ghp_[A-Za-z0-9]{20,}|github_pat_|/home/$USER|${PADROES_PRIVADOS:-__nenhum__}" "$SKEL"; then
    echo "✗ conteúdo pessoal/segredo encontrado acima: corrija antes de commitar"; exit 1
fi
echo "✔ skel sincronizado ($(find "$SKEL" -type f | wc -l) arquivos). Revise: git -C $REPO status"
