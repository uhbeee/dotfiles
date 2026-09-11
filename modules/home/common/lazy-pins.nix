{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles;
  mode = if cfg.devCheckout != null then "dev" else "store";
  libLock = ../../../home/.config/nvim/lazy-lock.json;

  # Revision verification: every pinned plugin's checkout must sit at exactly
  # the locked commit. Run with: nvim -l <this> <lockfile> <lazy plugin root>.
  verifier = pkgs.writeText "verify-lazy-pins.lua" ''
    local lockfile, root = arg[1], arg[2]
    local f = assert(io.open(lockfile, 'r'))
    local pins = vim.json.decode(f:read('*a'))
    f:close()
    local bad = {}
    for name, pin in pairs(pins) do
      local dir = root .. '/' .. name
      if not vim.uv.fs_stat(dir) then
        bad[#bad + 1] = name .. ': missing'
      else
        local head = vim.fn.system({ 'git', '-C', dir, 'rev-parse', 'HEAD' }):gsub('%s+$', "")
        if vim.v.shell_error ~= 0 then
          bad[#bad + 1] = name .. ': not a git checkout'
        elseif head ~= pin.commit then
          bad[#bad + 1] = name .. ': at ' .. head:sub(1, 12) .. ', pinned ' .. pin.commit:sub(1, 12)
        end
      end
    end
    if #bad > 0 then
      io.stderr:write('lazy pins not converged:\n  ' .. table.concat(bad, '\n  ') .. '\n')
      os.exit(1)
    end
  '';
in
{
  # The library's committed lockfile is the source of truth for plugin pins.
  # A marker records "<mode> <sha256 of the reference lockfile applied>" and
  # only advances after a restore that verified every pinned revision.
  #
  # Two hard-won rules. The marker is invalidated BEFORE any restore attempt:
  # a partial restore changes installed plugins, so a stale success record
  # would let a later rollback to the previously converged pins skip the
  # reconciliation it now needs. And verification reads the immutable
  # reference pins (the store copy, or a pre-restore snapshot in dev mode),
  # never lazy's working lockfile: `Lazy! restore` rewrites that file to the
  # revisions actually installed, including after failures, so verifying
  # against it would bless whatever happened.
  #
  # Restores need the network, so failure reports and continues rather than
  # blocking the rebuild; the missing marker retries it on the next
  # activation.
  home.activation.lazyPins = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    (
      export PATH="${lib.makeBinPath [ pkgs.git pkgs.neovim pkgs.coreutils ]}:$PATH"
      stateDir="''${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
      lazyRoot="''${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"
      marker="$stateDir/.dotfiles-lazy-applied"
      mkdir -p "$stateDir"

      ${if mode == "dev" then ''
        workLock="${cfg.devCheckout}/home/.config/nvim/lazy-lock.json"
        if [ ! -f "$workLock" ]; then
          echo "lazy pins: no lockfile at $workLock; skipping" >&2
          exit 0
        fi
        # Immutable reference: lazy works against the checkout lockfile and
        # may rewrite it, so verification needs a pre-restore snapshot. The
        # snapshot is only refreshed when no reconciliation is pending (the
        # marker survived the last run); while one is pending - including
        # after an interrupted restore that never reached the copy-back
        # below - the existing reference IS the requested pins, and the
        # worklock is reinstated from it rather than trusted.
        refLock="$stateDir/.dotfiles-lazy-ref"
        if [ -f "$marker" ] || [ ! -f "$refLock" ]; then
          run install -m 0644 "$workLock" "$refLock"
        elif ! cmp -s "$refLock" "$workLock"; then
          run install -m 0644 "$refLock" "$workLock"
          echo "lazy pins: reconciliation pending; reinstated the requested pins to $workLock" >&2
        fi
      '' else ''
        # Refresh the machine's writable copy (lazy's working lockfile)
        # whenever the library pins moved. The immutable store file is the
        # verification reference; the marker decides whether a restore ran.
        refLock=${libLock}
        workLock="$stateDir/lazy-lock.json"
        if ! cmp -s "$refLock" "$workLock"; then
          run install -m 0644 "$refLock" "$workLock"
        fi
      ''}

      want="${mode} $(sha256sum < "$refLock" | cut -d' ' -f1)"
      have=$(cat "$marker" 2>/dev/null || true)
      if [ "$want" != "$have" ]; then
        echo "lazy pins: reconciling installed plugins with the ${mode} lockfile"
        # Invalidate the old success record first: from here on, installed
        # plugins may no longer match ANY previously verified state.
        run rm -f "$marker"
        if run nvim --headless "+Lazy! restore" +qa \
            && run nvim -l ${verifier} "$refLock" "$lazyRoot"; then
          if [ ! -v DRY_RUN ]; then
            printf '%s\n' "$want" > "$marker"
          fi
          echo "lazy pins: converged"
        else
          ${lib.optionalString (mode == "dev") ''
            # lazy rewrote the working (checkout) lockfile to whatever got
            # installed. Put the requested pins back, so the developer's file
            # is not silently corrupted and the retry on the next activation
            # re-snapshots the ORIGINAL pins instead of blessing the rewrite.
            if ! cmp -s "$refLock" "$workLock"; then
              run install -m 0644 "$refLock" "$workLock"
              echo "lazy pins: restored the requested pins to $workLock after the failed restore" >&2
            fi
          ''}
          echo "lazy pins: restore did not converge; continuing, will retry on the next activation" >&2
        fi
      fi
    )
  '';
}
