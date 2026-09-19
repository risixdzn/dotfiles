# ~/.config/fish/config.fish
#
# Environment, PATH and aliases live in conf.d/ (fish sources those first).
# This file only holds interactive shell setup.

set -g fish_greeting ""

if status is-interactive
    # Prompt
    type -q starship; and starship init fish | source

    # Smarter cd. The `cd` alias must come after this init: zoxide copies the
    # existing `cd` into __zoxide_cd_internal here, so aliasing earlier (from
    # conf.d) makes zoxide call the alias and recurse until the stack blows.
    if type -q zoxide
        zoxide init fish | source
        alias cd='z'
    end

    # Fuzzy finder key bindings (ctrl-t, ctrl-r, alt-c)
    type -q fzf; and fzf --fish | source

    # Node version manager, switches on cd
    type -q fnm; and fnm env --use-on-cd --shell fish | source
end

# Machine specific overrides, never committed
test -f $__fish_config_dir/local.fish; and source $__fish_config_dir/local.fish

# herdr-automatic-rename: live tab naming hook
for _f in $HOME/.config/herdr/plugins/github/herdr-automatic-rename-*/shell/hook.fish
    test -r "$_f"; and source "$_f"; and break
end
