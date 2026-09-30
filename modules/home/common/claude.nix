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
      Ship the authored settings verbatim, herdr's SessionStart hook and the
      authored subagent-reporting hook included, and link that hook's script.
      Off (the portable default), both sets of hook entries are stripped at
      build time and the script is not linked, so consumers get Claude
      settings with no herdr trace.
    '';
  };

  config =
    let
      # Claude Code rewrites settings.json in place through symlinks
      # (audited: the link chain survives its writes). Shared arrangement;
      # semantics and ordering documented in managed-settings.nix.
      #
      # The authored file is complete: it carries herdr's SessionStart hook
      # and this repo's subagent-reporting hook, each behind a runtime
      # existence guard ([ -x ] on the script), so dev mode keeps linking one
      # editable file - and on a dev checkout without herdr the guarded hooks
      # simply no-op. The portable settings are derived from it, not
      # duplicated: the same file with the herdr entries stripped, so the two
      # can never drift.
      #
      # The filter drops whole matcher groups by the script a group runs,
      # across every hook event rather than SessionStart alone: the subagent
      # hook is wired to seven events, and a new one must not silently reach
      # portable consumers.
      relpath = "home/.claude/settings.json";
      portable = pkgs.runCommand "claude-settings-portable.json"
        { nativeBuildInputs = [ pkgs.jq ]; } ''
        jq 'if .hooks then
              .hooks |= with_entries(.value |= map(select(
                [.hooks[]?.command // ""]
                | any(contains("herdr-agent-state.sh")
                      or contains("subagent-pane-metadata.sh")) | not)))
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

      # Linked beside herdr's managed herdr-agent-state.sh, never over it: a
      # single file, so herdr's integration installer keeps owning the
      # directory and its own script. Rides the same switch as the settings
      # entries that call it, so a portable consumer gets neither.
      home.file.".claude/hooks/subagent-pane-metadata.sh" = lib.mkIf
        config.dotfiles.claude.herdrHook
        { source = config.lib.dotfiles.authored "home/.claude/hooks/subagent-pane-metadata.sh"; };
    };
}
