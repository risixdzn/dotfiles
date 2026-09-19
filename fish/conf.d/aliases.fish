# Aliases

alias c='clear'
alias q='clear'

# bat ships as batcat on Debian/Ubuntu
if type -q batcat
    alias bat='batcat'
end
alias cat='bat'

if type -q eza
    alias ls='eza --color=always --long --no-filesize --icons=always --no-time --no-user --no-permissions'
    alias lt='eza --color=always --tree --level=2 --icons=always --git-ignore'
end

alias code='zed'
alias gac='git add . && git commit'

# NOTE: `alias cd=z` lives in config.fish, not here.
# zoxide copies the current `cd` into __zoxide_cd_internal when it initializes,
# so the alias has to be defined after that init or it recurses into itself.
