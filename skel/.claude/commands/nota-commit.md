---
description: Salva no Obsidian a nota da atividade concluída, que o deep-commit usa para escrever o commit
argument-hint: "[resumo opcional]"
---
Salve a nota de commit da atividade concluída nesta sessão. Resumo do usuário: $ARGUMENTS

# Procedimento
1. Descubra o repositório (`git rev-parse --show-toplevel`) e os arquivos alterados da atividade (`git status --short`; use só os que fazem parte desta atividade, com caminhos relativos à raiz do repo).
2. Se já existir nota `status: pendente` para o mesmo repo e atividade em `~/Obsidian Vault/Claude/Commits/`, atualize-a em vez de criar outra.
3. Crie `~/Obsidian Vault/Claude/Commits/AAAA-MM-DD HHMM - <título curto>.md` no modelo abaixo.
4. Texto em português formal e impessoal, factual, sem emojis, sem citar IA/Claude. Escreva o **porquê** (o diff não mostra isso): causa, decisão tomada e alternativas descartadas se relevantes.
5. Termine com uma linha: `📎 nota de commit salva: <nome> · rode: deep-commit <arquivos>`.

Não coloque segredos (tokens, senhas, dados de clientes).

# Modelo
```markdown
---
tipo: nota-commit
status: pendente
repo: /caminho/absoluto/do/repo
arquivos: ["src/x.py", "src/y.py"]
tipo_commit: fix
escopo: orders
problema: "[[Nota do Problema]]"
data: AAAA-MM-DD
---
# <título curto da atividade>

**Contexto:** qual era o problema/necessidade, onde aparecia e qual o impacto.
**Causa:** (se for correção) a causa raiz identificada.
**Solução:** o que foi feito e por que essa abordagem.
**Observações:** validação feita, pontos de atenção, pendências, impacto em outros módulos.
```
`problema` só se houver nota em `Problemas/`; omita linhas vazias.
