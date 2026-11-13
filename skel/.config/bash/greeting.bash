# Saudacao ao abrir o terminal: sorteia uma figura a cada login
#   blackhole -> buraco negro TON 618 · pilares -> Pilares da Criacao (M16) · andromeda -> M31
# (nao aparece dentro do nvim)
[[ -n ${NVIM-} ]] && return

# --- figura animada: as estrelas piscam so ate o 1o comando, depois a figura congela ---
# (um comando rolando a tela tiraria a figura do lugar e as estrelas sairiam por cima do texto)
_figura_start() {
    [[ -n ${_FIG_DIR-} ]] || return
    _figura_stop
    local tty; tty=$(tty) || return
    python3 ~/.config/bash/figura_anim.py "$$" "$tty" "$_FIG_DIR" 2 </dev/null >/dev/null 2>&1 &
    _FIG_PID=$!
    disown "$_FIG_PID" 2>/dev/null
}
# para o animador ANTES do comando escrever na tela e devolve a rolagem para a tela inteira
_figura_stop() {
    [[ -n ${_FIG_PID-} ]] || return 0
    kill "$_FIG_PID" 2>/dev/null
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$_FIG_PID" 2>/dev/null || break; sleep 0.02; done
    _FIG_PID=
    printf '\e7\e[r\e8'
}
if declare -F blehook >/dev/null; then
    blehook PREEXEC-=_figura_stop 2>/dev/null
    blehook PREEXEC+=_figura_stop
    # Ctrl+L e atalho (nao comando): o PREEXEC nao dispara, entao para o animador aqui tambem
    function ble/widget/figura-clear-screen { _figura_stop; ble/widget/clear-screen; }
    blehook/eval-after-load keymap_emacs 'ble-bind -m emacs -f C-l figura-clear-screen'
    blehook/eval-after-load keymap_vi 'ble-bind -m vi_imap -f C-l figura-clear-screen; ble-bind -m vi_nmap -f C-l figura-clear-screen'
