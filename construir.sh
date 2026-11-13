#!/bin/bash
# construir.sh — monta a distro a partir da imagem OFICIAL do Arch Linux para WSL.
# Build reproduzível: nada vem da máquina de quem constrói, só deste repositório e dos repositórios oficiais.
#
# No PowerShell (WSL 2.4.4+):
#   wsl --install archlinux --name phoenixos-build --no-launch
#   wsl -d phoenixos-build -u root -- bash -c "pacman -Sy --noconfirm git && git clone --depth 1 <URL-deste-repo> /opt/distro && bash /opt/distro/construir.sh"
#   wsl --terminate phoenixos-build
#   wsl --export phoenixos-build phoenixos.wsl
#   wsl --unregister phoenixos-build
#
# Quem recebe: wsl --install --from-file phoenixos.wsl
set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
[[ $EUID -eq 0 ]] || { echo "rode como root (wsl -d phoenixos-build -u root …)"; exit 1; }
if [[ ${WSL_DISTRO_NAME:-} != *build* ]]; then
    echo "✗ distro atual: '${WSL_DISTRO_NAME:-?}'. Rode só numa instalação nova cujo nome contenha 'build'."; exit 1
fi
getent passwd 1000 >/dev/null && { echo "✗ já existe usuário com uid 1000: use uma instalação nova do Arch"; exit 1; }

echo "==> 1/6 chaves e pacotes"
pacman-key --init >/dev/null && pacman-key --populate archlinux >/dev/null
pacman -Syu --needed --noconfirm \
    base-devel sudo git openssh curl wget unzip man-db less which \
    python nodejs npm deno \
    neovim ripgrep fd fzf bat eza zoxide starship lazygit \
    docker docker-compose docker-buildx wl-clipboard obsidian
npm install -g --allow-scripts=opencode-ai opencode-ai >/dev/null
systemctl enable docker.service

echo "==> 2/6 shell: oh-my-bash, ble.sh e fzf-tab-completion (direto dos projetos)"
SKEL=/etc/skel
rm -rf "$SKEL/.oh-my-bash" "$SKEL/.local/share/blesh" "$SKEL/.local/share/fzf-tab-completion"
git clone -q --depth 1 https://github.com/ohmybash/oh-my-bash.git "$SKEL/.oh-my-bash"
git clone -q --depth 1 https://github.com/lincheney/fzf-tab-completion.git "$SKEL/.local/share/fzf-tab-completion"
tmp=$(mktemp -d)
curl -fsSL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz | tar -xJ -C "$tmp"
mv "$tmp"/ble-nightly "$SKEL/.local/share/blesh"; rm -rf "$tmp"
rm -rf "$SKEL"/.oh-my-bash/.git "$SKEL"/.local/share/fzf-tab-completion/.git

echo "==> 3/6 configurações do repositório → /etc/skel"
cp -a "$REPO/skel/." "$SKEL/"
chown -R root:root "$SKEL"

echo "==> 4/6 assistente e criação de usuário no 1º boot"
install -m 755 "$REPO/bin/distro-setup" /usr/local/bin/distro-setup
install -D -m 755 "$REPO/oobe.sh" /usr/local/lib/distro/oobe.sh
cat > /etc/wsl.conf <<'EOF'
[boot]
systemd=true

[interop]
# nao executa .exe do Windows e nao mistura o PATH do Windows (para ligar: enabled=true e wsl --shutdown)
enabled=false
appendWindowsPath=false
EOF
icon=$(sed -n "s/^icon *= *//p" /etc/wsl-distribution.conf 2>/dev/null || true)
cat > /etc/wsl-distribution.conf <<EOF
[oobe]
command = /usr/local/lib/distro/oobe.sh
defaultUid = 1000
defaultName = phoenixos

[shortcut]
icon = ${icon:-/usr/lib/wsl/archlinux.ico}
EOF
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel && chmod 440 /etc/sudoers.d/10-wheel
visudo -cf /etc/sudoers.d/10-wheel >/dev/null

echo "==> 5/6 limpeza"
pacman -Scc --noconfirm >/dev/null || true
rm -rf /etc/pacman.d/gnupg              # o oobe.sh gera de novo: cada instalação com as suas chaves
rm -rf /root/.npm /root/.cache /tmp/* /var/tmp/* 2>/dev/null || true
rm -f /root/.bash_history /etc/ssh/ssh_host_*
find /var/log -type f -exec truncate -s 0 {} + 2>/dev/null || true
: > /etc/machine-id
rm -rf /opt/distro

echo "==> 6/6 pronto. No PowerShell:"
echo "      wsl --terminate ${WSL_DISTRO_NAME}"
echo "      wsl --export ${WSL_DISTRO_NAME} phoenixos.wsl"
echo "      wsl --unregister ${WSL_DISTRO_NAME}"
