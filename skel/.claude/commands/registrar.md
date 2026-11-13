---
description: Registra no grafo do Obsidian o que foi resolvido/decidido nesta sessão
argument-hint: "[assunto opcional]"
---
Registre no grafo de conhecimento. Assunto: $ARGUMENTS
(Se vazio, identifique você mesmo o que foi resolvido, decidido, cancelado ou descoberto nesta sessão e ainda não está registrado.)

# Procedimento de registro
Este arquivo é a referência completa; o `CLAUDE.md` aponta para cá.

1. **Busque antes de criar:** `rg -il "<termo ou erro>" ~/Obsidian\ Vault/Claude/Problemas`. Se existir, atualize a nota; só crie uma nova se não existir.
2. **Nome:** `Problemas/<Tema> - <Título curto>.md`.
3. **`erros:`** com o texto **exato** das mensagens de erro (é a principal chave de busca). **`palavras:`** com sinônimos e termos que alguém usaria para procurar.
4. **Relações tipadas** no frontmatter, só com notas que existem. Na seção `## Relacionados`, explique o porquê em uma linha e **adicione o link de volta** na outra nota.
5. **`## Sessões`:** linke só as sessões em que o problema foi trabalhado de verdade. A nota da sessão atual tem `(<id curto>)` no nome; o id é informado no início da sessão.
6. **Status:** `resolvido` · `em-aberto` · `adiado` · `descartado` (cancelado) · `decidido` · `documentado`. O painel do terminal mostra em-aberto (verde) e adiado (amarelo) como pendentes; resolvido, decidido e descartado aparecem como concluídas recentes.
7. **Atualize o handoff da sessão atual na hora:** edite só o bloco entre `<!-- handoff:inicio -->` e `<!-- handoff:fim -->` da nota em `Sessoes/` (formato do `/handoff`, no máximo cerca de 15 linhas: some o item em Feito, tire-o de Pendências, ajuste Estado e Próximo passo) e mude `handoff: nao` para `handoff: sim`.
8. Se algo do ambiente mudou, atualize `Estado do Ambiente.md` e o `verificado_em`.
9. Termine com uma linha: `📝 registrado: <nota> · handoff atualizado`.

Não registre perguntas triviais nem segredos (senhas, tokens, chaves). Não edite `Mapa de Problemas.md`, nem a parte `<!-- auto:* -->` dos Temas, nem a conversa das notas de sessão: são gerados pelo hook.

# Modelo de nota
Listas sempre inline `[...]`. Omita chaves de relação vazias. `projeto` só quando a nota é específica de um diretório.
```markdown
---
tipo: problema | decisao | conhecimento | plano
status: resolvido | em-aberto | adiado | descartado | decidido | documentado
temas: ["WSL", "Arch Linux"]
erros: ["texto exato do erro"]
palavras: ["termo", "sinônimo"]
causado_por: ["[[Nota]]"]
depende_de: ["[[Nota]]"]
mesmo_sintoma: ["[[Nota]]"]
alternativa_a: ["[[Nota]]"]
substitui: ["[[Nota]]"]
relacionado: ["[[Nota]]"]
projeto: ~/clones/meu-projeto
data: AAAA-MM-DD
verificado_em: AAAA-MM-DD
---
# <Tema> - <Título>

**Sintoma/Contexto:** …
**Causa:** …
**Solução:** … (arquivos e comandos exatos)

## Como verificar
```bash
<comando que confirma que a solução continua valendo>
```

## Relacionados
- [[Outra nota]]: por que está relacionada

## Sessões
- [[<nota da sessão>]]
```
