# PATH entries, most specific first.
# fish_add_path is idempotent, so re-sourcing this file is safe.

set -gx BUN_INSTALL $HOME/.bun
set -gx PNPM_HOME $HOME/.local/share/pnpm

fish_add_path -gP $HOME/.local/bin
fish_add_path -gP $HOME/.local/share/fnm
fish_add_path -gP $BUN_INSTALL/bin
fish_add_path -gP $HOME/.nub/bin
fish_add_path -gP $PNPM_HOME
