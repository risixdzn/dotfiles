# Environment variables

set -gx EDITOR "zed --wait"
set -gx VISUAL $EDITOR

# Skip built-in updaters, packages are managed by bootstrap.sh / apt
set -gx DISABLE_AUTOUPDATER 1

# bat ships as batcat on Debian/Ubuntu
set -l pager (type -q batcat; and echo batcat; or echo bat)

# fzf: file widget (ctrl-t) with a bat preview
set -gx FZF_CTRL_T_OPTS "
    --style full
    --walker-skip .git,node_modules,target,dist,.next
    --preview '$pager -n --color always {}'
"
