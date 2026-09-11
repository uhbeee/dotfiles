{ config, ... }:

{
  # Authored config; wezterm.lua loads ~/.config/dotfiles-local/wezterm.lua
  # for machine-local tweaks, so read-only store sources cost nothing.
  home.file.".config/wezterm".source = config.lib.dotfiles.authored "home/.config/wezterm";
}
