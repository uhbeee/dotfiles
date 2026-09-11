{ config, lib, ... }:

# herdr, macOS only.

{
  # herdr writes logs, sockets, session state and a plugins lock beside its
  # config at runtime (audited), so only the authored config.toml is managed;
  # ~/.config/herdr itself stays a real directory herdr owns.
  #
  # force: on a machine with the old arrangement (the directory itself a
  # symlink into the checkout), the collision check would see an existing
  # config.toml through that symlink and abort before the migration below is
  # allowed to run. The migration replaces the directory first, so force
  # never actually clobbers foreign data.
  home.file.".config/herdr/config.toml" = {
    source = config.lib.dotfiles.authored "home/.config/herdr/config.toml";
    force = true;
  };

  # Migration from the old arrangement: replace the directory symlink with a
  # real directory and bring the runtime state along rather than abandoning
  # it. Sockets are transient and deliberately not copied. Runs in the write
  # phase (after writeBoundary, before linkGeneration places config.toml),
  # so a preflight abort - an unrelated collision in checkLinkTargets -
  # leaves the old, working arrangement untouched.
  home.activation.herdrStateMigration =
    lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
      herdrDir="$HOME/.config/herdr"
      if [ -L "$herdrDir" ]; then
        oldTarget=$(readlink -f "$herdrDir" 2>/dev/null || true)
        run rm "$herdrDir"
        run mkdir -p "$herdrDir"
        if [ -n "$oldTarget" ] && [ -d "$oldTarget" ]; then
          for f in session.json .plugins.lock herdr-client.log herdr-server.log; do
            if [ -e "$oldTarget/$f" ] && [ ! -e "$herdrDir/$f" ]; then
              run cp -p "$oldTarget/$f" "$herdrDir/$f"
            fi
          done
        fi
      elif [ -f "$herdrDir/config.toml" ] && [ ! -L "$herdrDir/config.toml" ]; then
        # First install over a real directory holding a personal config.toml:
        # force (above) would replace it without trace. Preserve it beside
        # the link instead; never overwrite an earlier preservation.
        backup="$herdrDir/config.toml.pre-dotfiles"
        n=1
        while [ -e "$backup" ]; do
          n=$((n + 1))
          backup="$herdrDir/config.toml.pre-dotfiles.$n"
        done
        run mv "$herdrDir/config.toml" "$backup"
        echo "herdr: existing unmanaged config.toml preserved at $backup" >&2
      fi
    '';
}
