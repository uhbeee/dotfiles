# machines

Your machines, described one file each, all consuming a shared preference
library. This repo is where identity lives: usernames, hostnames, home paths,
per-machine divergences. The library never learns any of it. Keep this repo
private if you like; it holds no secrets either way - secrets never go in
either repo.

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
then write your first machine file ("First install" below walks through it).

## First install

Order matters on a bare machine: this repo must arrive before any
configuration can install the tools that make arriving easy.

1. **Get this repo.** If it is private, none of your usual credentials
   exist yet: create a fine-grained personal access token in the GitHub
   web UI (contents: read) and clone over HTTPS, pasting the token as
   the password. `gh` arrives with the first switch below; run
   `gh auth login` afterwards and its credential helper takes over from
   the throwaway token.

2. **Install [Determinate Nix](https://determinate.systems)** (the
   compositions here assume it: `nix.enable = false` leaves the daemon
   to it):

   ```sh
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
     | sh -s -- install --no-confirm
   ```

   Then open a new terminal so `nix` is on PATH.

3. **Git identity.** The library keeps identity out of both repos: git
   includes `~/.gitconfig.local` at runtime. Write it before your first
   commit:

   ```ini
   # ~/.gitconfig.local - machine-local, never committed anywhere
   [user]
       name = Your Name
       email = you@example.com
   ```

4. **Describe the machine**: copy an existing machine file (a fresh
   scaffold ships `machines/example.nix`; a lived-in repo has one per
   machine) to `machines/<host>.nix`, answer its questions, and point
   `flake.nix`'s `machine =` line at it.

5. **Library checkout, only if the machine file sets
   `dotfiles.devCheckout`.** That option makes every authored config
   link point into a local checkout of the library, so the checkout
   (and any symlink the configured path goes through) must exist before
   the first switch or the links dangle. Clone the library to that path
   now. Machines that omit the option need no checkout: they get
   read-only files from the nix store, the default.

Then, in this repo:

```sh
git init && git add -A     # flakes only see tracked files
nix flake lock             # write flake.lock, unprivileged

# Whole Mac: build unprivileged first, then switch as root using the
# darwin-rebuild this flake locked - not whatever the registry resolves today.
nix build .#darwinConfigurations.<host>.system
shasum flake.lock > /tmp/lock.sum
sudo ./result/sw/bin/darwin-rebuild switch --flake .#<host> --no-update-lock-file
readlink /run/current-system   # must print the same path as: readlink ./result
shasum -c /tmp/lock.sum        # lock contents unchanged by root
stat -f '%Su' flake.lock       # still owned by you, not root

# Home directory only:
nix build .#homeConfigurations."<user>@<host>".activationPackage
./result/activate
```

`darwin-rebuild switch` re-evaluates the flake as root. `--no-update-lock-file`
only keeps root from rewriting `flake.lock`; nothing freezes the source files,
so do not edit the checkout or the lock between the build and the switch. The
checks at the end verify you held to that: the `readlink` comparison proves
root activated exactly the prebuilt system rather than a fresh one, the
checksum proves the lock's *contents* survived, and the ownership check proves
root did not take the file over (ownership and content are separate
properties; a root-owned lock breaks the next unprivileged `nix flake lock`).
Keep every part of the pattern on every switch.

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

# Whole Mac: same switch pattern as the first install, all checks included.
nix build .#darwinConfigurations.<host>.system
shasum flake.lock > /tmp/lock.sum
sudo ./result/sw/bin/darwin-rebuild switch --flake .#<host> --no-update-lock-file
readlink /run/current-system   # matches readlink ./result
shasum -c /tmp/lock.sum        # lock contents unchanged by root
stat -f '%Su' flake.lock       # still owned by you

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
shasum flake.lock > /tmp/lock.sum
sudo ./result/sw/bin/darwin-rebuild switch --flake .#<host> --no-update-lock-file
readlink /run/current-system   # matches readlink ./result
shasum -c /tmp/lock.sum        # lock contents unchanged by root
stat -f '%Su' flake.lock       # still owned by you
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
