{ config, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  # Edit-in-place: the real file stays in my repo, ~/.config just points at it.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
}
