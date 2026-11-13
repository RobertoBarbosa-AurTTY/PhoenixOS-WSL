# Comunicação
- Sempre em **português**, direto: resultado primeiro, detalhes só se forem úteis.
- O usuário escreve rápido e informal, com erros de digitação: interprete a intenção e não peça para repetir.
- sudo pede senha e eu não consigo rodar: entregue comandos prontos para colar com `! sudo …`.
- Antes de mudar o sistema (wsl.conf, firewall, pacotes), diga o que muda e como desfazer.

# Ambiente
WSL2 + **Arch Linux** (pacman/AUR). Detalhes em `~/Obsidian Vault/Claude/Estado do Ambiente.md`, que é injetado no início da sessão. Se algo mudar, atualize essa nota.

# Memória
| Onde | O quê |
|---|---|
| este arquivo | regras de trabalho e comunicação |
| `~/Obsidian Vault/Claude/` | conhecimento: `Problemas/` (mantido por mim), `Sessoes/`, `Temas/` e `Mapa de Problemas.md` (gerados pelo hook), `Estado do Ambiente.md` |
| auto-memória | só preferências pessoais do usuário |
| `~/Obsidian Vault/Claude/Commits/` | notas de atividade concluída, lidas pelo `deep-commit` para escrever o corpo do commit |
Não duplique o mesmo fato em mais de um lugar.

- **Antes de investigar um problema**, busque no grafo: `rg -il "<erro exato ou palavra-chave>" ~/Obsidian\ Vault/Claude/Problemas`. Se o `verificado_em` for antigo, rode o bloco **Como verificar** da nota.
- **Sempre que um problema for resolvido, decidido, cancelado ou descoberto algo reaproveitável**, mesmo que seja o 2º ou 3º da sessão, registre na hora e atualize o handoff da sessão, sem esperar o usuário pedir. **Leia e siga `~/.claude/commands/registrar.md`**, que tem o procedimento e o modelo de nota.

# Sessões
- Uma sessão por assunto. Se o usuário mudar claramente de assunto e a sessão atual já tiver bastante trabalho, atualize o handoff e sugira em uma linha: "dica: `/clear` para começar este assunto numa sessão nova, já com a memória carregada".
- Comandos do usuário: `/registrar`, `/handoff`, `/retomar`, `/mapa`, `/nota-commit`.

# Commits
- **Ao concluir uma atividade que alterou código num repositório git**, salve a nota de commit seguindo `~/.claude/commands/nota-commit.md`, sem esperar o usuário pedir. O usuário commita depois com `deep-commit <arquivos>`. Eu não commito nem faço push.
