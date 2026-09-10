# dotfiles

My Mac setup, managed with [nix-darwin](https://github.com/nix-darwin/nix-darwin)
and [home-manager](https://github.com/nix-community/home-manager). One repo, one
command, and a fresh Mac ends up configured the same way every time.

## Principle: user and device agnostic

**Nothing about a specific person or a specific machine belongs in this repo.**

Clone it, supply your own details locally, and it configures your machine. No
forking, no editing tracked files, no pull request needed to use it. If your
setup diverges from mine later, that divergence is yours and stays on your
machine - it never has to come back here.

- **Identity** - name, email, username - is supplied at setup time or read from
  an untracked local file. It is never committed.
- **Machine specifics** - hostname, CPU architecture, hardware - belong to the
  host file for that machine, never to shared config.
- **Secrets** never enter the repo at all.

Anything tracked here that is specific to one person or one machine is a bug.

## Credit

This started as a follow-along of [Kun Chen](https://github.com/kunchenguid)'s
[dotfiles](https://github.com/kunchenguid/dotfiles). The structure, the
`mkOutOfStoreSymlink` edit-in-place approach, and the Neovim config are all his.
Original is MIT-0.

I'm taking it from here as my own setup, so this will keep drifting from
upstream. Anything broken in here is mine, not his.

## What it configures

- **System**: dark mode, fast key repeat, auto-hiding dock and menu bar, Finder list view, tap to click
- **Shell**: zsh with autosuggestions and syntax highlighting, starship prompt, aliases
- **CLI**: ripgrep, fd, fzf, jq, lazygit, neovim, git, gh, Hack Nerd Font
- **Apps** via Homebrew: wezterm, claude-code, herdr
- **Editor**: Neovim with rose-pine moon, oil, snacks, neogit, gitsigns, which-key
- **Agents**: one `home/AGENTS.md` shared by Claude Code, Codex and opencode

## Usage

On a fresh Mac:

```sh
git clone https://github.com/uhbeee/dotfiles.git
cd dotfiles
./bootstrap.sh
```

`bootstrap.sh` installs Determinate Nix, symlinks this repo to `~/.dotfiles`,
matches the username in `flake.nix` to yours, and runs the first switch.

For every change after that:

```sh
./rebuild.sh
```

Most files under `home/` are symlinked back into this repo, so editing them takes
effect immediately. Only adding a *new* symlink needs a rebuild.

## Before you run it

`configuration.nix` sets `homebrew.onActivation.cleanup = "zap"`, which removes
any Homebrew package or cask not listed in `brews` and `casks`. Read that list
first and add anything you want to keep.

`gh auth login` still has to be run once per machine. The token is a secret and
is deliberately not tracked here.
