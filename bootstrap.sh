#!/usr/bin/env bash
#
# Installs the tools these dotfiles expect. Safe to re-run.
# Debian/Ubuntu only, apt where possible.
#
#   ./bootstrap.sh

set -euo pipefail

bold=$'\033[1m'; green=$'\033[32m'; yellow=$'\033[33m'; dim=$'\033[2m'; reset=$'\033[0m'

info() { printf '%s\n' "$*"; }
ok()   { printf '  %s✓%s %s\n' "$green" "$reset" "$*"; }
warn() { printf '  %s!%s %s\n' "$yellow" "$reset" "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

APT_PACKAGES=(
  fish        # shell
  git
  curl
  bat         # installs as batcat
  eza         # ls replacement
  fzf         # fuzzy finder
  zoxide      # smarter cd
  ripgrep
  btop        # system monitor
  fontconfig
  unzip
  jq          # needed by the herdr-automatic-rename plugin
  build-essential  # provides cc, needed to build Rust herdr plugins from source
)

install_apt() {
  local missing=()
  for pkg in "${APT_PACKAGES[@]}"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    ok "apt packages already installed"
    return
  fi

  info "  installing: ${missing[*]}"
  sudo apt-get update
  sudo apt-get install -y "${missing[@]}"
  ok "apt packages installed"
}

install_starship() {
  if have starship; then
    ok "starship $(starship --version | head -1 | awk '{print $2}')"
    return
  fi
  # --bin-dir keeps this in ~/.local/bin, so the installer never needs sudo.
  # Its default (/usr/local/bin) escalates via a bare `sudo -v`, which some
  # sudoers setups (e.g. NOPASSWD:ALL alongside a password-required group
  # rule) refuse even though `sudo -n` works fine.
  mkdir -p "$HOME/.local/bin"
  curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
  ok "starship installed to ~/.local/bin"
}

install_fnm() {
  if have fnm || [[ -x $HOME/.local/share/fnm/fnm ]]; then
    ok "fnm already installed"
    return
  fi
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
  ok "fnm installed"
}

install_bun() {
  if have bun || [[ -x $HOME/.bun/bin/bun ]]; then
    ok "bun already installed"
    return
  fi
  curl -fsSL https://bun.sh/install | bash
  ok "bun installed"
}

install_roamgate() {
  if have roamgate; then
    ok "roamgate already installed"
    return
  fi
  curl -fsSL \
    https://github.com/powerfooI/roamgate/releases/latest/download/install-roamgate.sh |
    ROAMGATE_VERSION= sh
  ok "roamgate installed"
}

install_rust() {
  if have rustc && have cargo; then
    ok "rust $(rustc --version | awk '{print $2}')"
    return
  fi
  # --no-modify-path: PATH is managed centrally in fish/conf.d/path.fish,
  # not by rustup editing shell rc files.
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
    sh -s -- -y --no-modify-path --default-toolchain stable --profile minimal
  # So herdr plugin builds later in this run (e.g. herdr-sidebar on arches
  # without a prebuilt binary) can find cargo/rustc immediately.
  export PATH="$HOME/.cargo/bin:$PATH"
  ok "rust installed"
}

install_nerd_font() {
  local dir="$HOME/.local/share/fonts"
  if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
    ok "JetBrainsMono Nerd Font already installed"
    return
  fi
  mkdir -p "$dir"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/JetBrainsMono.zip" \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
  unzip -qo "$tmp/JetBrainsMono.zip" -d "$dir/JetBrainsMono"
  fc-cache -f >/dev/null
  rm -rf "$tmp"
  ok "JetBrainsMono Nerd Font installed"
}

install_herdr_automatic_rename() {
  if ! have herdr; then
    warn "herdr not installed, skipping herdr-automatic-rename (install herdr, then re-run bootstrap.sh)"
    return
  fi
  # Idempotent: safe to re-run, it no-ops if the plugin and hook are already there.
  # Not `set -e` fatal, same reasoning as install_herdr_plugin below.
  if curl -fsSL https://raw.githubusercontent.com/qu8n/herdr-automatic-rename/main/install.sh | bash -s -- fish; then
    ok "herdr-automatic-rename installed"
  else
    warn "herdr-automatic-rename failed to install, see the error above"
  fi
}

# $1: repo (owner/repo, optionally with a subpath to the plugin)
# $2: plugin_id as `herdr plugin list --json` reports it
install_herdr_plugin() {
  local repo="$1" plugin_id="$2"
  if ! have herdr; then
    warn "herdr not installed, skipping $plugin_id (install herdr, then re-run bootstrap.sh)"
    return
  fi
  if herdr plugin list --json 2>/dev/null |
    jq -e --arg id "$plugin_id" '.result.plugins[]|select(.plugin_id==$id)' >/dev/null 2>&1; then
    ok "$plugin_id already installed"
    return
  fi
  # Not `set -e` fatal: a plugin can fail to build on this arch (e.g. no
  # prebuilt binary + no Rust toolchain) without taking down the rest of
  # bootstrap.sh with it.
  if herdr plugin install "$repo" --yes; then
    ok "$plugin_id installed"
  else
    warn "$plugin_id failed to install, see the error above"
  fi
}

set_login_shell() {
  local fish_path current_shell
  fish_path="$(command -v fish || true)"
  if [[ -z $fish_path ]]; then
    warn "fish not on PATH, skipping login shell change"
    return
  fi

  current_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
  if [[ $current_shell == "$fish_path" ]]; then
    ok "fish is already the login shell"
    return
  fi

  # Remember what the shell was, so revert.sh can put it back.
  mkdir -p "$HOME/.dotfiles-backup"
  echo "$current_shell" >"$HOME/.dotfiles-backup/previous-shell"

  # chsh refuses a shell that isn't listed in /etc/shells
  if ! grep -qxF "$fish_path" /etc/shells 2>/dev/null; then
    info "  adding $fish_path to /etc/shells"
    if [[ $EUID -eq 0 ]]; then
      echo "$fish_path" >>/etc/shells
    elif have sudo; then
      echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
    else
      warn "no sudo and not root, can't register $fish_path in /etc/shells"
      return
    fi
  fi

  # Prefer sudo over plain chsh: chsh normally authenticates via the
  # invoking account's own password, which cloud-init users (e.g. "ubuntu")
  # usually don't have set at all (account is locked, SSH key + sudo only)
  # - that PAM check can never succeed. Routing through sudo instead runs
  # chsh as root, which skips that check entirely.
  if [[ $EUID -eq 0 ]]; then
    chsh -s "$fish_path" "$(id -un)"
  elif have sudo; then
    sudo chsh -s "$fish_path" "$(id -un)"
  elif [[ -t 0 && -t 1 ]]; then
    info "  setting login shell to fish, you may be asked for your account password"
    chsh -s "$fish_path"
  else
    warn "no sudo and no tty, can't run chsh non-interactively"
    return
  fi
  ok "login shell set to fish (takes effect on next login)"
}

main() {
  info "${bold}installing apt packages${reset}"
  install_apt

  info ""
  info "${bold}installing standalone tools${reset}"
  install_starship
  install_fnm
  install_bun
  install_roamgate
  install_nerd_font
  install_rust

  info ""
  info "${bold}setting login shell${reset}"
  set_login_shell

  info ""
  info "${bold}herdr plugins${reset}"
  install_herdr_automatic_rename
  install_herdr_plugin "hhdebb/herdr-radar" "herdr-radar"
  install_herdr_plugin "alexarthurs/herdr-sidebar/plugins/herdr-sidebar" "herdr-sidebar"

  info ""
  info "${bold}not handled here, install manually if you want them${reset}"
  have ghostty || info "  ${dim}ghostty    https://ghostty.org/download${reset}"
  have herdr   || info "  ${dim}herdr      https://github.com/herdrdev/herdr/releases${reset}"
  have zed     || info "  ${dim}zed        curl -f https://zed.dev/install.sh | sh${reset}"

  info ""
  info "next: ./install.sh"
}

main "$@"
