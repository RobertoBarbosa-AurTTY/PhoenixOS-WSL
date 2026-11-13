# Estado do Ambiente

> Injetado no início de cada sessão do Claude. O Claude atualiza esta nota quando algo no ambiente muda.

- **Sistema:** Arch Linux no WSL2, systemd ativo. Gerenciador: **pacman**/AUR.
- **sudo pede senha:** o Claude não consegue rodar sudo. Passe os comandos para o usuário executar com `! sudo …`.
- **Isolamento:** interop com o Windows desligado (não roda .exe), sem PATH do Windows. `/mnt/c` continua montado.
- **Shell:** bash + oh-my-bash (tema powerline) + ble.sh. Editor: nvim.
- **Instalado:** git, docker, node/npm, deno, python3, nvim, lazygit, rg, fzf, bat, eza, zoxide, opencode.
- **Painel do terminal:** configurado pelo `distro-setup` (`~/.config/distro/config.env`).
- **Repositórios:** (preencher)
