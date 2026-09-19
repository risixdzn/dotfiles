#!/usr/bin/env bash
#
# Shared between install.sh and revert.sh: what gets linked where, plus the
# small print helpers both scripts use. Not meant to be run directly.

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# package:source-in-repo:destination
LINKS=(
  "fish:fish/config.fish:$CONFIG_HOME/fish/config.fish"
  "fish:fish/conf.d:$CONFIG_HOME/fish/conf.d"
  "starship:starship/starship.toml:$CONFIG_HOME/starship.toml"
  "ghostty:ghostty/config:$CONFIG_HOME/ghostty/config"
  "herdr:herdr/config.toml:$CONFIG_HOME/herdr/config.toml"
  "btop:btop/btop.conf:$CONFIG_HOME/btop/btop.conf"
  "git:git/gitconfig:$HOME/.gitconfig"
  "git:git/gitmessage.txt:$HOME/.gitmessage.txt"
)

bold=$'\033[1m'; green=$'\033[32m'; yellow=$'\033[33m'; dim=$'\033[2m'; reset=$'\033[0m'

info() { printf '%s\n' "$*"; }
ok()   { printf '  %s✓%s %s\n' "$green" "$reset" "$*"; }
warn() { printf '  %s!%s %s\n' "$yellow" "$reset" "$*"; }
skip() { printf '  %s·%s %s%s%s\n' "$dim" "$reset" "$dim" "$*" "$reset"; }
