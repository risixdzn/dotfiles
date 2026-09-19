#!/usr/bin/env bash
#
# Symlinks the configs in this repo into place.
# Existing files are moved into ~/.dotfiles-backup/<timestamp>/ first.
#
#   ./install.sh              link everything
#   ./install.sh --dry-run    print what would happen, change nothing
#   ./install.sh fish git     link only the named packages

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES/lib/links.sh"

BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0

REQUIRED_TOOLS=(fish starship zoxide fzf eza git)
OPTIONAL_TOOLS=(ghostty herdr btop batcat fnm bun)

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '  %swould run:%s %s\n' "$dim" "$reset" "$*"
  else
    "$@"
  fi
}

link() {
  local src="$DOTFILES/$1" dest="$2"

  if [[ ! -e $src ]]; then
    warn "missing in repo: $1"
    return
  fi

  if [[ -L $dest && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
    skip "${dest/#$HOME/\~} already linked"
    return
  fi

  if [[ -e $dest || -L $dest ]]; then
    run mkdir -p "$BACKUP_DIR/$(dirname "${dest#"$HOME"/}")"
    run mv "$dest" "$BACKUP_DIR/${dest#"$HOME"/}"
    warn "backed up ${dest/#$HOME/\~}"
  fi

  run mkdir -p "$(dirname "$dest")"
  run ln -s "$src" "$dest"
  ok "${dest/#$HOME/\~} -> ${1}"
}

check_tools() {
  local missing=()
  for tool in "${REQUIRED_TOOLS[@]}"; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    warn "missing required tools: ${missing[*]}"
    warn "run ./bootstrap.sh to install them"
  fi

  missing=()
  for tool in "${OPTIONAL_TOOLS[@]}"; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  [[ ${#missing[@]} -gt 0 ]] && skip "optional tools not found: ${missing[*]}"
  return 0
}

main() {
  local packages=()
  for arg in "$@"; do
    case "$arg" in
      --dry-run|-n) DRY_RUN=1 ;;
      -h|--help)    sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
      -*)           echo "unknown flag: $arg" >&2; exit 1 ;;
      *)            packages+=("$arg") ;;
    esac
  done

  [[ $DRY_RUN -eq 1 ]] && info "${bold}dry run, nothing will be changed${reset}"
  info "${bold}linking dotfiles from $DOTFILES${reset}"

  for entry in "${LINKS[@]}"; do
    local pkg="${entry%%:*}" rest="${entry#*:}"
    local src="${rest%%:*}" dest="${rest#*:}"

    if [[ ${#packages[@]} -gt 0 ]]; then
      local wanted=0
      for p in "${packages[@]}"; do [[ $p == "$pkg" ]] && wanted=1; done
      [[ $wanted -eq 1 ]] || continue
    fi

    link "$src" "$dest"
  done

  info ""
  check_tools

  if [[ -d $BACKUP_DIR ]]; then
    info ""
    info "replaced files are in ${BACKUP_DIR/#$HOME/\~}"
  fi

  if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v fish 2>/dev/null)" ]]; then
    info ""
    info "${dim}fish is not your login shell. To change it:${reset}"
    info "${dim}  chsh -s \"\$(command -v fish)\"${reset}"
  fi
}

main "$@"
