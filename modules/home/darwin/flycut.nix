{ config, lib, pkgs, ... }:

{
  # GUI-adjacent (a menu bar app) and macOS-only, so present only on darwin
  # at profile "full"; both conditions gate the contents with mkIf, never a
  # conditional import (trap A). Without the platform half, a Linux "full"
  # consumer would carry an enabled agent definition pointing at a macOS
  # app path - inert under home-manager's own darwin gate, but a leak.
  #
  # Start Flycut at login. Its own "launch at startup" preference registers a
  # login item outside this repo, so drive it from launchd instead and leave
  # that preference off, or the app starts twice.
  config = lib.mkIf (pkgs.stdenv.hostPlatform.isDarwin && config.dotfiles.profile == "full") {
    launchd.agents.flycut = {
      enable = true;
      config = {
        ProgramArguments = [ "/Applications/Flycut.app/Contents/MacOS/Flycut" ];
        RunAtLoad = true;
        KeepAlive = false;  # a menu bar app I quit on purpose should stay quit
      };
    };
  };
}
