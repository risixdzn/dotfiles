#!/usr/bin/env bash
#
# Undoes what install.sh (and bootstrap.sh's shell change) did:
# removes the symlinks this repo created and restores whatever was there
# before, from ~/.dotfiles-backup/<timestamp>/.
#
# Does NOT uninstall any apt/curl-installed tools from bootstrap.sh -
# only unlinking configs and the login shell change are reverted.
#
#   ./revert.sh                    revert everything, using the latest backup
#   ./revert.sh --dry-run          print what would happen, change nothing
#   ./revert.sh --list             list available backup snapshots
#   ./revert.sh --backup 20260919-110016   use a specific snapshot
#   ./revert.sh --keep-shell       leave the login shell as it is
#   ./revert.sh fish git           revert only the named packages

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES/lib/links.sh"

BACKUPS_ROOT="$HOME/.dotfiles-backup"
SHELL_STATE="$BACKUPS_ROOT/previous-shell"
DRY_RUN=0
KEEP_SHELL=0
BACKUP_NAME=""

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '  %swould run:%s %s\n' "$dim" "$reset" "$*"
  else
    "$@"
  fi
}

list_backups() {
  if [[ ! -d $BACKUPS_ROOT ]]; then
    info "no backups found at ${BACKUPS_ROOT/#$HOME/\~}"
    return
  fi
  local found=0
  for d in "$BACKUPS_ROOT"/*/; do
    [[ -d $d ]] || continue
    found=1
    local name count
    name="$(basename "$d")"
    count="$(find "$d" -type f -o -type l 2>/dev/null | wc -l | tr -d ' ')"
    printf '  %s  (%s file%s)\n' "$name" "$count" "$([[ $count == 1 ]] || echo s)"
  done
  [[ $found -eq 0 ]] && info "no backup snapshots found at ${BACKUPS_ROOT/#$HOME/\~}"
}

latest_backup() {
  [[ -d $BACKUPS_ROOT ]] || return 1
  find "$BACKUPS_ROOT" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | sort | tail -1
}

# Revert one package:src:dest triple. Only touches dest if it is currently
# our symlink, so anything you relinked or edited by hand is left alone.
revert_one() {
  local src="$DOTFILES/$1" dest="$2" backup_dir="$3"
  local relpath="${dest#"$HOME"/}"
  local backup_path="$backup_dir/$relpath"

  if [[ ! -L $dest ]]; then
    if [[ -e $dest ]]; then
      warn "${dest/#$HOME/\~} is not a symlink, leaving it alone"
    else
      skip "${dest/#$HOME/\~} not present, nothing to revert"
    fi
    return
  fi

  if [[ "$(readlink -f "$dest")" != "$(readlink -f "$src")" ]]; then
    warn "${dest/#$HOME/\~} is a symlink to something else, leaving it alone"
    return
  fi

  run rm "$dest"

  if [[ -n $backup_dir && -e $backup_path ]]; then
    run mkdir -p "$(dirname "$dest")"
    run mv "$backup_path" "$dest"
    ok "${dest/#$HOME/\~} restored from backup"
  else
    ok "${dest/#$HOME/\~} removed (nothing to restore)"
  fi
}

revert_shell() {
  if [[ $KEEP_SHELL -eq 1 ]]; then
    return
  fi
  if [[ ! -f $SHELL_STATE ]]; then
    skip "no previous shell recorded, leaving login shell as is"
    return
  fi

  local prev_shell current_shell
  prev_shell="$(cat "$SHELL_STATE")"
  current_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"

  if [[ $current_shell == "$prev_shell" ]]; then
    ok "login shell is already $prev_shell"
    run rm -f "$SHELL_STATE"
    return
  fi

  if [[ ! -x $prev_shell ]]; then
    warn "recorded previous shell $prev_shell no longer exists, leaving login shell as is"
    return
  fi

  # See bootstrap.sh's set_login_shell for why sudo comes before plain chsh.
  if [[ $EUID -eq 0 ]]; then
    run chsh -s "$prev_shell" "$(id -un)"
  elif command -v sudo >/dev/null 2>&1; then
    run sudo chsh -s "$prev_shell" "$(id -un)"
  elif [[ -t 0 && -t 1 ]]; then
    info "  setting login shell back to $prev_shell, you may be asked for your account password"
    run chsh -s "$prev_shell"
  else
    warn "no sudo and no tty, can't revert login shell non-interactively"
    return
  fi

  ok "login shell reverted to $prev_shell"
  run rm -f "$SHELL_STATE"
}

usage() {
  sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
}

main() {
  local packages=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run|-n)  DRY_RUN=1; shift ;;
      --list)        list_backups; exit 0 ;;
      --backup)      BACKUP_NAME="${2:?--backup needs a snapshot name}"; shift 2 ;;
      --backup=*)    BACKUP_NAME="${1#*=}"; shift ;;
      --keep-shell)  KEEP_SHELL=1; shift ;;
      -h|--help)     usage; exit 0 ;;
      -*)            echo "unknown flag: $1" >&2; exit 1 ;;
      *)             packages+=("$1"); shift ;;
    esac
  done

  local backup_dir=""
  if [[ -n $BACKUP_NAME ]]; then
    backup_dir="$BACKUPS_ROOT/$BACKUP_NAME"
    if [[ ! -d $backup_dir ]]; then
      echo "no such backup: ${backup_dir/#$HOME/\~}" >&2
      echo "run './revert.sh --list' to see what's available" >&2
      exit 1
    fi
  else
    local latest
    latest="$(latest_backup || true)"
    if [[ -n $latest ]]; then
      backup_dir="$BACKUPS_ROOT/$latest"
    fi
  fi

  [[ $DRY_RUN -eq 1 ]] && info "${bold}dry run, nothing will be changed${reset}"

  if [[ -n $backup_dir ]]; then
    info "${bold}reverting using backup ${backup_dir/#$HOME/\~}${reset}"
  else
    info "${bold}no backup snapshot found, will only remove dotfiles-managed symlinks${reset}"
  fi

  for entry in "${LINKS[@]}"; do
    local pkg="${entry%%:*}" rest="${entry#*:}"
    local src="${rest%%:*}" dest="${rest#*:}"

    if [[ ${#packages[@]} -gt 0 ]]; then
      local wanted=0
      for p in "${packages[@]}"; do [[ $p == "$pkg" ]] && wanted=1; done
      [[ $wanted -eq 1 ]] || continue
    fi

    revert_one "$src" "$dest" "$backup_dir"
  done

  info ""
  info "${bold}login shell${reset}"
  revert_shell

  if [[ -n $backup_dir ]]; then
    info ""
    info "backup snapshot kept at ${backup_dir/#$HOME/\~}, remove it whenever you're sure"
  fi
}

main "$@"
