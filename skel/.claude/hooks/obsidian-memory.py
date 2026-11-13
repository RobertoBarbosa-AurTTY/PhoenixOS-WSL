#!/usr/bin/env python3
"""Memória de sessões + grafo de problemas do Claude Code no Obsidian.

Modos (stdin = JSON do hook):
  save      Stop          grava a nota da sessão, regera os índices, arquiva sessões antigas,
                          lembra o Claude de registrar o que foi resolvido
  handoff   SessionEnd    dispara em 2º plano a geração do handoff (Haiku)
  load      SessionStart  injeta ambiente + handoff + pendências como contexto
  indices   (manual)      regera "Mapa de Problemas" e as notas de Temas
  worker <transcript> <session_id> <cwd>   (interno) gera o handoff
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

# o processo filho (claude -p do handoff) nunca deve disparar a memória
if os.environ.get("OBSIDIAN_MEMORY_CHILD"):
    sys.exit(0)

VAULT = Path(os.environ.get("OBSIDIAN_VAULT", Path.home() / "Obsidian Vault"))
BASE = VAULT / "Claude"
SESSOES = BASE / "Sessoes"
ARQUIVO = SESSOES / "Arquivo"
PROBLEMAS = BASE / "Problemas"
TEMAS = BASE / "Temas"
MAPA = BASE / "Mapa de Problemas.md"
AMBIENTE = BASE / "Estado do Ambiente.md"
STATE = Path.home() / ".claude" / "hooks" / "state"
LOG = STATE / "obsidian-memory.log"
PAINEL = STATE / "painel.ansi"   # exibido pela saudação do terminal (~/.config/bash/greeting.bash)
PAINEL_MAX = 3                   # itens por lista no painel

DIAS_ARQUIVAR = 30          # sessões sem atividade há mais que isso vão para Sessoes/Arquivo
MAX_OUTRAS = 3              # sessões anteriores listadas no início
HANDOFF_MODELO = "haiku"
HANDOFF_MAX_CHARS = 80_000  # conversa enviada ao Haiku
LEMBRETE_MIN_EDITS, LEMBRETE_MIN_BASH = 2, 5

REL_TIPOS = ["causado_por", "depende_de", "mesmo_sintoma", "alternativa_a", "substitui", "relacionado"]
ABERTOS = {"em-aberto", "adiado"}
ORDEM_STATUS = {"em-aberto": 0, "adiado": 1, "resolvido": 2, "decidido": 3, "documentado": 4, "descartado": 5}
H_INI, H_FIM = "<!-- handoff:inicio -->", "<!-- handoff:fim -->"
A_INI, A_FIM = "<!-- auto:inicio -->", "<!-- auto:fim -->"
HANDOFF_VAZIO = "_(gerado automaticamente ao encerrar a sessão, ou use /handoff)_"
SINAL_RESOLVIDO = re.compile(
    r"(deu certo|funcionou|funciona agora|resolveu|resolvido|perfeito|valeu|obrigad|fechou|"
    r"agora (deu|foi|sim)|ficou (bom|top|show)|deixa (assim|como padr))", re.I)

PROMPT_HANDOFF = """Você gera HANDOFFS de sessões de trabalho entre um usuário e o assistente Claude Code.
Leia a conversa e escreva, em português, SOMENTE o bloco abaixo, em markdown, sem introdução e com no máximo ~15 linhas.
Seja específico: cite arquivos, comandos e valores. Não invente nada que não esteja na conversa.

