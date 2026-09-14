{ config, lib, pkgs, ... }:

{
  # GUI-adjacent (screen capture is a desktop concern) and macOS-only (the
  # directory exists for the darwin system module's screencapture default),
  # so present only on darwin at profile "full"; both conditions gate the
  # contents with mkIf, never a conditional import (trap A). A cli-profile
  # Mac that still imports the system defaults keeps its screencapture
  # location pointed here without the directory; macOS then falls back to
  # the Desktop, degraded but harmless.
  #
  # defaults.nix points screencapture here. macOS silently falls back to the
  # Desktop when the directory is missing, so create it rather than assume it.
  config = lib.mkIf (pkgs.stdenv.hostPlatform.isDarwin && config.dotfiles.profile == "full") {
    home.activation.screenshotsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/Documents/Screenshots"
    '';
  };
}
