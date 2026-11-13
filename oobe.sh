#!/bin/bash
# OOBE: roda como root na PRIMEIRA vez que a distro é aberta (WSL lê /etc/wsl-distribution.conf).
# Cria o usuário da pessoa (uid 1000) a partir do /etc/skel, que já traz o terminal configurado.
# Se sair com erro, o WSL roda de novo na próxima abertura.
set -u

cat <<'EOF'

  Bem-vindo ao PhoenixOS! Distro Arch Linux (WSL) já configurada para desenvolvimento:
  terminal com painel, nvim, docker, deno, node, lazygit, fzf, ripgrep e agentes de IA.

  Primeiro passo: criar o seu usuário Linux. Depois, ao abrir o terminal, um assistente
  pergunta seu agente de IA (Claude Code / opencode) e os links do Dozzle/Grafana.
EOF

echo -e "\nPreparando as chaves do pacman..."
pacman-key --init &>/dev/null && pacman-key --populate archlinux &>/dev/null && echo "  ok"

while :; do
    read -r -p $'\nNome de usuário (minúsculas, sem espaço): ' u
    if [[ ! $u =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then echo "  inválido: use letras minúsculas, números, _ ou -"; continue; fi
    if id "$u" &>/dev/null; then echo "  já existe"; continue; fi
    break
done

grupos=wheel; getent group docker >/dev/null && grupos+=,docker
useradd -m -u 1000 -G "$grupos" -s /bin/bash "$u" || exit 1
echo "Defina a senha (usada no sudo):"
until passwd "$u"; do echo "  tente de novo"; done

# usuário padrão ao abrir a distro
if grep -q '^\[user\]' /etc/wsl.conf 2>/dev/null; then
    sed -i "/^\[user\]/,/^\[/ s/^default=.*/default=$u/" /etc/wsl.conf
else
    printf '\n[user]\ndefault=%s\n' "$u" >> /etc/wsl.conf
fi

echo -e "\nPronto, usuário $u criado. Abrindo o terminal…"
exit 0