**Objetivo:** <o que o usuário queria nesta sessão>
**Estado:** <onde parou; o que está funcionando agora>
**Feito:**
- <itens concluídos, com arquivos/comandos>
**Pendências:**
- <o que ficou em aberto, adiado ou sem resposta do usuário; "nenhuma" se não houver>
**Próximo passo sugerido:** <uma ação concreta>
**Cuidados:** <decisões tomadas, propostas que o usuário recusou, erros a não repetir; "nenhum" se não houver>"""


# ----------------------------------------------------------------- utilidades
def log(msg):
    try:
        STATE.mkdir(parents=True, exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(f"{datetime.now():%F %T} {msg}\n")
    except Exception:
        pass


def escrever(path, texto):
    """Escrita atômica; não toca no arquivo se o conteúdo não mudou."""
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text(encoding="utf-8") == texto:
        return
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(texto, encoding="utf-8")
    tmp.replace(path)


def corta(t, n):
    t = t.strip()
    return t if len(t) <= n else t[:n].rstrip() + " […]"


def lista(v):
    if isinstance(v, list):
        return v
    return [v] if v else []


def nome_link(x):
    return re.sub(r"^\[\[|\]\]$", "", x.strip()).split("|")[0].strip()


def parse_fm(texto):
    """Frontmatter YAML simples: `chave: valor` e `chave: [a, "b", ...]`."""
    if not texto.startswith("---"):
        return {}, texto
    fim = texto.find("\n---", 3)
    if fim < 0:
        return {}, texto
    bruto, corpo = texto[3:fim], texto[fim + 4:]
    fm = {}
    for linha in bruto.splitlines():
        m = re.match(r"^([\w-]+):\s*(.*)$", linha)
        if not m:
            continue
        k, v = m.group(1), m.group(2).strip()
        if v.startswith("[") and v.endswith("]"):
            itens = re.findall(r'\s*(?:"((?:[^"\\]|\\.)*)"|\'([^\']*)\'|([^,]+))\s*,?', v[1:-1])
            fm[k] = [next((x for x in t if x), "").strip() for t in itens]
            fm[k] = [x for x in fm[k] if x]
        else:
            fm[k] = v.strip("\"'")
    return fm, corpo


def mtime(p):
    try:
        return p.stat().st_mtime
    except OSError:
        return 0


# ----------------------------------------------------------------- transcript
def texto_de(content):
    if isinstance(content, str):
        return content.strip()
    return "\n".join(
        b.get("text", "") for b in content or [] if isinstance(b, dict) and b.get("type") == "text"
    ).strip()


def eh_prompt_real(content):
    if isinstance(content, list) and any(isinstance(b, dict) and b.get("type") == "tool_result" for b in content):
        return False
    t = texto_de(content)
    return bool(t) and not t.startswith(
        ("<command-", "<system-reminder", "<local-command", "Base directory for this skill", "# Update Config Skill"))


def ler_transcript(path):
    """-> (trocas [(prompt, resposta)], eventos [(idx, 'edit'|'bash'|'registro')])"""
    trocas, prompt, resp, eventos = [], None, [], []
    with open(path, encoding="utf-8") as f:
        for i, linha in enumerate(f, 1):
            try:
                e = json.loads(linha)
            except json.JSONDecodeError:
                continue
            if e.get("isSidechain") or e.get("isMeta"):
                continue
            cont = (e.get("message") or {}).get("content")
            if e.get("type") == "user" and eh_prompt_real(cont):
                if prompt is not None:
                    trocas.append((prompt, "\n\n".join(resp).strip()))
                prompt, resp = texto_de(cont), []
            elif e.get("type") == "assistant":
                t = texto_de(cont)
                if t and prompt is not None:
                    resp.append(t)
                for b in cont if isinstance(cont, list) else []:
                    if not (isinstance(b, dict) and b.get("type") == "tool_use"):
                        continue
                    alvo = json.dumps(b.get("input") or {}, ensure_ascii=False)
                    if "Problemas" in alvo:
                        eventos.append((i, "registro"))
                    elif b.get("name") in ("Edit", "Write", "NotebookEdit", "MultiEdit"):
                        eventos.append((i, "edit"))
                    elif b.get("name") == "Bash":
                        eventos.append((i, "bash"))
    if prompt is not None:
        trocas.append((prompt, "\n\n".join(resp).strip()))
    return trocas, eventos


def titulo_de(prompt):
    t = re.sub(r"\s+", " ", prompt).strip()
    t = re.sub(r'[\\/:*?"<>|#^\[\]()]', "", t)[:60].strip()
    return t or "sessao"


def achar_nota(sid):
    for d in (SESSOES, ARQUIVO):
        if d.exists():
            for p in d.glob(f"*({sid[:8]}).md"):
                return p
    return None


def achar_transcript(sid):
    for p in (Path.home() / ".claude" / "projects").glob(f"*/{sid}.jsonl"):
        return p
    return None


# ----------------------------------------------------------------- problemas / índices
def carregar_problemas():
    if not PROBLEMAS.exists():
        return []
    out = []
    for p in sorted(PROBLEMAS.glob("*.md")):
        fm, corpo = parse_fm(p.read_text(encoding="utf-8"))
        out.append((p.stem, fm, corpo))
    return out


def backlinks(stem):
    return [f"- [[{n}]] ({fm.get('status', '?')})" for n, fm, corpo in carregar_problemas()
            if f"[[{stem}]]" in corpo]


def gerar_indices():
    probs = carregar_problemas()
    if not probs:
        return
    probs.sort(key=lambda x: (ORDEM_STATUS.get(x[1].get("status", ""), 9), x[0].lower()))
    temas = {}
    for n, fm, _ in probs:
        for t in lista(fm.get("temas")):
            temas.setdefault(t, []).append((n, fm))

    L = ["---", "tipo: indice", "---", "", "# Mapa de Problemas", "",
         "> Gerado automaticamente a partir do frontmatter das notas em `Problemas/`. "
         "Edite as notas, não este arquivo. Abra o Graph view (Ctrl+G) para ver as relações.", "",
         "## Temas", " · ".join(f"[[{t}]] ({len(v)})" for t, v in sorted(temas.items())), "",
         "## Pendências"]
    abertos = [(n, fm) for n, fm, _ in probs if fm.get("status") in ABERTOS]
    L += [f"- [[{n}]] ({fm.get('status')})" for n, fm in abertos] or ["- (nenhuma)"]
    L += ["", "## Todas as notas", "", "| Nota | Tipo | Status | Temas | Verificado |", "|---|---|---|---|---|"]
    for n, fm, _ in probs:
        L.append(f"| [[{n}]] | {fm.get('tipo', '')} | {fm.get('status', '')} | "
                 f"{', '.join(lista(fm.get('temas')))} | {fm.get('verificado_em', '')} |")
    escrever(MAPA, "\n".join(L) + "\n")

    for t, itens in temas.items():
        arq = TEMAS / (re.sub(r'[\\/:*?<>|]', "", t) + ".md")
        cab = arq.read_text(encoding="utf-8").split(A_INI)[0].rstrip() if arq.exists() \
            else f"---\ntipo: tema\n---\n# {t}"
        auto = [A_INI, "## Notas (gerado automaticamente)"]
        for n, fm in itens:
            rels = [f"{k.replace('_', ' ')} {', '.join(f'[[{nome_link(x)}]]' for x in lista(fm.get(k)))}"
                    for k in REL_TIPOS[:-1] if lista(fm.get(k))]
            auto.append(f"- [[{n}]] ({fm.get('status', '?')})" + (f": {'; '.join(rels)}" if rels else ""))
        auto += ["", "Ver também: [[Mapa de Problemas]]", A_FIM]
        escrever(arq, cab + "\n\n" + "\n".join(auto) + "\n")


def gerar_painel():
    """Painel do terminal: próximo passo + até 3 pendentes + até 3 concluídas recentes."""
    A, C, G, V, R = ("\033[38;2;255;190;60m", "\033[38;5;245m", "\033[38;5;252m",
                     "\033[38;2;120;200;120m", "\033[0m")

    def curto(s, w):
        s = re.sub(r"\s+", " ", s.replace("`", "").replace("**", "")).strip()
        return s if len(s) <= w else s[:w - 1] + "…"

    probs = [(n, fm, mtime(PROBLEMAS / f"{n}.md")) for n, fm, _ in carregar_problemas()]
    pend = sorted((x for x in probs if x[1].get("status") in ABERTOS), key=lambda x: -x[2])
    conc = sorted((x for x in probs if x[1].get("status") in ("resolvido", "decidido", "descartado")),
                  key=lambda x: -x[2])
    COR_STATUS = {"em-aberto": "\033[38;2;120;200;120m", "adiado": "\033[38;2;240;210;80m"}  # verde / amarelo

    L = []
    if pend:
        L.append(f"  {A}◻ Pendentes ({len(pend)}){R}")
        L += [f"     {C}·{R} {G}{curto(n, 44):<44}{R} "
              f"{COR_STATUS.get(fm.get('status'), C)}{fm.get('status', '').replace('-', ' ')}{R}"
              for n, fm, _ in pend[:PAINEL_MAX]]
    if conc:
        L.append(f"  {V}✔ Concluídas recentes{R}")
        L += [f"     {C}·{R} {G}{curto(n, 44):<44}{R} {C}{datetime.fromtimestamp(t):%d/%m}"
              + (" · cancelado" if fm.get("status") == "descartado" else "") + R
              for n, fm, t in conc[:PAINEL_MAX]]
    escrever(PAINEL, "\n".join(L) + "\n" if L else "")


# ----------------------------------------------------------------- sessão
def gravar_sessao(hook):
    transcript, sid = hook.get("transcript_path"), hook.get("session_id", "")
    if not transcript or not os.path.exists(transcript) or not sid:
        return None, [], []
    trocas, eventos = ler_transcript(transcript)
    if not trocas:
        return None, trocas, eventos
    agora = datetime.now()
    nota = achar_nota(sid)
    handoff, inicio = None, agora.isoformat(timespec="minutes")
    if nota:
        txt = nota.read_text(encoding="utf-8")
        inicio = parse_fm(txt)[0].get("inicio", inicio)
        m = re.search(re.escape(H_INI) + r"\n(.*?)\n" + re.escape(H_FIM), txt, re.S)
        if m:
            handoff = m.group(1).strip()
    else:
        nota = SESSOES / f"{agora:%Y-%m-%d %H%M} - {titulo_de(trocas[0][0])} ({sid[:8]}).md"
    tem_handoff = bool(handoff) and handoff != HANDOFF_VAZIO

    L = ["---", f"session_id: {sid}", f"projeto: {hook.get('cwd', '')}", f"inicio: {inicio}",
         f"atualizado: {agora.isoformat(timespec='minutes')}", f"trocas: {len(trocas)}",
         f"handoff: {'sim' if tem_handoff else 'nao'}", "tags: [claude, sessao]", "---", "",
         f"# {titulo_de(trocas[0][0])}", "",
         f"Retomar a conversa completa: `claude --resume {sid}` · [[Mapa de Problemas]]", "",
         "## Handoff", H_INI, handoff if tem_handoff else HANDOFF_VAZIO, H_FIM, "",
         "## Problemas relacionados", *(backlinks(nota.stem) or ["- (nenhum)"]), "", "## Conversa", ""]
    for i, (p, r) in enumerate(trocas, 1):
        L += [f"### {i}. Prompt", "", p, "", "#### Resposta", "", r or "_(sem texto)_", ""]
    escrever(nota, "\n".join(L))
    return nota, trocas, eventos


def arquivar():
    if not SESSOES.exists():
        return
    limite = time.time() - DIAS_ARQUIVAR * 86400
    for p in SESSOES.glob("*.md"):
        if mtime(p) < limite:
            ARQUIVO.mkdir(parents=True, exist_ok=True)
            p.rename(ARQUIVO / p.name)


def lembrete(hook, trocas, eventos):
    """Bloqueia o Stop uma vez quando o usuário sinaliza que algo foi resolvido
    e houve trabalho relevante desde o último registro/lembrete."""
    if hook.get("stop_hook_active") or not trocas or not eventos:
        return None
    if not SINAL_RESOLVIDO.search(trocas[-1][0][:400]):
        return None
    sid = hook.get("session_id", "")
    st = STATE / f"lembrete-{sid[:8]}.json"
    ultimo = json.loads(st.read_text()).get("idx", 0) if st.exists() else 0
    corte = max([ultimo] + [i for i, k in eventos if k == "registro"])
    edits = sum(1 for i, k in eventos if i > corte and k == "edit")
    bashs = sum(1 for i, k in eventos if i > corte and k == "bash")
    if edits < LEMBRETE_MIN_EDITS and bashs < LEMBRETE_MIN_BASH:
        return None
    STATE.mkdir(parents=True, exist_ok=True)
    st.write_text(json.dumps({"idx": max(i for i, _ in eventos)}))
    return (f"[memória] O usuário sinalizou que algo foi resolvido e esta etapa teve trabalho relevante "
            f"({edits} edições, {bashs} comandos) sem registro no grafo. Registre agora em "
            f"~/Obsidian Vault/Claude/Problemas/ seguindo ~/.claude/commands/registrar.md (crie ou atualize a nota: "
            f"erros exatos, relações tipadas, Como verificar, link para a sessão atual, que tem '({sid[:8]})' "
            f"no nome). Em seguida ATUALIZE O HANDOFF dessa nota de sessão (bloco handoff:inicio/fim: "
            f"Feito, Pendências, Estado, Próximo passo; handoff: sim). Depois diga ao usuário, em UMA linha, "
            f"qual nota foi criada/atualizada. "
            f"Se não houver nada reaproveitável, responda apenas: (nada novo para o mapa)")


# ----------------------------------------------------------------- git do vault
def git_commit(msg):
    """Commit local de tudo que mudou no vault (sem remoto). Silencioso se não houver git/mudanças."""
    if not (VAULT / ".git").exists() or (VAULT / ".git" / "index.lock").exists():
        return
    g = ["git", "-C", str(VAULT)]
    try:
        subprocess.run(g + ["add", "-A"], capture_output=True, timeout=30)
        if subprocess.run(g + ["diff", "--cached", "--quiet"], timeout=30).returncode == 0:
            return
        r = subprocess.run(g + ["commit", "-q", "--no-verify", "-m", msg], capture_output=True, text=True, timeout=30)
        if r.returncode != 0:
            log(f"git commit falhou: {r.stderr[-300:]!r}")
    except Exception as e:
        log(f"git: {e!r}")


# ----------------------------------------------------------------- handoff
def spawn_worker(transcript, sid, cwd):
    STATE.mkdir(parents=True, exist_ok=True)
    lock = STATE / f"handoff-{sid[:8]}.lock"
    if lock.exists() and time.time() - mtime(lock) < 600:
        return
    lock.touch()
    with open(LOG, "a") as err:
        subprocess.Popen([sys.executable, os.path.abspath(__file__), "worker", str(transcript), sid, cwd or ""],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=err,
                         start_new_session=True, cwd=str(STATE))


def worker(transcript, sid, cwd=""):
    STATE.mkdir(parents=True, exist_ok=True)
    lock = STATE / f"handoff-{sid[:8]}.lock"
    try:
        nota, trocas, _ = gravar_sessao({"transcript_path": transcript, "session_id": sid, "cwd": cwd})
        if not nota or not trocas:
            return
        blocos = [f"USUÁRIO: {p}\nCLAUDE: {r}" for p, r in trocas]
        texto = "\n\n---\n\n".join(blocos)
        if len(texto) < 300:
            return
        if len(texto) > HANDOFF_MAX_CHARS:  # mantém o 1º pedido + o final da conversa
            texto = blocos[0][:5000] + "\n\n[…trecho do meio omitido…]\n\n" + texto[-(HANDOFF_MAX_CHARS - 6000):]
        claude = shutil.which("claude") or str(Path.home() / ".local/bin/claude")
        r = subprocess.run(
            [claude, "-p", "--model", HANDOFF_MODELO, "--no-session-persistence",
             "--settings", '{"disableAllHooks":true}'],
            input=f"{PROMPT_HANDOFF}\n\n<conversa>\n{texto}\n</conversa>",
            capture_output=True, text=True, timeout=240, cwd=str(STATE),
            env=dict(os.environ, OBSIDIAN_MEMORY_CHILD="1"))
        out = r.stdout.strip().replace(H_INI, "").replace(H_FIM, "")
        if r.returncode != 0 or not out:
            log(f"handoff falhou {sid[:8]} rc={r.returncode} {r.stderr[-300:]!r}")
            return
        txt = nota.read_text(encoding="utf-8")
        txt = re.sub(re.escape(H_INI) + r"\n.*?\n" + re.escape(H_FIM),
                     lambda _: f"{H_INI}\n{out}\n{H_FIM}", txt, count=1, flags=re.S)
        txt = txt.replace("\nhandoff: nao\n", "\nhandoff: sim\n", 1)
        escrever(nota, txt)
        log(f"handoff ok {sid[:8]}")
    finally:
        lock.unlink(missing_ok=True)
        try:
            gerar_painel()  # pega o "próximo passo" do handoff recém-gerado
        except Exception as e:
            log(f"painel: {e!r}")
        nota = achar_nota(sid)
        git_commit(f"sessão {sid[:8]}: {nota.stem if nota else 'sem nota'}")


# ----------------------------------------------------------------- modos
def save(hook):
    nota, trocas, eventos = gravar_sessao(hook)
    for f in (gerar_indices, arquivar, gerar_painel):
        try:
            f()
        except Exception as e:
            log(f"{f.__name__}: {e!r}")
    msg = lembrete(hook, trocas, eventos)
    if msg:
        print(json.dumps({"decision": "block", "reason": msg}, ensure_ascii=False))


def handoff(hook):
    t, sid = hook.get("transcript_path"), hook.get("session_id")
    if t and sid and os.path.exists(t):
        spawn_worker(t, sid, hook.get("cwd", ""))


def load(hook):
    if not BASE.exists():
        return
    sid = hook.get("session_id", "")
    cwd = hook.get("cwd") or os.getcwd()
    P = [f"# MEMÓRIA PERSISTENTE (Obsidian: {BASE})",
         f"Sessão atual: id curto `{sid[:8]}`; a nota dela aparecerá em Sessoes/ com '({sid[:8]})' no nome."]

    if AMBIENTE.exists():
        fm, corpo = parse_fm(AMBIENTE.read_text(encoding="utf-8"))
        corpo = re.sub(r"^# .*\n", "", corpo.split("## Como verificar")[0], flags=re.M)
        P += ["", f"## Estado do ambiente (verificado em {fm.get('verificado_em', '?')})", corta(corpo, 2000)]

    notas = sorted((p for p in SESSOES.glob("*.md") if sid[:8] not in p.name), key=mtime, reverse=True) \
        if SESSOES.exists() else []
    if notas:
        ultima = notas[0]
        txt = ultima.read_text(encoding="utf-8")
        fm, _ = parse_fm(txt)
        m = re.search(re.escape(H_INI) + r"\n(.*?)\n" + re.escape(H_FIM), txt, re.S)
        ho = m.group(1).strip() if m else ""
        if not ho or ho == HANDOFF_VAZIO:
            trechos = re.split(r"^### \d+\. Prompt\s*$", txt, flags=re.M)[1:][-3:]
            ho = "(handoff ainda não gerado; últimas trocas:)\n" + "\n".join(
                f"- USUÁRIO: {corta(b.partition('#### Resposta')[0], 300)}\n"
                f"  CLAUDE: {corta(b.partition('#### Resposta')[2], 500)}" for b in trechos)
            tp = achar_transcript(fm.get("session_id", ""))
            if tp:  # deixa pronto para a próxima vez
                spawn_worker(tp, fm["session_id"], fm.get("projeto", ""))
        P += ["", f"## Última sessão: {ultima.stem}",
              f"Diretório: {fm.get('projeto', '?')} · Atualizada: {fm.get('atualizado', '?')} · "
              f"Conversa completa: `claude --resume {fm.get('session_id', '?')}` · Nota: {ultima}", ho]
        mesmas = [p for p in notas[1:] if f"projeto: {cwd}\n" in p.read_text(encoding="utf-8")[:400]]
        outras = (mesmas + [p for p in notas[1:] if p not in mesmas])[:MAX_OUTRAS]
        if outras:
            P += ["", "## Outras sessões recentes", *[f"- {p.stem}" for p in outras]]

    probs = carregar_problemas()
    if probs:
        abertos = [f"- {n} ({fm.get('status')})" for n, fm, _ in probs if fm.get("status") in ABERTOS]
        P += ["", "## Pendências no grafo", *(abertos or ["- (nenhuma)"])]
        if cwd != str(Path.home()):
            locais = [n for n, fm, _ in probs if fm.get("projeto") and
                      (cwd.startswith(os.path.expanduser(fm["projeto"])) or
                       os.path.expanduser(fm["projeto"]).startswith(cwd))]
            if locais:
                P += ["", f"## Notas ligadas a {cwd}", *[f"- {n}" for n in locais]]
        temas = {}
        for _, fm, _ in probs:
            for t in lista(fm.get("temas")):
                temas[t] = temas.get(t, 0) + 1
        P += ["", f"## Grafo de problemas: {len(probs)} notas · temas: "
              + ", ".join(f"{t} ({c})" for t, c in sorted(temas.items())),
              f"Antes de investigar um problema, BUSQUE no grafo pelo texto exato do erro ou por palavras-chave "
              f"(campos `erros:` e `palavras:`): `rg -il \"<trecho>\" \"{PROBLEMAS}\"`. "
              f"Índice completo: \"{MAPA}\". Se `verificado_em` for antigo ou o ambiente parecer diferente, "
              f"rode o bloco 'Como verificar' da nota antes de confiar nela."]

    P += ["", "## Instrução de abertura",
          "Na sua PRIMEIRA resposta desta sessão, comece com 1–2 linhas dizendo onde a última sessão parou "
          "(use o handoff) e pergunte se o usuário quer retomar. Se a primeira mensagem já for claramente "
          "sobre outro assunto, só mencione isso em meia linha e siga com o pedido."]
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart",
                                             "additionalContext": "\n".join(P)}}, ensure_ascii=False))


if __name__ == "__main__":
    modo = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        if modo == "worker":
            worker(*sys.argv[2:5])
        elif modo == "indices":
            gerar_indices()
            gerar_painel()
        elif modo == "painel":
            gerar_painel()
            sys.stdout.write(PAINEL.read_text(encoding="utf-8"))
        else:
            try:
                hook = json.load(sys.stdin)
            except Exception:
                hook = {}
            {"save": save, "handoff": handoff, "load": load}.get(modo, lambda h: None)(hook)
    except Exception as e:
        log(f"erro em {modo}: {e!r}")
