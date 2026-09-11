{ config, ... }:

let
  # Claude Code rewrites settings.json in place through symlinks (audited:
  # the link chain survives its writes). Shared arrangement; semantics and
  # ordering documented in modules/home/common/managed-settings.nix.
  ms = config.lib.dotfiles.managedSettings {
    relpath = "home/.claude/settings.json";
    target = ".claude/settings.json";
    marker = "claude-settings.seeded";
  };
in
{
  home.file.".claude/settings.json" = ms.file;
  home.activation.claudeSettingsToDev = ms.toDev;
  home.activation.claudeSettingsSeed = ms.seed;
}
