# Project notes for agents

This repo is a preference library: it exports home-manager and nix-darwin
modules and describes no machine and no person. Machines live in a separate
private machines repo that consumes these outputs (scaffold:
`nix flake init -t <this-flake>#machine`); rebuilds run from there. The
template's README owns first-install, update and recovery.

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

## Cross-platform rule: built on one platform = installed on all

A change built for one platform is wired for every supported platform
(macOS, Linux, WSL) as much as possible: common modules by default,
platform-gated with mkIf only when the thing itself is platform-bound.
The `checks` output in flake.nix enforces this mechanically - it builds a
synthetic user-agnostic home closure per supported system, so run
`nix flake check` after module changes; each architecture's check builds
natively on a box of that architecture (the Mac for aarch64-darwin, the
WSL box for x86_64-linux).

## Other deliberate decisions - do NOT silently revert them

- `homebrew.onActivation.cleanup = "zap"` in `modules/system/darwin/homebrew.nix`
  is intentional.
  It forces every Homebrew package to be declared in the Nix config instead of
  installed ad-hoc, which is what keeps the machine reproducible. Do not soften
  it to `uninstall` or `none`.
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

Authored config under `home/` is store-managed and read-only by default; the
`dotfiles.devCheckout` option flips every authored link to edit-in-place via
`mkOutOfStoreSymlink` (see `modules/home/common/options.nix`). The option is
set - like all identity - in the consuming machines repo's machine file, never
here. When a machine sets it to a local checkout of this repo, files under
`home/` are edited there directly and take effect without a rebuild; adding a
*new* symlink still needs a rebuild (from the machines repo), and consumers
without the option get the store path. Work that lands upstream reaches such a
machine in two steps, both needed: the rebuild creates the new links, and a
pull in that checkout supplies their contents - merging a PR alone changes
nothing there. Do not assume the checkout you are working in is live-linked:
that depends on the machine's setting.

Secrets and runtime state never belong in this repo. `gh`'s token lives in
`~/.config/gh/hosts.yml`, which is deliberately unmanaged, and herdr's logs,
sockets and session state are gitignored. Check `.gitignore` before adding
anything that a tool writes at runtime.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
