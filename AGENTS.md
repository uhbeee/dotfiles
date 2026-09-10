# Project notes for agents

This repo is the single source of truth for a Mac's configuration. `rebuild.sh`
applies it; `bootstrap.sh` takes a bare machine to that point.

## Governing principle: user and device agnostic

Nothing about a specific person or a specific machine may be committed to this
repo. Someone else must be able to clone it untouched, supply their own details
locally, and configure their own machine - no fork, no edit to a tracked file,
no pull request.

Identity (name, email, username) is supplied at setup time or read from an
untracked local file. Machine specifics (hostname, architecture, hardware)
belong to that machine's host file. Secrets never enter the repo.

When adding anything, ask whether it would be wrong on someone else's machine.
If so, it is a parameter, not a committed value. This outranks convenience:
do not hardcode a value merely because there is currently one user.

Git identity is handled: `home.nix` sets `programs.git.includes` to
`~/.gitconfig.local`, so git resolves the identity at runtime and Nix never
reads it. Do not reintroduce `programs.git.settings.user` here.

One exception remains: `user` in `flake.nix`. Nix needs the username at
evaluation time, and **flakes only see git-tracked files**, so it cannot come
from an untracked `local.nix` - that was verified, not assumed, and the file is
simply absent from the flake's store copy. `bootstrap.sh` rewrites the line to
match whoever runs it; the cross-platform migration moves it into per-machine
host files so shared config carries no username.

## Other deliberate decisions - do NOT silently revert them

- `homebrew.onActivation.cleanup = "zap"` in `configuration.nix` is intentional.
  It forces every Homebrew package to be declared in the Nix config instead of
  installed ad-hoc, which is what keeps the machine reproducible. Do not soften
  it to `uninstall` or `none`.
- The username is threaded from a single point via `specialArgs`, never
  hardcoded in more than one place. Under the governing principle above it
  should ultimately not be committed at all; until then, one definition only.
- The host label `"mac"` appears in `flake.nix`, `rebuild.sh` and `bootstrap.sh`.
  All three have to agree.
- `o.mouse = ''` in `home/.config/nvim/lua/vim_config.lua` is set so Herdr can
  leave host mouse capture off and Escape isn't swallowed. It is not an oversight.
- `homebrew.masApps` is deliberately unused. The activation runs brew bundle via
  `sudo --user=<user>`, which has no App Store session, so `mas list` returns
  nothing, every declared App Store app reads as missing, and the reinstall it
  attempts fails and aborts the whole rebuild. Verified by running the same
  Brewfile in a normal shell, where the same entry reports `Using Magnet` and
  succeeds. App Store apps that have a Homebrew cask belong in `casks`; the rest
  are installed by hand. Note masApps is also exempt from the `zap` cleanup, so
  it never managed removal either.

Config lives in the repo and is symlinked into place with `mkOutOfStoreSymlink`,
so files under `home/` are edited here directly and take effect without a rebuild.
Adding a *new* symlink still needs a rebuild.

Secrets and runtime state never belong in this repo. `gh`'s token lives in
`~/.config/gh/hosts.yml`, which is deliberately unmanaged, and herdr's logs,
sockets and session state are gitignored. Check `.gitignore` before adding
anything that a tool writes at runtime.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
