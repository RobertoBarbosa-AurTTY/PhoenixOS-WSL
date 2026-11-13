---
description: Resumo do grafo de problemas e das pendências
argument-hint: "[tema ou termo, opcional]"
---
Leia `~/Obsidian Vault/Claude/Mapa de Problemas.md`. Filtro: $ARGUMENTS

- Sem filtro: mostre os temas com contagem, as pendências e as 5 notas atualizadas mais recentemente (`ls -t ~/Obsidian\ Vault/Claude/Problemas | head -5`).
- Com filtro: busque com `rg -il "$ARGUMENTS" ~/Obsidian\ Vault/Claude/Problemas` e mostre cada nota encontrada (status + 1 linha de solução) e as relações entre elas.
Resposta curta, em tabela ou lista.
