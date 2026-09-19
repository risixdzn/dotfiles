# dotfiles

Terminal setup for Ubuntu: fish, starship, ghostty, herdr, btop and git.

## Install

```sh
git clone <this-repo> ~/dev/projects/dotfiles
cd ~/dev/projects/dotfiles

./bootstrap.sh   # install the tools (apt + a few standalone installers)
./install.sh     # symlink the configs into place
```

`install.sh` moves anything already at a destination into
`~/.dotfiles-backup/<timestamp>/` before linking, so nothing is lost.

```sh
./install.sh --dry-run    # show what would change
./install.sh fish git     # link only some packages
```

## Reverting

If something's wrong, `revert.sh` undoes `install.sh` (removes the symlinks
and restores what was there before, from the backup) and, unless told
otherwise, also undoes the login shell change from `bootstrap.sh`.

```sh
./revert.sh              # revert everything, using the latest backup
./revert.sh --dry-run    # show what would change
./revert.sh --list       # list available backup snapshots
./revert.sh --backup 20260919-110016   # use a specific snapshot
./revert.sh --keep-shell # leave the login shell alone
./revert.sh fish git     # revert only some packages
```

It only touches a destination that is still exactly the symlink `install.sh`
created — anything you've since edited or relinked by hand is left alone and
reported, not overwritten. It does not uninstall anything `bootstrap.sh`
installed (fish, eza, starship, ...), only the linking and the shell change.

## What goes where

| Package    | Repo path              | Linked to                     |
| ---------- | ---------------------- | ----------------------------- |
| `fish`     | `fish/config.fish`     | `~/.config/fish/config.fish`  |
| `fish`     | `fish/conf.d/`         | `~/.config/fish/conf.d/`      |
| `starship` | `starship/starship.toml` | `~/.config/starship.toml`   |
| `ghostty`  | `ghostty/config`       | `~/.config/ghostty/config`    |
| `herdr`    | `herdr/config.toml`    | `~/.config/herdr/config.toml` |
| `btop`     | `btop/btop.conf`       | `~/.config/btop/btop.conf`    |
| `git`      | `git/gitconfig`        | `~/.gitconfig`                |
| `git`      | `git/gitmessage.txt`   | `~/.gitmessage.txt`           |

## Fish layout

Fish sources everything in `conf.d/` before `config.fish`, so the split is:

- `conf.d/path.fish` — PATH entries (`fish_add_path`, idempotent)
- `conf.d/env.fish` — environment variables, fzf options
- `conf.d/aliases.fish` — aliases, each guarded by `type -q`
- `config.fish` — interactive setup: starship, zoxide, fzf, fnm

`alias cd=z` is the one alias that lives in `config.fish` rather than
`conf.d/aliases.fish`. zoxide copies the existing `cd` into its own
`__zoxide_cd_internal` when it initializes, so an alias defined before that
init makes zoxide call the alias and recurse until the call stack blows up.

## Machine specific settings

Anything that should not be committed (API keys, work-only config) goes in
files that are gitignored and sourced automatically:

- `~/.config/fish/local.fish` — sourced at the end of `config.fish`
- `~/.gitconfig.local` — pulled in by `[include]` in `~/.gitconfig`

```fish
# ~/.config/fish/local.fish
set -gx SOME_API_KEY "..."
```

## Tools

Installed by `bootstrap.sh`: fish, git, curl, bat, eza, fzf, zoxide, ripgrep,
btop, unzip, starship, fnm, bun, JetBrainsMono Nerd Font.

Installed manually: [ghostty](https://ghostty.org/download),
[herdr](https://github.com/herdrdev/herdr/releases),
[zed](https://zed.dev).

## Making fish the login shell

`bootstrap.sh` sets it automatically (as root, or via `sudo`/an interactive
`chsh` prompt otherwise) and remembers the previous shell in
`~/.dotfiles-backup/previous-shell` so `revert.sh` can put it back. If you
only ran `install.sh`, it just prints a reminder:

```sh
chsh -s "$(command -v fish)"
```
