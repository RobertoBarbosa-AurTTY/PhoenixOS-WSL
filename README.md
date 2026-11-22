# PhoenixOS

Distro **Arch Linux para WSL2** pronta para desenvolvimento, com um terminal que mostra o que importa ao abrir.
O nome é uma homenagem ao **Phoenix A**, um dos maiores buracos negros conhecidos (o painel abre com o TON 618, os Pilares da Criação ou Andrômeda).

## O que vem

- **Terminal:** bash + oh-my-bash + ble.sh (sugestões enquanto digita), fzf no TAB, eza, zoxide, bat, starship
- **Painel ao abrir o terminal:** figura astronômica em ANSI truecolor, Pendentes/Concluídas (memória do agente no Obsidian) e, se você quiser, erros de produção (Dozzle) e endpoints lentos (Grafana)
- **Dev:** neovim (AstroNvim), git, lazygit, docker + compose, node/npm, deno, python, ripgrep, fd
- **Agentes de IA:** Claude Code e/ou opencode, cada pessoa entra com a própria conta
  - memória de sessões no Obsidian (`/registrar`, `/handoff`, `/retomar`, `/mapa`)
  - `triagem-logs`: lê os logs no Dozzle, agrupa os erros e o agente separa bug real de ruído
  - `deep-commit`: mensagem de commit escrita pela IA a partir do diff
- **Isolado do Windows:** não roda `.exe` e não herda o PATH do Windows (dá para ligar em `/etc/wsl.conf`)

## Instalar

Baixe o `phoenixos.wsl` em [Releases](../../releases) e, no PowerShell (WSL 2.4.4 ou mais novo):

```powershell
wsl --install --from-file phoenixos.wsl
```

1. **1º boot:** cria o seu usuário e a senha do sudo.
2. **1º terminal:** o assistente `distro-setup` pergunta:
   - nome/e-mail do git (e cria a chave SSH, se você quiser)
   - agente: Claude Code e/ou opencode (faz o login com a sua conta)
   - link do **Dozzle** (opcional): você marca os containers e diz onde está o código de cada um
   - link de um **dashboard público do Grafana** (opcional): você escolhe o painel de latência por endpoint

Sem Dozzle/Grafana, o painel mostra só a figura e Pendentes/Concluídas. Para refazer: `distro-setup`.

## Construir a imagem

O build parte da imagem **oficial** do Arch para WSL e usa só este repositório e os repositórios oficiais. Nada vem da máquina de quem constrói.

```powershell
wsl --install archlinux --name phoenixos-build --no-launch
wsl -d phoenixos-build -u root -- bash -c "pacman -Sy --noconfirm git && git clone --depth 1 https://github.com/RobertoBarbosa-AurTTY/PhoenixOS-WSL /opt/distro && bash /opt/distro/construir.sh"
wsl --terminate phoenixos-build
wsl --export phoenixos-build phoenixos.wsl
wsl --unregister phoenixos-build
```

## Estrutura

| Caminho | Papel |
|---|---|
| `construir.sh` | build da imagem (roda como root numa instalação nova chamada `*build*`) |
| `oobe.sh` | criação do usuário no 1º boot (`/etc/wsl-distribution.conf`) |
| `bin/distro-setup` | assistente de configuração do usuário |
| `skel/` | home padrão de todo usuário novo (`/etc/skel`): bash, nvim, painel, Claude, Obsidian |
| `scripts/sincronizar-skel.sh` | para o mantenedor: copia os dotfiles atuais para `skel/` e bloqueia segredos |

Config de cada usuário: `~/.config/distro/config.env` (painel) e `~/.config/triagem-logs/config.json` (Dozzle, Grafana, agente).

## Licença

[MIT](LICENSE). A imagem também inclui software de terceiros com licença própria, baixado durante o build: [oh-my-bash](https://github.com/ohmybash/oh-my-bash) (MIT), [ble.sh](https://github.com/akinomyoga/ble.sh) (BSD-3-Clause), [fzf-tab-completion](https://github.com/lincheney/fzf-tab-completion) (GPL-3.0) e os pacotes do Arch Linux.
