{ config, lib, ... }:

{
  # GUI-adjacent, so present only at profile "full"; a server gets no
  # terminal-emulator config. Gated with mkIf on the contents, never a
  # conditional import (trap A: imports cannot depend on config). The app
  # itself is not home's to install - a Homebrew cask on macOS, a package
  # or the distro's on Linux - only the authored config lives here.
  #
  # Authored config; wezterm.lua loads ~/.config/dotfiles-local/wezterm.lua
  # for machine-local tweaks, so read-only store sources cost nothing.
  config = lib.mkIf (config.dotfiles.profile == "full") {
    home.file.".config/wezterm".source = config.lib.dotfiles.authored "home/.config/wezterm";
  };
}