fi
figura() {
    case $1 in
        off) _figura_stop ;;
        on)  if [[ -n ${_FIG_DIR-} ]]; then printf '\e[H\e[2J'; printf '\e[%d;1H' "$_FIG_RES"; _figura_start
             else echo "so a nebulosa e animada (abra um terminal novo ate ela sair)"; fi ;;
        *)   echo "uso: figura on|off  (pisca ate o proximo comando)" ;;
    esac
}
# figura com a tabela de logs (triagem-logs) à direita, centralizada na vertical; usa o array "tab" do chamador
# Padrão das figuras: FIG_ALT linhas x FIG_LARG colunas (56 de imagem + 2 de recuo).
# Figura maior é cortada, menor é completada com espaços: a tabela ao lado nunca desalinha.
FIG_ALT=16 FIG_LARG=58
_fig_com_tabela() {
    local -a fl; mapfile -t -n "$FIG_ALT" fl < "$1"
    local t=${#tab[@]} i j right linha
    local off=$(( (FIG_ALT - t) / 2 )); (( off < 0 )) && off=0
    for (( i = 0; i < FIG_ALT; i++ )); do
        linha=${fl[i]-}
        [[ -z $linha ]] && printf -v linha '%*s' "$FIG_LARG" ''
        j=$((i - off)) right=
        (( j >= 0 && j < t )) && right="      ${tab[j]}"
        printf '%s\e[0m%s\n' "$linha" "$right"
    done
}
_blackhole_greeting() {
    _figura_stop; unset _FIG_DIR _FIG_RES
    # figuras: pasta|titulo|cor do titulo (R;G;B)|animada (1/0). Quadros pre-renderizados por <pasta>/render.py
    local figuras=(
        "blackhole|TON 618|255;190;60|0"
        "pilares|PILARES DA CRIAÇÃO|110;205;215|1"
        "andromeda|ANDRÔMEDA (M31)|170;185;255|1"
    )
    local fig=${figuras[RANDOM % ${#figuras[@]}]}
    local nome titulo cor anim
    IFS='|' read -r nome titulo cor anim <<< "$fig"
    local dir=~/.config/bash/$nome/frames
    local cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 120)}
    local frames=("$dir"/*.ansi)
    local lines=${LINES:-$(tput lines 2>/dev/null || echo 40)}
    # blocos opcionais: só aparecem se o Dozzle/Grafana foram informados no distro-setup
    local DOZZLE_URL= GRAFANA_URL=
    [[ -r ~/.config/distro/config.env ]] && source ~/.config/distro/config.env
    # tabela "Logs para atacar agora" (gerada pelo triagem-logs): ao lado da figura se couber, senão embaixo
    local -a tab=(); local tabela=~/.local/state/triagem-logs/painel.ansi tab_baixo=
    [[ -n $DOZZLE_URL && -s $tabela ]] && mapfile -t tab < "$tabela"
    if (( ${#tab[@]} && cols < 138 )); then tab_baixo=1; local -a tab_salva=("${tab[@]}"); tab=(); fi
    if [[ -r ${frames[0]} ]] && (( cols >= 58 )); then
        local n=$FIG_ALT  # padrão fixo (ver _fig_com_tabela)
        if [[ -t 1 ]] && [[ ${FIGURA_ANIM-1} == 1 ]] && (( anim )) && (( cols >= 60 && lines >= n + 10 )); then
            # figura fixa no topo (linhas 2..n+1), estrelas piscando em segundo plano por figura_anim.py
            printf '\e[H\e[2J\n'; _fig_com_tabela "${frames[0]}"
            _FIG_DIR=$dir _FIG_RES=$((n + 2))
            _figura_start
        else
            printf '\n'; _fig_com_tabela "${frames[-1]}"
        fi
    else
        printf '\n  \e[38;2;255;190;60m—(●)—\e[0m\n'
    fi

    local dias=(domingo segunda-feira terça-feira quarta-feira quinta-feira sexta-feira sábado)
    local meses=(janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro)
    local dw d m hm
    read -r dw d m hm < <(date '+%w %-d %-m %H:%M')
    printf '\n  \e[1;38;2;%sm%s\e[0m\e[38;5;245m  ·  %s, %s de %s · %s\e[0m\n\n' \
        "$cor" "$titulo" "${dias[dw]}" "$d" "${meses[m-1]}" "$hm"

    if [[ -n $tab_baixo ]] && (( cols >= 64 )); then
        printf '  %s\n' "${tab_salva[@]}"; printf '\n'
    fi

    # painel de atividades (pré-gerado pelo hook do Claude: custo zero na abertura)
    # + tabela de endpoints lentos (triagem-logs) à direita, na mesma coluna da tabela de logs
    local painel=~/.claude/hooks/state/painel.ansi lentos=~/.local/state/triagem-logs/lentos.ansi
    local -a pl=() ll=()
    [[ -s $painel ]] && (( cols >= 64 )) && mapfile -t pl < "$painel"
    [[ -n $GRAFANA_URL && -s $lentos ]] && (( cols >= 64 )) && mapfile -t ll < "$lentos"
    local col=$(( FIG_LARG + 6 ))   # a tabela de logs começa depois da figura + 6 espaços
    if (( ${#ll[@]} && ${#pl[@]} && cols >= col + 62 )); then
        local i n=$(( ${#pl[@]} > ${#ll[@]} ? ${#pl[@]} : ${#ll[@]} )) l plain
        local _ext; _ext=$(shopt -p extglob); shopt -s extglob
        for (( i = 0; i < n; i++ )); do
            l=${pl[i]-}
            plain=${l//$'\e'\[*([0-9;])m/}
            printf '%s\e[0m%*s%s\n' "$l" $(( col - ${#plain} > 1 ? col - ${#plain} : 1 )) '' "${ll[i]-}"
        done
        eval "$_ext"
        printf '\n'
    else
        (( ${#pl[@]} )) && printf '%s\n' "${pl[@]}" && printf '\n'
        (( ${#ll[@]} )) && printf '%s\n' "${ll[@]}" && printf '\n'
    fi
}
_blackhole_greeting
unset -f _blackhole_greeting _fig_com_tabela

# reexibe o painel atualizado a qualquer momento
painel() { python3 ~/.claude/hooks/obsidian-memory.py painel; }
