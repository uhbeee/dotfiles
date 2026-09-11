{ config, lib, pkgs, ... }:

{
  # Shared arrangement for settings files their applications rewrite in place
  # (Claude Code and Pi both writeFileSync their settings.json). A bare
  # read-only store file would break the app's own settings UI, so:
  #
  # - dev mode: the historical edit-in-place link into the checkout, where
  #   writes landing in the repo is the point. force is set because a store
  #   stint leaves a real seeded file where the link goes; the toDev
  #   migration below preserves it first.
  # - store mode: a real, writable file seeded from the library default.
  #   It follows library updates only while byte-identical to the last seed;
  #   a diverged file is the user's and is left alone.
  #
  # Mode transitions never lose local edits: entering dev preserves a
  # diverged file as <name>.pre-dev (numbered, never overwriting an earlier
  # backup) and records which backup it made; returning to store restores
  # exactly that recorded file, never an unrelated historical backup, and
  # reseeds the default otherwise. All mutations run in the write phase (after
  # writeBoundary, before/after linkGeneration), so a preflight abort - an
  # unrelated collision in checkLinkTargets - leaves the old arrangement
  # untouched.
  #
  # Callers pass: relpath (repo-relative source), target (home-relative
  # path), marker (state-file name). They wire the results as:
  #   home.file.<target> = ms.file;
  #   home.activation.<name>ToDev = ms.toDev;
  #   home.activation.<name>Seed = ms.seed;
  config.lib.dotfiles.managedSettings = { relpath, target, marker }:
    let
      cfg = config.dotfiles;
      source = ../../.. + "/${relpath}";
      stateRef = ''"''${XDG_STATE_HOME:-$HOME/.local/state}"/dotfiles'';
    in
    {
      file = lib.mkIf (cfg.devCheckout != null) {
        source = config.lib.dotfiles.authored relpath;
        force = true;
      };

      toDev = lib.mkIf (cfg.devCheckout != null)
        (lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
          live="$HOME/${target}"
          seedMarker=${stateRef}/${marker}
          # Records which backup THIS transition created; returning to store
          # mode restores exactly that file, never an unrelated historical
          # backup that happens to sit beside it.
          pendingRestore=${stateRef}/${marker}.pending-restore
          run mkdir -p "$(dirname "$seedMarker")"
          # Only a transition that actually processes a real file may touch
          # the record: repeated dev activations see the managed symlink and
          # must leave a pending record from the original transition intact.
          if [ -f "$live" ] && [ ! -L "$live" ]; then
            run rm -f "$pendingRestore"
            if [ -f "$seedMarker" ] && ${pkgs.diffutils}/bin/cmp -s "$live" "$seedMarker"; then
              run rm "$live"
            else
              backup="$live.pre-dev"
              n=1
              while [ -e "$backup" ]; do
                n=$((n + 1))
                backup="$live.pre-dev.$n"
              done
              run mv "$live" "$backup"
              if [ ! -v DRY_RUN ]; then
                printf '%s\n' "$backup" > "$pendingRestore"
              fi
              echo "${target}: local file diverged from the library seed;" \
                   "preserved at $backup before linking the checkout" >&2
            fi
            run rm -f "$seedMarker"
          fi
        '');

      seed = lib.mkIf (cfg.devCheckout == null)
        (lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          live="$HOME/${target}"
          seedMarker=${stateRef}/${marker}
          default=${lib.escapeShellArg "${source}"}
          run mkdir -p "$(dirname "$live")" "$(dirname "$seedMarker")"
          pendingRestore=${stateRef}/${marker}.pending-restore
          if [ ! -e "$live" ]; then
            # Restore exactly what the last dev transition preserved, if
            # anything; unrelated historical backups stay where they are.
            pending=""
            if [ -f "$pendingRestore" ]; then
              pending=$(cat "$pendingRestore")
            fi
            if [ -n "$pending" ] && [ -f "$pending" ]; then
              run mv "$pending" "$live"
              run rm -f "$pendingRestore"
              echo "${target}: restored preserved local settings from $pending"
            else
              run install -m 0644 "$default" "$live"
              run cp "$default" "$seedMarker"
            fi
          elif [ -f "$seedMarker" ] && ${pkgs.diffutils}/bin/cmp -s "$live" "$seedMarker"; then
            if ! ${pkgs.diffutils}/bin/cmp -s "$default" "$live"; then
              run install -m 0644 "$default" "$live"
              run cp "$default" "$seedMarker"
            fi
          fi
        '');
    };
}
