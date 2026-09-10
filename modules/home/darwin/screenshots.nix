{ lib, ... }:

{
  # configuration.nix points screencapture here. macOS silently falls back to the
  # Desktop when the directory is missing, so create it rather than assume it.
  home.activation.screenshotsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/Documents/Screenshots"
  '';
}
