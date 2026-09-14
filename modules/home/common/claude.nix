{ config, lib, pkgs, ... }:

{
  # Wiring between library modules, not a consumer option (the consumer
  # surface stays at profile/devCheckout/excludePackages). The darwin herdr
  # module sets it, keeping herdr's Claude integration beside herdr; nothing
  # else should.
  options.dotfiles.claude.herdrHook = lib.mkOption {
    type = lib.types.bool;
    default = false;
    internal = true;
    description = ''
      Ship the authored settings verbatim, herdr's SessionStart hook
      included. Off (the portable default), the hook entry is stripped at
      build time and consumers get Claude settings with no herdr trace.
    '';
  };

  config =
    let
      # Claude Code rewrites settings.json in place through symlinks
      # (audited: the link chain survives its writes). Shared arrangement;
      # semantics and ordering documented in managed-settings.nix.
      #
      # The authored file is complete: it carries herdr's SessionStart hook
      # behind a runtime existence guard ([ -x ] on the script herdr itself
      # installs), so dev mode keeps linking one editable file - and on a
      # dev checkout without herdr the guarded hook simply no-ops. The
      # portable settings are derived from it, not duplicated: the same
      # file with the herdr entries stripped, so the two can never drift.
      relpath = "home/.claude/settings.json";
      portable = pkgs.runCommand "claude-settings-portable.json"
        { nativeBuildInputs = [ pkgs.jq ]; } ''
        jq 'if .hooks then
              .hooks.SessionStart |= map(select(
                [.hooks[]?.command // ""]
                | any(contains("herdr-agent-state.sh")) | not))
              | .hooks |= with_entries(select(.value != []))
              | (if .hooks == {} then del(.hooks) else . end)
            else . end' ${../../.. + "/${relpath}"} > "$out"
      '';
      ms = config.lib.dotfiles.managedSettings {
        inherit relpath;
        target = ".claude/settings.json";
        marker = "claude-settings.seeded";
        source = if config.dotfiles.claude.herdrHook then null else portable;
      };
    in
    {
      home.file.".claude/settings.json" = ms.file;
      home.activation.claudeSettingsToDev = ms.toDev;
      home.activation.claudeSettingsSeed = ms.seed;
    };
}
