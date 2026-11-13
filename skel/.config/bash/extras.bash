# ---------- Historico ----------
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth:erasedups      # sem duplicados nem comandos iniciados com espaco
HISTIGNORE="ls:ll:la:cd:pwd:exit:clear:history"
HISTTIMEFORMAT="%d/%m/%Y %H:%M  "
shopt -s histappend cmdhist
# Salva cada comando na hora (compartilha entre abas abertas)
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# ---------- eza (ls com icones) ----------
if command -v eza >/dev/null; then
    alias ls='eza --icons=always --color=always --group-directories-first'
    alias la='eza --icons=always --color=always --group-directories-first -a'
    alias ll='eza --icons=always --color=always --group-directories-first -lah --git'
    alias lt='eza --icons=always --color=always --tree --level=2 --git-ignore'
fi

# ---------- zoxide (cd inteligente) ----------
# z <parte do nome>  -> pula para a pasta mais usada
# zi                 -> escolhe a pasta no fzf
if command -v zoxide >/dev/null; then
    export _ZO_FZF_OPTS="--style=full --height=90% --pointer '>' --gutter ' ' \
      --color 'pointer:green:bold,bg+:-1:,fg+:green:bold,info:blue:bold,hl:gray:bold,hl+:gray:bold' \
      --input-label ' Search ' --color 'input-border:blue,input-label:blue:bold' \
      --list-label ' Pastas ' --color 'list-border:green,list-label:green:bold' \
      --preview-label ' Preview ' --color 'preview-border:magenta,preview-label:magenta:bold' \
      --preview 'eza -1 --icons=always --color=always -a {2..}' --preview-window 'right,50%'"
    eval "$(zoxide init bash)"
fi

# ---------- ble.sh: estilo da sugestao automatica ----------
# so texto cinza, sem o bloco branco de fundo
if [[ ${BLE_VERSION-} ]]; then
    ble-face -s auto_complete fg=244
fi

# ---------- prompt powerline: letras brancas em negrito (o tema usa a cor padrao, fraca) ----------
# so age se o tema carregado for o powerline do oh-my-bash; desfazer: apagar este bloco
if [[ ${OSH_THEME-} == powerline ]] && declare -F __powerline_left_segment >/dev/null; then
    __powerline_left_segment() {
        local OLD_IFS="${IFS}"; IFS="|"
        local params=( $1 )
        IFS="${OLD_IFS}"
        local separator=""
        if [[ "${SEGMENTS_AT_LEFT}" -gt 0 ]]; then
            separator="$(set_color ${LAST_SEGMENT_COLOR} ${params[1]})${POWERLINE_LEFT_SEPARATOR}${_omb_prompt_normal}"
        fi
        LEFT_PROMPT+="${separator}$(set_color $([[ ${params[2]:--} == - ]] && echo 231 || echo "${params[2]}") ${params[1]})\[\e[1m\] ${params[0]} ${_omb_prompt_normal}"
        LAST_SEGMENT_COLOR=${params[1]}
        (( SEGMENTS_AT_LEFT += 1 ))
    }
fi

# rr / recarregar: reinicia o terminal limpo (substitui "source ~/.bashrc").
# O source repete hooks/PATH a cada uso e deixa a tela anterior; aqui a tela e o scrollback são apagados
# e o shell é trocado por um bash novo (exec), no mesmo diretório e com o histórico salvo.
rr() {
    if [[ $1 != -f ]] && [[ -n $(jobs -p) ]]; then
        echo "há processos em segundo plano (jobs) que seriam encerrados; use: rr -f" >&2
        return 1
    fi
    declare -F _figura_stop >/dev/null && _figura_stop   # para a animação da figura
    history -a                                            # grava o histórico desta sessão
    printf '\e[r\e[0m\e[H\e[2J\e[3J'                      # rolagem normal, apaga tela e scrollback
    exec bash
}
alias recarregar=rr

# dotfiles: repositório bare em ~/.dotfiles (ver ~/.config/dotfiles/README.md)
dot() { git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" "$@"; }
# commit dos dotfiles com o deep-commit (mesmos argumentos: arquivos, -n, -m "dica"…)
dotcommit() { GIT_DIR="$HOME/.dotfiles" GIT_WORK_TREE="$HOME" deep-commit "$@"; }
