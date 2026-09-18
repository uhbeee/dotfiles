# dotfiles

A preference library, managed with [nix-darwin](https://github.com/nix-darwin/nix-darwin)
and [home-manager](https://github.com/nix-community/home-manager). It exports
the configuration as flake modules; a separate machines repo, one per person,
consumes them and describes the actual machines. The library supplies the
shared defaults; each machine's own overrides, exclusions and lock graph
decide what it actually builds.

## Principle: user and device agnostic

**Nothing about a specific person or a specific machine belongs in this repo.**

Point your machines repo at it and it configures your machine. No forking, no
editing tracked files, no pull request needed to use it. If your setup
diverges from mine later, that divergence is yours and stays in your machines
repo - it never has to come back here.

- **Identity** - name, email, username - lives in the machines repo's host
  file or an untracked local file. It is never committed here.
- **Machine specifics** - hostname, CPU architecture, hardware - belong to the
  host file for that machine, never to shared config.
- **Secrets** never enter either repo at all.

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
- **Agents**: one `home/AGENTS.md` shared by Claude Code, Codex and opencode,
  plus the agent skills below

## Agent skills

Skill families shipped by default, usable from both Claude Code (skills)
and Codex (custom prompts):

| Family | What it does | Docs |
|--------|--------------|------|
| `plan-*` | Plan-driven work with AI agents: create a plan through an interview and design review, implement work items, gate each through an impartial cross-LLM review loop, keep the plan docs synced. All agent-to-agent communication goes through auditable markdown. | [README](home/.config/plan-skills/README.md) |

New families get a row here and their own README next to their core files.

## Usage

This repo is only the library - it names no machine and no person, and
nothing here is applied directly. Your machines live in a separate (private,
if you like) machines repo that consumes these outputs; its README covers
first install on a bare machine, updates, and recovery. Scaffold one below.

Library developers set `dotfiles.devCheckout` in their machine file to a
local checkout of this repo: authored files under `home/` then symlink back
here and edits take effect immediately. Only adding a *new* symlink needs a
rebuild (run from the machines repo).

## Consuming it as a library

The flake also exports its modules, so a separate machines repo can consume
them instead of cloning this one.

The modules read standard `home.username`/`home.homeDirectory`, impose no
`stateVersion`, and authored config arrives read-only from the nix store -
verified by consumer builds from a clean committed revision and a behavioral
run in a disposable account. Overrides: `mkDefault` scalars,
`~/.config/dotfiles-local/` files, `dotfiles.excludePackages`. Scope is
`dotfiles.profile`: the default `"full"` is everything, `"cli"` drops the
GUI-adjacent config (WezTerm and friends) for servers and containers -
home config only, system scope is which system modules a host imports.
Library developers set `dotfiles.devCheckout` to a local checkout to get
edit-in-place links instead of store files. The outputs:

- `homeManagerModules.default` - shell, editor, CLI, prompt, agents
- `darwinModules.default` - the macOS system preferences, self-contained
- `nixosModules.default` - the NixOS system base (flakes enabled, zsh
  system-side), deliberately small
- `nixosModules.gnome` - plain GNOME plus the WezTerm app, separately
  importable: whether a host gets a desktop is the host file's decision,
  never the home profile's
- `overlays.default` - the pinned-package overlay (Pi), so consumers build
  the same versions this repo tests against
- `lib.basePackages` - the package list as data, a function of `pkgs`;
  removal on one machine is the `dotfiles.excludePackages` option
- `templates.machine` - scaffolds that machines repo

Already have a machines repo? Add `dotfiles` as an input with
`nixpkgs.follows`/`home-manager.follows`, import the module, write the machine
file. A NixOS machine imports `nixosModules.default` (plus `nixosModules.gnome`
for a desktop) alongside home-manager's NixOS module, with the host directory
owning identity, hardware and disk layout - the template's
`nixosConfigurations` output shows the exact wiring. Starting from nothing:

```sh
mkdir machines && cd machines
nix flake init -t github:uhbeee/dotfiles#machine
```

The scaffold ships all three target compositions (standalone home-manager,
nix-darwin with home-manager inside, and NixOS with home-manager inside),
example machine files, and the install/update/recovery runbook - including
the nixos-anywhere fresh-install path with a declarative disko disk layout.
The per-machine convention is documented there, next to the files it
governs.

## Support matrix

Statuses are earned by gates actually run, never inferred, and are scoped
by platform, architecture and profile. **validated**: activated and
exercised at runtime. **build-only**: the closure built through a real
build route; runtime never exercised. **runtime-untested**: builds, but
this exact runtime integration has never run. **untested**: not even a
build has run.

| Target | Arch | Profile | Status |
|---|---|---|---|
| macOS, nix-darwin + home-manager | aarch64 | full | validated - the daily-driver composition |
| macOS, standalone home-manager | aarch64 | cli + full | validated - consumer-probe builds every test run; behavioral pass in a disposable account |
| NixOS, system + home-manager modules | x86_64 | full | validated - real install; GNOME, WezTerm and nvim run from the library |
| NixOS, system + home-manager modules | aarch64 | - | untested |
| Non-NixOS Linux, standalone home-manager | aarch64 | cli | validated - Ubuntu container: activation, tool use, a second switch |
| Non-NixOS Linux, standalone home-manager | aarch64 | full | runtime-untested - the generic-Linux GUI path has never run on a real desktop; the closure itself builds |
| Non-NixOS Linux, standalone home-manager | x86_64 | cli | build-only - built through the Linux build route |
| Non-NixOS Linux, standalone home-manager | x86_64 | full | runtime-untested - as aarch64 full; the closure builds through the Linux build route |
| NixOS-WSL | x86_64 | cli | untested - not yet built; provisional once the tarball builds, validated only after a Windows import/login/rebuild/restart pass |

The container row covers Ubuntu, servers, and Ubuntu-under-WSL, which is
standalone home-manager like the rest; NixOS-WSL is its own row because it
is a different installation, not a variant.

## Before you run it

`modules/system/darwin/homebrew.nix` sets `homebrew.onActivation.cleanup = "zap"`, which removes
any Homebrew package or cask not listed in `brews` and `casks`. Read that list
first and add anything you want to keep.

`gh auth login` still has to be run once per machine. The token is a secret and
is deliberately not tracked here.
