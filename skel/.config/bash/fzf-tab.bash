# fzf + completions com preview no TAB (tema inspirado em gh0stzk/dotfiles)
command -v fzf >/dev/null || return

# Atalhos padrao do fzf: Ctrl+R (historico), Ctrl+T (arquivos), Alt+C (cd)
if [[ ${BLE_VERSION-} ]]; then
    ble-import -d integration/fzf-key-bindings   # versao compativel com ble.sh
else
    eval "$(fzf --bash)"
fi

# Visual igual ao fzf-tab do gh0stzk: caixas Search / Results / Preview
export FZF_COMPLETION_OPTS="--style=full --pointer '>' --gutter ' ' \
  --color 'pointer:green:bold,bg+:-1:,fg+:green:bold,info:blue:bold,marker:yellow:bold,hl:gray:bold,hl+:gray:bold' \
  --input-label ' Search ' --color 'input-border:blue,input-label:blue:bold' \
  --list-label ' Results ' --color 'list-border:green,list-label:green:bold' \
  --preview-label ' Preview ' --color 'preview-border:magenta,preview-label:magenta:bold' \
  --preview 'fzf-tab-preview {1}' --preview-window 'right,50%' \
  --bind 'space:accept'"
export FZF_TMUX_HEIGHT="90%"
export FZF_TAB_COMPLETION_PROMPT="> "

# TAB abre o fzf com as completions do bash
source "$HOME/.local/share/fzf-tab-completion/bash/fzf-bash-completion.sh"
bind -x '"\t": fzf_bash_completion'
