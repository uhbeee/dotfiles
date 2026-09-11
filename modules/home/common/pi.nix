{ config, ... }:

let
  authored = config.lib.dotfiles.authored;
  # Pi's SettingsManager writeFileSync's ~/.pi/agent/settings.json (verified
  # in the pinned 0.85.1 dist), so it gets the managed-defaults-with-local-
  # state arrangement. themes/, extensions/ and models.json are only read;
  # Pi's other mutable state (auth.json, models-store.json, npm/, sessions/,
  # the calm toggle) is sibling files, local and unmanaged.
  ms = config.lib.dotfiles.managedSettings {
    relpath = "home/.pi/agent/settings.json";
    target = ".pi/agent/settings.json";
    marker = "pi-settings.seeded";
  };
in
{
  home.file.".pi/agent/themes".source = authored "home/.pi/agent/themes";
  home.file.".pi/agent/extensions".source = authored "home/.pi/agent/extensions";
  home.file.".pi/agent/models.json".source = authored "home/.pi/agent/models.json";

  home.file.".pi/agent/settings.json" = ms.file;
  home.activation.piSettingsToDev = ms.toDev;
  home.activation.piSettingsSeed = ms.seed;
}
