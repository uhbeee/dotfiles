# machines

Your machines, described one file each, all consuming a shared preference
library. This repo is where identity lives: usernames, hostnames, home paths,
per-machine divergences. The library never learns any of it. Keep this repo
private if you like; it holds no secrets either way - secrets never go in
either repo.

> **Provisional.** This scaffold describes the target contract, and the
> library has not finished migrating to it (its `docs/build-order.md`, phases
> 3-4). Today the exported modules still require a bespoke `user` argument,
> pin their own `home.stateVersion`, and link config files through
> `~/.dotfiles`, so neither composition below builds for a consumer yet, and
> the `mkDefault`/`dotfiles-local` override mechanisms do not exist yet. This
> banner is removed when the library's phase 3 lands and these compositions
> are verified from outside.

## Layout

- `flake.nix` binds this repo to the library and defines one output per
  machine, in two compositions:
  - `homeConfigurations."<user>@<host>"` - standalone home-manager, for any
    machine where you own the home directory but not the OS.
  - `darwinConfigurations.<host>` - nix-darwin owning a whole Mac, with
    home-manager inside it.
- `machines/<host>.nix` - one file per machine. Identity, platform,
  `stateVersion`, and anything true of that machine and nothing else.

First step: edit `flake.nix` and point `dotfiles.url` at the real library,
then rename and fill in `machines/example.nix` for your first machine.

## First install

On a Mac, install [Determinate Nix](https://determinate.systems) first (the
compositions here assume it: `nix.enable = false` leaves the daemon to it),
then, in this repo:

```sh
git init && git add -A     # flakes only see tracked files
nix flake lock             # write flake.lock, unprivileged

# Whole Mac: build unprivileged first, then switch as root using the
# darwin-rebuild this flake locked - not whatever the registry resolves today.
nix build .#darwinConfigurations.<host>.system
sudo ./result/sw/bin/darwin-rebuild switch --flake .#<host> --no-update-lock-file
readlink /run/current-system   # must print the same path as: readlink ./result

# Home directory only:
nix build .#homeConfigurations."<user>@<host>".activationPackage
./result/activate
```

`darwin-rebuild switch` re-evaluates the flake as root. `--no-update-lock-file`
only keeps root from rewriting `flake.lock`; nothing freezes the source files,
so do not edit the checkout or the lock between the build and the switch. The
`readlink` comparison at the end is what verifies you held to that: it proves
root activated exactly the prebuilt system rather than a fresh one. Keep all
three parts of the pattern on every switch.

After a darwin switch, the pinned `darwin-rebuild` lives in the activated
system at `/run/current-system/sw/bin`. The standalone composition installs
the `home-manager` CLI from this flake's locked input
(`programs.home-manager.enable`); activating the package is what puts it on
PATH.

Commit `flake.lock` once the first switch succeeds. That commit is your
known-good baseline.

## Updating

```sh
nix flake update dotfiles   # unprivileged; rewrites flake.lock

# Whole Mac:
nix build .#darwinConfigurations.<host>.system
sudo ./result/sw/bin/darwin-rebuild switch --flake .#<host> --no-update-lock-file
readlink /run/current-system   # matches readlink ./result

# Standalone home directory:
nix build .#homeConfigurations."<user>@<host>".activationPackage
./result/activate
```

The lock update changes inputs; the rebuild is what applies them. Commit
`flake.lock` only after a good rebuild: the commit history of that one file is
your record of known-working combinations, and the recovery steps below depend
on it.

## Recovery

Every switch creates a generation, so most bad updates are a rollback. No
flake evaluation is involved, so run the tool of the currently active system:

```sh
/run/current-system/sw/bin/darwin-rebuild --list-generations
sudo /run/current-system/sw/bin/darwin-rebuild switch --rollback
# standalone home-manager:
home-manager generations   # then run the listed generation's activate script
```

Two honest limits. Rolling back re-runs the selected generation's activation,
Homebrew included, so casks the bad generation removed are reinstalled then
and there - but at whatever version Homebrew serves today, not the one you
had, and application data that a `zap` uninstall purged is not restored.
Generations are configuration, not backup: keep an inventory
(`brew list --versions`) and a real backup of application data before risky
updates.

If a library update caused it, also pin the inputs back. `git checkout
flake.lock` only restores the *committed* lock - after you commit an update,
that is the broken one. Restore from the known-good commit explicitly, then
prebuild and switch the restored inputs like any other change:

```sh
git log --oneline -- flake.lock          # find the last good rebuild's commit
git checkout <good-commit> -- flake.lock
nix build .#darwinConfigurations.<host>.system
sudo ./result/sw/bin/darwin-rebuild switch --flake .#<host> --no-update-lock-file
readlink /run/current-system   # matches readlink ./result
```

## Diverging from the library

*(Target contract; lands with the library's phase 3.)*

- **Simple preferences** ship as `lib.mkDefault`: assign your own value in a
  module here and it wins.
- **Removing a package**: the library exports its list as data. Filter it:

  ```nix
  home.packages = lib.mkForce
    (builtins.filter (p: (p.pname or "") != "lazygit")
      (dotfiles.lib.basePackages pkgs));
  ```

- **Editor and terminal tweaks** go in `~/.config/dotfiles-local/`
  (`nvim.lua`, `wezterm.lua`), loaded when present, outside anything the
  library manages.
