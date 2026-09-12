# machines

Your machines, described one file each, all consuming a shared preference
library. This repo is where identity lives: usernames, hostnames, home paths,
per-machine divergences. The library never learns any of it. Keep this repo
private if you like; it holds no secrets either way - secrets never go in
either repo.

> **Provisional.** The exported modules now honor this contract: identity is
> yours (`home.username`/`home.homeDirectory`/`stateVersion`), authored config
> arrives read-only from the nix store, and the override mechanisms below are
> implemented. What remains before this banner goes: the library's consumer
> build from a clean committed revision and its disposable-account behavioral
> run (its `docs/build-order.md`, tasks 3.6-3.7).

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

- **Simple preferences** ship as `lib.mkDefault`: assign your own value in a
  module here and it wins, and the rest of the library's settings stay.
- **Removing a package**: name it in the library's option:

  ```nix
  dotfiles.excludePackages = [ "lazygit" ];
  ```

  This filters only the library's base list. Do not `lib.mkForce` over
  `home.packages` instead: that discards every module-contributed package
  (zsh, starship, pi's node runtime), not just the one you meant.

- **Editor and terminal tweaks** go in `~/.config/dotfiles-local/`, outside
  anything the library manages, loaded when present and skipped silently
  when absent. `nvim.lua` is plain Lua, run after the library's config.
  `wezterm.lua` must return a function that receives the config table:

  ```lua
  -- ~/.config/dotfiles-local/wezterm.lua
  return function(config)
    config.font_size = 13.0
  end
  ```

- **First `nvim` open is silent by design.** Activation already restored
  every plugin to the library's pins, so there is no install splash; a quiet
  start IS the success case. You only see lazy's installer when pins change.
- **herdr's binary ships in the darwin composition** (Homebrew). A
  standalone home-manager consumer gets herdr's config but must install the
  binary themselves; the config is inert without it.
- **Settings their apps rewrite** (Claude Code's and Pi's `settings.json`)
  arrive as real, writable files seeded from the library. They follow
  library updates only until you change them in the app; after that your
  local file wins and is never overwritten.

## Developing the library

Set one option in your machine's module to work on the library itself:

```nix
dotfiles.devCheckout = "/path/to/your/dotfiles/checkout";
```

Every authored config file then links into that checkout and is editable in
place without a rebuild. Unset it to return to read-only store files; local
settings edits are preserved across both transitions, and plugin pins
reconcile automatically.
